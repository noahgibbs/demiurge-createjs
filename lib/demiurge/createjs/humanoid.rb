# TODO: Move these constants into the class

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

HUMANOID_IMAGE_OFFSETS = {
  :walkcycle => 0,
  :hurt => 36,
  :slash => 42,
  :spellcast => 66,
  :total => 94
}

module Demiurge::Createjs
  # A Humanoid corresponds pretty specifically to The Mana Project's idea of a humanoid.
  # It has layers of equipment sprites over a pretty specific base animation.
  # You can get humanoid spritesheets from Mana Project games (The Mana World,
  # Evol Online, etc.) and/or from the Liberated Pixel Cup. Check OpenGameArt
  # for LPC-compatible artwork for more.
  class ManaHumanoid
    attr :direction
    attr :anim
    attr :name

    def initialize name, layers, format = "png"
      @name, @format = name, format

      @layers = layers.map { |layer| layer.is_a?(String) ? { name: layer } : layer }
      prev_offset = 0
      @layers.each do |layer|
        layer[:filename] ||= layer[:name]  # No filename? Default to name.
        layer[:offset] ||= prev_offset + HUMANOID_IMAGE_OFFSETS[:total]
        prev_offset = layer[:offset]
      end

      @direction = :down
      @anim = :stand
    end

    def stack_name
      "#{name}_stack"
    end

    def build_spritesheet_json
      images = (@layers.zip(0..(@layers.size - 1))).flat_map do |layer, index|
        [
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:walkcycle] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_walkcycle.#{@format}",
            "image_width" => 576,
            "image_height" => 256,
          },
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:hurt] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_hurt.#{@format}",
            "image_width" => 384,
            "image_height" => 64,
          },
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:slash] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_slash.#{@format}",
            "image_width" => 384,
            "image_height" => 256,
          },
          {
            "firstgid" => HUMANOID_IMAGE_OFFSETS[:spellcast] + layer[:offset],
            "image" => "/sprites/#{layer[:name]}_spellcast.#{@format}",
            "image_width" => 448,
            "image_height" => 256,
          },
        ]
      end

      {
        "name" => "#{name}_spritesheet",
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

  end
end
