class Demiurge::Createjs::Player
  attr_reader :transport
  attr_reader :name
  attr_reader :location_name

  def initialize(transport:, name: "player", location_name:, tilewidth: 32, tileheight: 32, width: 640, height: 480, engine_sync:)
    @transport = transport
    @engine_sync = engine_sync
    @name = name
    @location_name = location_name

    @currently_shown = {}

    # "Exposure" as understood on the client starts at 0 unless set.
    # You can think of it as the center of the player's viewport.  The
    # player object expects to have a location and viewport set pretty
    # much immediately after creation, so we don't send a message for
    # it yet.

    @view_width = width
    @view_height = height
    @pan_center_x = 0
    @pan_center_y = 0

    @engine_sync.add_player(self)

    @shown_location = nil
  end

  def message(*args)
    @transport.game_message *args
  end

  def show_sprites(item_name, spritesheet, spritestack)
    return if @currently_shown[item_name]
    self.message "displayNewSpriteSheet", spritesheet
    self.message "displayNewSpriteStack", spritestack
    @currently_shown[item_name] = true
  end

  def hide_sprites(item_name)
    return unless @currently_shown[item_name]
    self.message "displayHideSpriteStack", spritestack["name"]
    self.message "displayHideSpriteSheet", spritesheet["name"]
    @currently_shown.delete(item_name)
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

  def pan_offset_for_center_tile(x, y)
    tile_center_x = x * @tilewidth + @tilewidth / 2
    tile_center_y = y * @tileheight + @tileheight / 2

    [tile_center_x, tile_center_y]
  end
end
