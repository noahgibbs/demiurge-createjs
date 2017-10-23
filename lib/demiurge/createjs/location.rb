class Demiurge::Createjs::Location
  attr_reader :spritesheet
  attr_reader :spritestack
  attr_reader :demi_location

  # Track the visible output portion of a Demiurge location
  def initialize(demi_location:)
    @demi_location = demi_location
    tiles = demi_location.tiles
    @spritesheet = tiles[:spritesheet]
    @spritestack = tiles[:spritestack]
  end
end
