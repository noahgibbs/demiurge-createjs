
module Demiurge::Createjs
  class DisplayObject
    attr_reader :demi_item   # Demiurge item that this displays
    attr_reader :name        # Name, which may or may not correspond to the Demiurge item name

    # Most recently-displayed coordinate and location. This can vary
    # significantly from the Demiurge item's location during a long
    # series of movement notifications - the Demiurge item may already
    # be at the final location, while the notifications go one at a
    # time through the places in between.
    attr_reader :x
    attr_reader :y
    attr_reader :location  # Most recently-drawn Demiurge location name

    def initialize demi_item:
      @name = name
      @demi_item = demi_item
      @location, @x, @y = ::Demiurge::TmxLocation.position_to_loc_coords(demi_item.position) if demi_item.position
    end
  end
end
