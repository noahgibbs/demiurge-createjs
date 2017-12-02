# A Player object handles the network connection to a single browser,
# via a protocol over Websockets. It also keeps track of what visual
# objects are currently visible in the browser, and handles panning
# (moving the window of visible display around.)

# A Player has no direct display-able presence, but instead can
# optionally have a DisplayObject to represent it.

class Demiurge::Createjs::Player
  attr_reader :name
  attr_reader :demi_item
  attr_reader :websocket
  attr_accessor :display_obj # To be set from EngineSync

  def initialize(websocket:, name:, demi_item:, width: 640, height: 480, engine_sync:)
    @websocket = websocket
    @engine_sync = engine_sync
    @name = name
    @demi_item = demi_item

    @currently_shown = {}

    # "Exposure" as understood on the client starts with the upper
    # left at 0 unless set.  You can think of it as the center of the
    # player's viewport.  The player object expects to have a location
    # and viewport set pretty much immediately after creation, so we
    # don't send a message for it yet.
    #
    # Normally a "player" will be set up by an EngineSync to
    # automatically follow a particular agent (that player's body) so
    # the panning will be taken care of that way pretty rapidly.

    @view_width = width
    @view_height = height
    @pan_center_x = width / 2
    @pan_center_y = height / 2
  end

  def message(msg_name, *args)
    out_str = MultiJson.dump [ "game_msg", msg_name, *args ]
    File.open("log/outgoing_traffic.json", "a") { |f| f.write out_str + "\n" } if Demiurge::Createjs.get_record_traffic
    @websocket.send out_str
  end

  def register()
    @engine_sync.add_player(self)
  end

  def deregister()
    @engine_sync.remove_player(self)
  end

  def show_sprites(item_name, spritesheet, spritestack)
    return if @currently_shown[item_name]
    self.message "displayNewSpriteSheet", spritesheet
    self.message "displayNewSpriteStack", spritestack
    @currently_shown[item_name] = [ spritesheet[:name], spritestack[:name] ]
  end

  def show_sprites_at_position(item_name, spritesheet, spritestack, position)
    unless display_obj.location_spritesheet
      STDERR.puts "Not showing when at location #{display_obj.location_name}, item is at #{@demi_item.location_name}, something's odd."
      return
    end
    show_sprites(item_name, spritesheet, spritestack)
    location_name, x, y = ::Demiurge::TmxLocation.position_to_loc_coords(position)
    if display_obj.location_name != location_name
      raise "Trying to show sprite #{item_name.inspect} at location #{location_name.inspect}, not current location #{player.display_obj.location_name.inspect}!"
    end
    self.message "displayTeleportStackToPixel", item_name, x * self.display_obj.location_spritesheet[:tilewidth], y * self.display_obj.location_spritesheet[:tileheight], {}
  end

  def hide_sprites(item_name)
    return unless @currently_shown[item_name]
    sheet_name, stack_name = @currently_shown[item_name]
    self.message "displayHideSpriteStack", "name" => stack_name
    self.message "displayHideSpriteSheet", "name" => sheet_name
    @currently_shown.delete(item_name)
  end

  def hide_all_sprites
    @currently_shown.each do |item_name, entry|
      sheet_name, stack_name = *entry
      self.message "displayHideSpriteStack", "name" => stack_name
      self.message "displayHideSpriteSheet", "name" => sheet_name
    end
    @currently_shown = {}
  end

  # Pan the display to a pixel offset (upper-left corner) in the current spritestack
  def send_pan_to_pixel_offset(x, y, options = {})
    return if x == @pan_center_x && y == @pan_center_y
    @pan_center_x = x
    @pan_center_y = y
    message "displayPanToPixel", x, y, options
  end

  # Pan the display to a pixel offset (upper-left corner) in the current spritestack
  def send_instant_pan_to_pixel_offset(x, y, options = {})
    return if x == @pan_center_x && y == @pan_center_y
    @pan_center_x = x
    @pan_center_y = y
    message "displayInstantPanToPixel", x, y, options
  end
end
