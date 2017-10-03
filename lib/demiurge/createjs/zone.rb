class Demiurge::Createjs::Zone
  attr :spritestack
  attr :spritesheet

  def initialize options
    @spritestack = options[:spritestack]
    @spritesheet = options[:spritesheet]
  end
end
