require "demiurge/tmx"
require "demiurge/createjs/display_object"

module Demiurge::Createjs
  # A Humanoid corresponds pretty specifically to The Mana Project's idea of a humanoid.
  # It has layers of equipment sprites over a pretty specific base animation.
  # You can get humanoid spritesheets from Mana Project games (The Mana World,
  # Evol Online, etc.) and/or from the Liberated Pixel Cup. Check OpenGameArt
  # for LPC-compatible artwork for more.
  class Humanoid < ::Demiurge::Createjs::DisplayObject
    attr_reader :spritesheet
    attr_reader :spritestack

    def initialize layers, name:, demi_item:, format: "png", engine_sync:
      super name: name, demi_item: demi_item, engine_sync: engine_sync

      @format = format

      # This idea of layers and specific animations is *very* specific
      # to ManaSource-style or Liberated-Pixel-Cup-style humanoid
      # animations.
      @layers = layers.map { |layer| layer.is_a?(String) ? { name: layer } : layer }
      prev_offset = 0
      @layers.each do |layer|
        layer[:filename] ||= layer[:name]  # No filename? Default to name.
        layer[:offset] ||= prev_offset + HUMANOID_IMAGE_OFFSETS[:total]
        prev_offset = layer[:offset]
      end

      @spritesheet = build_spritesheet_json
      @spritestack = build_spritestack_json
    end

    def stack_name
      name
    end

    def sheet_name
      "#{name}_spritesheet"
    end

    def build_spritesheet_json
      images = (@layers.zip(0..(@layers.size - 1))).flat_map do |layer, index|
        [
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:walkcycle] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_walkcycle.#{@format}",
            "imagewidth" => 576,
            "imageheight" => 256,
            "tilewidth" => 64,
            "tileheight" => 64,
            "reg_x" => 0,
            "reg_y" => 32,  # This is hardcoded to ManaSource format in an annoyingly specific way... :-(
          },
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:hurt] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_hurt.#{@format}",
            "imagewidth" => 384,
            "imageheight" => 64,
            "tilewidth" => 64,
            "tileheight" => 64,
            "reg_x" => 0,
            "reg_y" => 32,
          },
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:slash] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_slash.#{@format}",
            "imagewidth" => 384,
            "imageheight" => 256,
            "tilewidth" => 64,
            "tileheight" => 64,
            "reg_x" => 0,
            "reg_y" => 32,
          },
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:spellcast] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_spellcast.#{@format}",
            "imagewidth" => 448,
            "imageheight" => 256,
            "tilewidth" => 64,
            "tileheight" => 64,
            "reg_x" => 0,
            "reg_y" => 32,
          },
        ]
      end

      {
        "name" => sheet_name,
        "tilewidth" => 64,
        "tileheight" => 64,
        "properties" => {},
        "animations" => @layers.map { |layer| self.class.animation_with_offset("#{layer[:name]}_", layer[:offset]) }.inject({}, &:merge),
        "images" => images,
      }
    end

    def build_spritestack_json
      layers = @layers.map do |layer|
        {
          "name" => layer[:name],
          "data" => [ [ layer[:offset] + HUMANOID_BASE_ANIMATION["stand_down"][0] ] ],
          "visible" => true,
          "opacity" => 1.0,
          "z" => 0.0,
        }
      end

      {
        "name" => stack_name,
        "width" => 1,
        "height" => 1,
        "spritesheet" => "#{name}_spritesheet",
        "layers" => layers,
      }
    end

    def animation_messages anim_name
      # For displayStartAnimation
      @layers.map do |layer|
        ["displayStartAnimation", {
          "stack" => stack_name,
          "layer" => layer[:name],
          "w" => 0,
          "h" => 0,
          "anim" => "#{layer[:name]}_#{anim_name}"
        }]
      end
    end

    def move_for_player(player, old_position, new_position, options = {})
      old_loc_name, old_x, old_y = ::Demiurge::TmxLocation.position_to_loc_coords(old_position)
      new_loc_name, new_x, new_y = ::Demiurge::TmxLocation.position_to_loc_coords(new_position)

      x_delta = new_x - old_x
      y_delta = new_y - old_y

      if x_delta.abs > y_delta.abs
        cur_direction = x_delta > 0 ? "right" : "left"
      else
        cur_direction = y_delta > 0 ? "down" : "up"
      end

      if options["duration"]
        time_to_walk = options["duration"]
      else
        speed = options["speed"] || 1.0
        distance = Math.sqrt(x_delta ** 2 + y_delta ** 2)
        time_to_walk = distance / speed
      end

      # When in doubt, hardcode w/ ManaSource values...
      pixel_x = x * 32
      pixel_y = y * 32
      if @location_spritesheet
        pixel_x = x * @location_spritesheet[:tilewidth]
        pixel_y = y * @location_spritesheet[:tileheight]
      end

      animation_messages("walk_#{cur_direction}").each { |msg| player.message msg }
      player.message ["displayMoveStackToPixel", stack_name, pixel_x, pixel_y, { "duration" => time_to_walk } ]
    end

    # Calculate messages for animations to move in a line to a tile.
    # Options:
    #   "speed" - speed to move one tile of distance
    #   "duration" - duration for entire walk animation (overrides "speed")
    def walk_to_loc_coords(location, x, y, options = {})
      messages = []

      x_delta = x - @x
      y_delta = y - @y

      if x_delta.abs > y_delta.abs
        cur_direction = x_delta > 0 ? "right" : "left"
      else
        cur_direction = y_delta > 0 ? "down" : "up"
      end

      if options["duration"]
        time_to_walk = options["duration"]
      else
        speed = options["speed"] || 1.0
        distance = Math.sqrt(x_delta ** 2 + y_delta ** 2)
        time_to_walk = distance / speed
      end

      # When in doubt, hardcode w/ ManaSource values...
      pixel_x = x * 32
      pixel_y = y * 32
      if @demi_item.location.is_a?(::Demiurge::TmxLocation)
        loc_sheet = @demi_item.location.tiles[:spritesheet]
        pixel_x = x * loc_sheet[:tilewidth]
        pixel_y = y * loc_sheet[:tileheight]
      end

      messages += animation_messages("walk_#{cur_direction}")
      messages.push ["displayMoveStackToPixel", stack_name, pixel_x, pixel_y, { "duration" => time_to_walk } ]

      @location = location
      @x = x
      @y = y

      messages
      #EM.add_timer(time_to_walk) do
      #  # Still walking as a result of this call? If so, now stop.
      #  if @anim_counter == cur_anim_counter
      #    send_animation "stand_#{cur_direction}"
      #  end
      #end
    end

    def pixel_coords_for_tile(x, y)
      # When in doubt, hardcode w/ ManaSource values...
      pixel_x = x * 32
      pixel_y = y * 32
      if @demi_item.location.is_a?(::Demiurge::TmxLocation)
        loc_sheet = @demi_item.location.tiles[:spritesheet]
        pixel_x = x * loc_sheet[:tilewidth]
        pixel_y = y * loc_sheet[:tileheight]
      end
      [pixel_x, pixel_y]
    end

    # Return a humanoid animation, offset by a constant number of frames.
    # This is used to have, say, multiple body or equipment animations in
    # the same spritesheet.
    def self.animation_with_offset(prefix, offset)
      anim = {}
      HUMANOID_BASE_ANIMATION.each do |key, value|
        anim[prefix + key] = value.map do |f|
          if f.is_a?(Fixnum)
            f + offset
          elsif f.is_a?(String)
            prefix + f
          else
            f
          end
        end
      end
      anim
    end

    HUMANOID_IMAGE_OFFSETS = {
      :walkcycle => 0,
      :hurt => 36,
      :slash => 42,
      :spellcast => 66,
      :total => 94
    }

    HUMANOID_BASE_ANIMATION = {
      "stand_up" => [0],
      "walk_up" => [1, 8, "walk_up", 0.33],
      "stand_left" => [9],
      "walk_left" => [10, 17, "walk_left", 0.33],
      "stand_down" => [18],
      "walk_down" => [19, 26, "walk_down", 0.33],
      "stand_right" => [27],
      "walk_right" => [28, 35, "walk_right", 0.33],
      "hurt" => [36, 41, "hurt", 0.33],
      "slash_up" => [42, 47, "slash_up", 0.33],
      "slash_left" => [48, 53, "slash_left", 0.33],
      "slash_down" => [54, 59, "slash_down", 0.33],
      "slash_right" => [60, 65, "slash_right", 0.33],
      "spellcast_up" => [66, 72, "spellcast_up", 0.33],
      "spellcast_left" => [73, 79, "spellcast_left", 0.33],
      "spellcast_down" => [80, 86, "spellcast_down", 0.33],
      "spellcast_right" => [87, 93, "spellcast_right", 0.33],
    }

  end
end
