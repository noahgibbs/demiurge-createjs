require "demiurge/tmx"
require "demiurge/createjs/location"
require "demiurge/createjs/humanoid"
require "demiurge/createjs/display_dsl"

# A single EngineSync runs on the server, sending messages about the
# world to the various player connections.

# TODO:
# * Refactor to add something like ".each_player_for_location {}"

class Demiurge::Createjs::EngineSync
  attr_reader :engine

  def initialize(engine)
    @engine = engine
    @players = {}      # Mapping of player name strings to Player objects (not DisplayObjects or Demiurge items)
    @display_objs = {} # Mapping of item names to DCJS DisplayObjects such as Humanoids

    # Subscribing immediately avoids "oh, I missed that change" race
    # conditions with the engine spinning without the Engine Sync
    # realizing it. But it can cause "oh hey, I haven't seen that yet"
    # race conditions.
    @engine.subscribe_to_notifications(tracker: self.to_s) do |data|
      notified(data)
    end

    @engine.all_item_names.each do |item_name|
      item = @engine.item_by_name(item_name)
      register_engine_item(item)
    end
  end

  def register_engine_item(item)
    return if @display_objs[item.name] # Already have this one
    if item.is_a?(::Demiurge::TmxLocation)
      @display_objs[item.name] = ::Demiurge::Createjs::Location.new demi_item: item, name: item.name, engine_sync: self  # Build a DCJS location
    elsif item.agent?
      disp = item.get_action("$display")
      if disp && disp["block"] # This special action is used to pass the Display info through to a Display library.
        builder = Demiurge::Createjs::DisplayBuilder.new(item, engine_sync: self)
        display_objs = builder.built_objects
        raise("Only display one object per agent right now for item #{item.name.inspect}!") if display_objs.size > 1
        raise("No display objects declared for item #{item.name.inspect}!") if display_objs.size == 0
        @display_objs[item.name] = display_objs[0]  # Exactly one display object. Perfect.
      else
        # No Display information? Default to generic guy in a hat.
        layers = [ "male", "kettle_hat_male", "robe_male" ]
        @display_objs[item.name] = ::Demiurge::Createjs::Humanoid.new layers, name: item.name, demi_item: item, engine_sync: self
      end

      # Is this a registration for a player's body?
      if @players[item.name]
        player = @players[item.name]
        player.display_obj = @display_objs[item.name]
      end

      show_display_obj_to_players(@display_objs[item.name])
    end
  end

  def display_object_by_name(item_name)
    @display_objs[item_name]
  end

  def each_player_for_location_name(location_name, &block)
    @players.each do |player_name, player|
      if player.display_obj && player.display_obj.location_name == location_name
        yield(player)
      end
    end
  end

  def show_display_obj_to_players(display_obj)
    return unless display_obj.position # Agents and some other items are allowed to have no position and just be instantiable
    demi_item = display_obj.demi_item
    loc_name, x, y = ::Demiurge::TmxLocation.position_to_loc_coords(display_obj.position)
    each_player_for_location_name(loc_name) do |player|
      display_obj.show_to_player(player)
    end

    loc = @engine.item_by_name(loc_name)
    if loc.is_a?(::Demiurge::TmxLocation)
      spritesheet = loc.tiles[:spritesheet]
      @players.each do |player_name, player|
        if player.display_obj.location_name == loc_name
          # The new display_obj and the player are in the same location
          player.show_sprites(display_obj.name, display_obj.spritesheet, display_obj.spritestack)
          player.message "displayTeleportStackToPixel", display_obj.stack_name, x * spritesheet[:tilewidth], y * spritesheet[:tileheight], {}
        end
      end
    end
  end

  def hide_display_obj_from_players(display_obj, position)
    position ||= display_obj.demi_item.position
    return unless position
    if position  # Agents and some other items are allowed to have no position and just be instantiable
      loc_name, x, y = ::Demiurge::TmxLocation.position_to_loc_coords(position)
      loc = @engine.item_by_name(loc_name)
      if loc.is_a?(::Demiurge::TmxLocation)
        spritesheet = loc.tiles[:spritesheet]
        @players.each do |player_name, player|
          if player.display_obj.location_name == loc_name
            # The new agent and the player are in the same location
            player.hide_sprites(display_obj.name)
          end
        end
      end
    end
  end

  def show_location_to_player(player, position, location_do)
    spritesheet = location_do.spritesheet
    spritestack = location_do.spritestack

    loc_name = location_do.name

    # Show the location's sprites
    player.hide_all_sprites
    player.show_sprites(location_do.name, spritesheet, spritestack)
    x, y = ::Demiurge::TmxLocation.position_to_coords(position)
    player.send_instant_pan_to_pixel_offset spritesheet[:tilewidth] * x, spritesheet[:tileheight] * y

    # Anybody else there? Show them to this player.
    @display_objs.each do |do_name, display_obj|
      if display_obj.location_name == loc_name
        display_obj.show_to_player(player)
      end
    end
  end

  def add_player(player)
    @players[player.name] = player
    player.display_obj = @display_objs[player.name]
    loc_name = player.display_obj.location_name
    loc_do = @display_objs[loc_name]

    # Do we have a display object for that player's location?
    unless loc_do
      STDERR.puts "This player doesn't seem to be in a known TMX location, instead is in #{loc_name.inspect}!"
      return
    end

    show_location_to_player(player, player.display_obj.position, loc_do)
  end

  # The logout action happens before this does, which may affect what's where.
  def remove_player(player)
    @players.delete(player.name)
  end

  private

  # When new data comes in about things in the engine changing, this is what receives that notification.
  def notified(data)
    return if data["type"] == "tick finished"
    return if data["type"] == "move_from"

    # We subscribe to all events in all locations, and the move-from
    # and move-to have the same fields except location, zone and
    # type. So only pay attention to the move_to.
    if data["type"] == "move_to"
      return notified_of_move_to(data)
    end

    if data["type"] == "speech"
      text = data["words"] || "ADD WORDS TO SPEECH NOTIFICATION!"
      speaker = @engine.item_by_name(data["item acting"])
      body = @display_objs[data["item acting"]]
      speaker_loc_name = speaker.location_name
      @players.each do |player_name, player|
        player_loc_name = player.display_obj.location_name
        next unless player_loc_name == speaker_loc_name
        player.message "displayTextAnimOverStack", body.stack_name, text, "color" => data["color"] || "red", "font" => data["font"] || "20px Arial", "duration" => data["duration"] || 5.0
      end
      #anim = new window.DCJS.CreatejsDisplay.TextAnim(display.stage, text, { x: pixel_x, y: pixel_y, duration: data["duration"] || 5.0 } );
      return
    end

    # This notification will catch new player bodies, instantiated agents and whatnot.
    if data["type"] == "new item"
      item = @engine.item_by_name data["item acting"]
      register_engine_item(item)
      return
    end

    # Right now, every unrecognized message type gets blasted out to every player. Expect this to change.
    @players.each do |player_name, player|
      player.message "simNotification", data
    end
  end

  def notified_of_move_to(data)
    actor_do = @display_objs[data["item acting"]]
    x, y = ::Demiurge::TmxLocation.position_to_coords(data["new_position"])
    old_x = actor_do.x
    old_y = actor_do.y
    loc_name = data["new_location"]
    loc_do = @display_objs[loc_name]
    if loc_do
      spritesheet = loc_do.spritesheet
      spritestack = loc_do.spritestack
    else
      STDERR.puts "Moving to a non-displayed location #{loc_name.inspect}, no display object found..."
    end

    actor_do.position = data["new_position"]

    # An object just moved to a new location - show it to everybody in the new location, if it's a displayable loction.
    if data["old_location"] != data["new_location"]
      show_display_obj_to_players(actor_do) if loc_do
    end

    # Is it a player that just moved? If so, update them specifically.
    acting_player = @players[data["item acting"]]
    if acting_player
      if data["old_location"] != data["new_location"]
        ## Show the new location's sprites to the player who is moving, if the new location has sprites
        show_location_to_player(acting_player, data["new_position"], @display_objs[loc_name]) if loc_do
      else
        # Player moved in same location, pan to new position
        #actor_do.move_for_player(acting_player, data["old_position"], data["new_position"], { "duration" => 0.5 })
        acting_player.send_instant_pan_to_pixel_offset spritesheet[:tilewidth] * x, spritesheet[:tileheight] * y
      end
    end

    # Whether it's a player moving or something else, update all the
    # players who just saw the item move, disappear or appear.
    @players.each do |player_name, player|
      next if player_name == data["item acting"]  # Already handled it if this player is the one moving.
      player_loc_name = player.display_obj ? player.display_obj.location_name : nil
      next unless player_loc_name            # Player has no location? We don't update them.

      if data["old_location"] == data["new_location"]
        next unless player_loc_name == data["new_location"]
        STDERR.puts "Showing item #{data["item acting"].inspect} moving for player #{player.name.inspect}..."
        actor_do.move_for_player(player, data["old_position"], data["new_position"], { "duration" => 0.5 })
      elsif player_loc_name == data["old_location"]
        # The item changed rooms and the player is in the old
        # location. Hide the item.
        actor_do.hide_from_player(player)
      elsif player_loc_name == data["new_location"]
        # The item changed rooms and the player is in the new
        # location. Show the item, if it moved to a displayable
        # location.
        actor_do.show_to_player(player) if loc_do
      end
    end
  end
end
