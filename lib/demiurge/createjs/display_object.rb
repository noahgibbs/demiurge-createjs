module ::Demiurge::Createjs
  class DisplayObject
    attr_reader :demi_item   # Demiurge item that this displays
    attr_reader :name        # Name, which should be the same as the Demiurge item name if there is one.

    # Most recently-displayed coordinate and location. This can vary
    # significantly from the Demiurge item's location during a long
    # series of movement notifications - the Demiurge item may already
    # be at the final location, while the notifications go one at a
    # time through the places in between.
    attr_reader :x              # Most recently-drawn coordinates
    attr_reader :y
    attr_reader :location_name  # Most recently-drawn Demiurge location name
    attr_reader :location_display_obj
    attr_reader :location_spritesheet
    attr_reader :location_spritestack
    attr_reader :position

    def initialize demi_item:, name:, engine_sync:
      @name = name
      @demi_item = demi_item
      @demi_name = demi_item.name  # Usually the same as @name
      @engine_sync = engine_sync
      raise "Non-matching name and Demiurge name!" if @demi_item && @demi_item.name != name
      @demi_engine = demi_item.engine
      self.position = demi_item.position if demi_item && demi_item.position
    end

    def demiurge_reloaded
      @demi_item = @demi_engine.item_by_name(@demi_name)
      @location_item = @demi_engine.item_by_name(@location_name)
    end

    def position=(new_position)
      @position = new_position
      @location_name, @x, @y = ::Demiurge::TmxLocation.position_to_loc_coords(new_position)
      @location_item = @demi_engine.item_by_name(@location_name)
      @location_display_obj = @engine_sync.display_object_by_name(@location_name)
      if @location_item && @location_item.respond_to?(:tiles)
        @location_spritesheet = @location_item.tiles[:spritesheet]
        @location_spritestack = @location_item.tiles[:spritestack]
      else
        @location_spritesheet = nil
        @location_spritestack = nil
      end
    end

    # If this is a DisplayObj that doesn't have or use a SpriteStack,
    # this will need to be overridden.  To show to a player at a
    # particular position, set the position before calling
    # show_to_player.
    def show_to_player(player)
      #show_to_player_at_position(player, @position)
      raise "Need a spritesheet/spritestack or to override DisplayObject#show_to_player!" unless self.spritestack
      player.show_sprites_at_position(@demi_item.name, self.spritesheet, self.spritestack, @position)
    end

    def hide_from_player(player)
      player.hide_sprites(@demi_item.name)
    end

    # When doing an animation or other transition, it's important to
    # specify the older and newer coordinates.  This can't easily use
    # state in the item itself for both old and new positions - the
    # same transition may need to be made for many viewing players, so
    # setting the state as "part of the transition" doesn't work well.
    # Further complicating things, different players aren't guaranteed
    # to be seeing this DisplayObject in the same state at the start
    # of the transition, since they could have just arrived and missed
    # an animation, for example.
    def move_for_player(player, old_position, new_position)
      raise "Please override this method!"
      player.message ["displayMoveStackToPixel", self.spritestack[:name], pixel_x, pixel_y, { "duration" => time_to_walk } ]
    end
  end
end
