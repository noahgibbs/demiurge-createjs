require "demiurge/tmx"
require "demiurge/createjs/location"
require "demiurge/createjs/humanoid"
require "demiurge/createjs/display"

class Demiurge::Createjs::EngineSync
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
      if item.is_a?(::Demiurge::TmxLocation)
        @locations[item_name] = ::Demiurge::Createjs::Location.new demi_location: item  # Build a TMX location
      elsif item.is_a?(::Demiurge::Agent)
        if item.get_action("$display") # This special action is used to pass the Display info through to a Display library.
          builder = Demiurge::Createjs::DisplayBuilder.new(item)
          display_objs = builder.built_objects
          raise("Only display one object per agent right now for item #{item.name.inspect}!") if display_objs.size > 1
          raise("No display objects declared for item #{item.name.inspect}!") if display_objs.size == 0
          @agents[item_name] = display_objs[0]  # Exactly one display object. Perfect.
        else
          # No Display information? Default to generic guy in a hat.
          layers = [ "male", "kettle_hat_male", "robe_male" ]
          @agents[item_name] = ::Demiurge::Createjs::Humanoid.new layers, name: item_name, demi_agent: item
        end
      end
    end
  end

  def add_player(player)
    @players[player.name] = player
    loc = @engine.item_by_name player.location_name

    # Do we have a tmx_location for that player?
    unless @locations[loc.name]
      STDERR.puts "This player doesn't seem to be in a known TMX location, instead is in #{loc.name.inspect}!"
      return
    end

    spritesheet = @locations[loc.name].spritesheet
    spritestack = @locations[loc.name].spritestack
    # Show the location's sprites
    player.show_sprites(loc.name, spritesheet, spritestack)
    player.message "displayInstantPanToPixel", (spritesheet[:tilewidth] * spritestack[:width]) / 2, (spritesheet[:tileheight] * spritestack[:height]) / 2, {}

    # Anybody else there?
    @agents.each do |agent_name, agent|
      if agent.demi_agent.location_name == loc.name
        # There's somebody here
        coords_string = agent.demi_agent.position.split("#",2)[1] || "0,0"
        x,y = coords_string.split(",").map(&:to_i)
        player.show_sprites(agent_name, agent.spritesheet, agent.spritestack)
        player.message "displayTeleportStackToPixel", agent_name + "_stack", x * spritesheet[:tilewidth], y * spritesheet[:tileheight], {}
      end
    end
  end

  private

  # When new data comes in about things in the engine changing, this is what receives that notification.
  def notified(data)
    return if data["type"] == "tick finished"

    if data["type"] == "move"
      agent = @agents[data["item acting"]]
      pos = data["new_position"].split("#",2)[1]
      x, y = pos.split(",").map(&:to_i)
      old_x = agent.x
      old_y = agent.y
      move_messages = agent.walk_to_tile x, y, { "duration" => 0.5 }
      @players.each do |player_name, player|
        if data["old_location"] == data["new_location"]
          player_loc_name = player.location_name
          # Just moving somebody around in a location
          next if data["new_location"] != player_loc_name  # Moving around where this player can't see, ignore it
          move_messages.each do |msg_array|
            player.message *msg_array
          end
        else
          # Moving somebody from one place to another
        end
      end
      return
    end

    @players.each do |player_name, player|
      player.message "simNotification", data
    end
  end

end
