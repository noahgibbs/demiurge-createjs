require "demiurge/tmx"
require "demiurge/createjs/location"
require "demiurge/createjs/humanoid"
require "demiurge/createjs/display"

# A single EngineSync runs on the server, sending messages about the
# world to the various player connections.

class Demiurge::Createjs::EngineSync
  attr_reader :engine

  def initialize(engine)
    @engine = engine
    @players = {}
    @locations = {}
    @agents = {}

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
    return if @locations[item.name] || @agents[item.name]  # Already have this one
    if item.is_a?(::Demiurge::TmxLocation)
      @locations[item.name] = ::Demiurge::Createjs::Location.new demi_location: item  # Build a TMX location
    elsif item.is_a?(::Demiurge::Agent)
      if item.get_action("$display")["block"] # This special action is used to pass the Display info through to a Display library.
        builder = Demiurge::Createjs::DisplayBuilder.new(item)
        display_objs = builder.built_objects
        raise("Only display one object per agent right now for item #{item.name.inspect}!") if display_objs.size > 1
        raise("No display objects declared for item #{item.name.inspect}!") if display_objs.size == 0
        @agents[item.name] = display_objs[0]  # Exactly one display object. Perfect.
      else
        # No Display information? Default to generic guy in a hat.
        layers = [ "male", "kettle_hat_male", "robe_male" ]
        @agents[item.name] = ::Demiurge::Createjs::Humanoid.new layers, name: item_name, demi_agent: item
      end

      show_agent_to_players(item)
    end
  end

  def show_agent_to_players(demi_item)
    if demi_item.position  # Agents are allowed to have no position and just be instantiable
      loc_name, x, y = ::Demiurge::TmxLocation.position_to_loc_coords(demi_item.position)
      loc = @engine.item_by_name(loc_name)
      if loc.is_a?(::Demiurge::TmxLocation)
        spritesheet = loc.tiles[:spritesheet]
        display_obj = @agents[demi_item.name]
        @players.each do |player_name, player|
          if player.demi_agent.location_name == loc_name
            # The new agent and the player are in the same location
            x, y = ::Demiurge::TmxLocation.position_to_coords(demi_item.position)
            player.show_sprites(demi_item.name, display_obj.spritesheet, display_obj.spritestack)
            player.message "displayTeleportStackToPixel", display_obj.stack_name, x * spritesheet[:tilewidth], y * spritesheet[:tileheight], {}
          end
        end
      end
    end
  end

  def add_player(player)
    agent = player.demi_agent
    @players[player.name] = player
    loc = agent.location

    # Do we have a tmx_location for that player?
    unless @locations[loc.name]
      STDERR.puts "This player doesn't seem to be in a known TMX location, instead is in #{loc.name.inspect}!"
      return
    end

    spritesheet = @locations[loc.name].spritesheet
    spritestack = @locations[loc.name].spritestack
    # Show the location's sprites
    player.show_sprites(loc.name, spritesheet, spritestack)
    x, y = ::Demiurge::TmxLocation.position_to_coords(agent.position)
    player.send_instant_pan_to_pixel_offset spritesheet[:tilewidth] * x, spritesheet[:tileheight] * y

    # Anybody else there?
    @agents.each do |agent_name, agent|
      if agent.demi_agent.location_name == loc.name
        # There's somebody here
        x, y = ::Demiurge::TmxLocation.position_to_coords(agent.demi_agent.position)
        player.show_sprites(agent_name, agent.spritesheet, agent.spritestack)
        player.message "displayTeleportStackToPixel", agent_name + "_stack", x * spritesheet[:tilewidth], y * spritesheet[:tileheight], {}
      end
    end
  end

  def remove_player(player)
    if player.nil?
      STDERR.puts "Nil player passed to remove_player!"
      return
    end
    agent = player.demi_agent
    body = @agents[agent.name] # This is the DCJS Humanoid object
    @players.delete(player.name)
    loc = agent.location

    # TODO: how do we deregister the Demiurge agent?

    # Indicate to all present that the player has disappeared
    @engine.send_notification({ "player_name" => player.name }, notification_type: "player_logout", location: loc.name, zone: loc.zone_name, item_acting: agent.name)

    # TODO: Once players are properly embodied, and if this player is, hide them on logout.
    # Also, move their body out of the room somehow.
    @players.values.each do |p|
      p.message "displayHideSpriteStack", body.stack_name
      p.message "displayHideSpriteSheet", body.sheet_name
    end
  end

  private

  # When new data comes in about things in the engine changing, this is what receives that notification.
  def notified(data)
    return if data["type"] == "tick finished"

    if data["type"] == "move"
      agent = @agents[data["item acting"]]
      x, y = ::Demiurge::TmxLocation.position_to_coords(data["new_position"])
      old_x = agent.x
      old_y = agent.y

      if data["old_location"] != data["new_location"]
        show_agent_to_players(agent.demi_agent)
      end

      move_messages = agent.walk_to_tile x, y, { "duration" => 0.5 } if x  # Only have move messages if moving to a TmxLocation
      @players.each do |player_name, player|
        player_loc_name = player.demi_agent.location_name
        next unless data["old_location"] == player_loc_name || data["new_location"] == player_loc_name
        if data["old_location"] == data["new_location"]
          # Just moving somebody between positions in the player's same location
          move_messages.each { |msg_array| player.message *msg_array }
        elsif data["old_location"] == player_loc_name
          # The player has moved away, make them disappear
          player.message "displayHideSpriteStack", agent.stack_name
          player.message "displayHideSpriteSheet", agent.sheet_name
        else
          # The moving agent has just gotten here, but the code above will make them appear
        end
      end
      return
    end

    if data["type"] == "speech"
      text = data["words"] || "ADD WORDS TO SPEECH NOTIFICATION!"
      speaker = @engine.item_by_name(data["item acting"])
      body = @agents[data["item acting"]]
      speaker_loc_name = speaker.location_name
      @players.each do |player_name, player|
        player_loc_name = player.demi_agent.location_name
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

    @players.each do |player_name, player|
      player.message "simNotification", data
    end
  end

end
