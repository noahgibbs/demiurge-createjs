class Demiurge::Createjs::Player
  attr :zone, true
  attr :x, true
  attr :y, true
  attr :transport, true
  attr :humanoid, true

  def initialize options
    @transport = options[:transport]
    @name = options[:name] || "player"
    @layers = [ "skeleton", "kettle_hat_male" ]
    @humanoid = Demiurge::Createjs::ManaHumanoid.new @name, @layers, "png"
    @x = 0
    @y = 0
    @view_width = options[:width] || 640
    @view_height = options[:height] || 480
    @cur_direction = "right"
    @cur_anim = "stand"

    # "Exposure" as understood on the client starts at 0 unless set.
    # You can think of it as the center of the player's viewport.  The
    # player object expects to have a location and viewport set pretty
    # much immediately after creation, so we don't send a message for
    # it yet.

    @pan_center_x = 0
    @pan_center_y = 0

    @anim_counter = 0
  end

  def message(*args)
    @transport.game_message *args
  end

  def display
    if @zone
      self.message "displayNewSpriteSheet", @zone.spritesheet
      self.message "displayNewSpriteStack", @zone.spritestack
    end
    self.message "displayNewSpriteSheet", @humanoid.build_spritesheet_json
    self.message "displayNewSpriteStack", @humanoid.build_spritestack_json
  end

  def send_animation anim_name
    @anim_counter += 1
    @layers.each do |layer|
      anim_msg = {
        "stack" => "#{@name}_stack",
        "layer" => layer,
        "w" => 0,
        "h" => 0,
        "anim" => "#{layer}_#{anim_name}"
      }
      message "displayStartAnimation", anim_msg
    end
  end

  # Move to a location on the current spritestack
  def teleport_to_tile(x, y, options = {})
    pan_offset_x, pan_offset_y = pan_offset_for_center_tile(x, y)
    send_pan_to_pixel_offset(x, y, options)

    pixel_x = x * @zone.spritesheet[:tilewidth]
    pixel_y = y * @zone.spritesheet[:tileheight]
    # TODO: something's wrong here. How to teleport player's sprite to correct location on Zone tiles...
    message "displayTeleportStackToPixel", "#{@name}_stack", pixel_x, pixel_y, options
    @x = x
    @y = y
  end

  # Move to a location on the current spritestack
  def move_to_tile(x, y, options = {})
    pixel_x = x * @zone.spritesheet[:tilewidth]
    pixel_y = y * @zone.spritesheet[:tileheight]
    message "displayMoveStackToPixel", "#{@name}_stack", pixel_x, pixel_y, options
    @x = x
    @y = y
  end

  # Pan the display to a pixel offset (upper-left corner) in the current spritestack
  def send_pan_to_pixel_offset(x, y, options = {})
    return if x == @pan_center_x && y == @pan_center_y
    message "displayPanStackToPixel", @zone.spritestack[:name], x, y, options
  end

  # Pan the display to a pixel offset (upper-left corner) in the current spritestack
  def send_instant_pan_to_pixel_offset(x, y, options = {})
    return if x == @pan_center_x && y == @pan_center_y
    message "displayInstantPanStackToPixel", @zone.spritestack[:name], x, y, options
  end

  def pan_offset_for_center_tile(x, y)
    tilewidth = @zone.spritesheet[:tilewidth]
    tileheight = @zone.spritesheet[:tileheight]
    sheetwidth = @zone.spritestack[:width] * @zone.spritesheet[:tilewidth]
    sheetheight = @zone.spritestack[:height] * @zone.spritesheet[:tileheight]

    tile_center_x = x * tilewidth + tilewidth / 2
    tile_center_y = y * tileheight + tileheight / 2

    upper_left_x = tile_center_x - @view_width / 2
    upper_left_y = tile_center_y - @view_height / 2

    highest_offset_x = sheetwidth - @view_width
    highest_offset_y = sheetheight - @view_height

    upper_left_x = 0 if upper_left_x < 0
    upper_left_y = 0 if upper_left_y < 0
    upper_left_x = highest_offset_x if upper_left_x > highest_offset_x
    upper_left_y = highest_offset_y if upper_left_y > highest_offset_y

    [upper_left_x, upper_left_y]
  end

  # This gives the pixel coordinates relative to the zone
  # spritesheet's origin for a humanoid sprite standing at the given
  # tile.
  def humanoid_coords_for_tile x, y
    tilewidth = @zone.spritesheet[:tilewidth]
    tileheight = @zone.spritesheet[:tileheight]
    sheetwidth = @zone.spritestack[:width] * @zone.spritesheet[:tilewidth]
    sheetheight = @zone.spritestack[:height] * @zone.spritesheet[:tileheight]

    # Center of terrain tile
    center_x = tilewidth * x + tilewidth / 2
    center_y = tileheight * y + tileheight / 2

    # Humanoid sprites generally have feet at about (32, 52). So if a
    # humanoid sprite was standing at tile 0, 0, you'd want the pixel
    # center at (16, 16) to line up with the humanoid sprite's feet at
    # (32, 52).
    [ center_x - 32, center_y - 52 ]
  end

  # Move in a line to a tile, walking, panning and setting animations
  # Options:
  #   "speed" - speed to move one tile of distance
  #   "duration" - duration for entire walk animation (overrides "speed")
  def walk_to_tile(x, y, options = {})
    x_delta = x - @x
    y_delta = y - @y

    if x_delta > y_delta
      @cur_dir = x_delta > 0 ? "right" : "left"
    else
      @cur_dir = y_delta > 0 ? "down" : "up"
    end

    if options["duration"]
      time_to_walk = options["duration"]
    else
      speed = options["speed"] || 1.0
      distance = Math.sqrt(x_delta ** 2 + y_delta ** 2)
      time_to_walk = distance / speed
    end

    send_animation "walk_#{@cur_dir}"
    cur_anim_counter = @anim_counter

    pan_x, pan_y = pan_offset_for_center_tile(x, y)
    send_pan_to_pixel_offset pan_x, pan_y, "duration" => time_to_walk
    move_to_tile x, y, "duration" => time_to_walk

    EM.add_timer(time_to_walk) do
      # Still walking as a result of this call? If so, now stop.
      if @anim_counter == cur_anim_counter
        send_animation "stand_#{@cur_dir}"
      end
    end
  end
end
