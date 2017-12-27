require "demiurge/createjs/display_object"

class Demiurge::Createjs::Location < ::Demiurge::Createjs::DisplayObject
  attr_reader :spritesheet
  attr_reader :spritestack

  # Track the visible output portion of a Demiurge location
  def initialize(demi_item:, name:, engine_sync:)
    super
    tiles = @demi_item.tiles
    @spritesheet = tiles[:spritesheet]
    @spritestack = tiles[:spritestack]
  end
end
