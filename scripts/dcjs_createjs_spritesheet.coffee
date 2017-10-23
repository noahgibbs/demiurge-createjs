class DCJS.CreatejsDisplay.CreatejsSpriteSheet
  constructor: (data) ->
    [ @tilewidth, @tileheight, @images, @animations, @ss_cyclic_animations ] =
        [ data.tilewidth, data.tileheight, data.images, data.animations, data.cyclic_animations ]

    images = (image.image for image in @images)
    DCJS.CreatejsDisplay.loader.addHandler () => @imagesLoaded()
    DCJS.CreatejsDisplay.loader.addImages images

    if @images[0].frame_definitions?
      # TODO: verify that all GIDs are consecutive in frame definitions
      @frame_definitions = []
      for image, i in @images
        # For oversize tiles, make sure their bottom left corner winds up in the right spot via reg_y param
        image_fds = ([ fd.x, fd.y, fd.width, fd.height, i, 0, fd.height - @tileheight ] for fd in image.frame_definitions)
        @frame_definitions = @frame_definitions.concat(image_fds)
    else
      @frame_definitions = { width: @tilewidth, height:  @tileheight }
      if data.reg_x?
        console.log "Registration:", data.reg_x, data.reg_y
        @frame_definitions["regX"] = data.reg_x
        @frame_definitions["regY"] = data.reg_y
      else
        console.log "No registration (reg_x) found in", data

    @loaded = false
    @handlers = {}

  create_sprite: () ->
    new createjs.Sprite(@sheet)

  # Handler is called on the event with an "event" object:
  #   event.name - which event
  #   event.source - object sending event
  #
  # Events:
  #   complete - all sprites loaded
  #
  addEventListener: (event, handler) ->
    if event == "complete"
      @handlers["complete"] = [] unless @handlers["complete"]?
      @handlers["complete"].push handler
    else
      console.error "Unknown event #{event} on spritesheet!"

  ss_frame_to_cjs_frame: (frame_num) ->
    return 0 if frame_num == 0
    for offset, image of @images
      if frame_num >= image.firstgid && (!@images[offset + 1]? || frame_num < @images[offset + 1].firstgid)
        return (frame_num - @images[offset].firstgid) + @images[offset].cjs_offset
    console.warn "Can't map frame #{frame_num} into SpriteSheet #{@name}!"
    undefined

  ss_anim_frames_to_cjs_anim_frames: (animation) ->
    if typeof animation == "number"
      @ss_frame_to_cjs_frame(animation)
    else if animation instanceof Array
      if animation.length == 1
        [@ss_frame_to_cjs_frame animation[0]]
      else
        { speed: animation[3], next: animation[2], frames: [(@ss_frame_to_cjs_frame animation[0])..(@ss_frame_to_cjs_frame animation[1])] }
    else  # complex
      frames = animation.frames
      frames = [frames] if typeof frames == "number"
      frames = @ss_anim_frames_to_cjs_anim_frames frames  # This time as Array
      { speed: animation.speed, next: animation.next, frames: frames }

  cyclic_anim_for_tile: (tile) ->
    @cyclic_animations["tile_anim_#{tile}"]

  ss_cyclic_anim_to_dcjs_cyclic_anim: (animation) ->
    anim = []

    total_duration = 0
    total_duration += section.duration for section in animation
    anim.cycle_time = total_duration * 10.0

    for section in animation
      anim.push frame: @ss_frame_to_cjs_frame(section.frame), duration: section.duration * 10.0

    anim

  imagesLoaded: () ->
    images = []

    # Calculate CreateJS spritesheet frame numbers
    current_cjs_offset = 0
    for image in @images
      image.loaded_dom = DCJS.CreatejsDisplay.loader.getImage image.image

      # Figure out how many frames CreateJS will extract from this image
      padded_width = parseInt(image.loaded_dom.width) + @tilewidth - 1
      padded_height = parseInt(image.loaded_dom.height) + @tileheight - 1
      cjs_width = parseInt(padded_width / @tilewidth)
      cjs_height = parseInt(padded_height / @tileheight)
      cjs_frames = cjs_width * cjs_height

      # Use current CJS offset for this image, update for next one
      image.cjs_offset = current_cjs_offset
      current_cjs_offset += cjs_frames
      images.push image.loaded_dom

    @cjs_animations = {}
    @cjs_animations[name] = @ss_anim_frames_to_cjs_anim_frames(animation) for name, animation of @animations

    @cyclic_animations = {}
    for name, animation of @ss_cyclic_animations
      tile_num = parseInt name.slice(10)  # Cut off "tile_anim_"
      new_num = @ss_frame_to_cjs_frame tile_num
      @cyclic_animations["tile_anim_#{new_num}"] = @ss_cyclic_anim_to_dcjs_cyclic_anim(animation)

    @sheet = new createjs.SpriteSheet frames: @frame_definitions, images: images, animations: @cjs_animations

    @loaded = true
    e = { name: "complete", source: this }
    handler(e) for handler in @handlers["complete"]
