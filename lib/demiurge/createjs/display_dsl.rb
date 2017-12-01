# This handles the Display DSL in Demiurge Display blocks.

module Demiurge::Createjs
  def self.build_display_object(block)
    builder = DisplayBuilder.new
    builder.instance_eval(&block)
  end

  class DisplayBuilder
    attr_reader :built_objects

    def initialize(agent, engine_sync:)
      @agent = agent
      @built_objects = []
      @engine_sync = engine_sync
      disp = agent.get_action("$display")["block"]
      raise("No display action available for DisplayBuilder!") unless disp
      self.instance_eval(&disp) # Create the built objects from the block
    end

    def manasource_humanoid(&block)
      builder = HumanoidBuilder.new(@agent, engine_sync: @engine_sync)
      builder.instance_eval(&block)
      @built_objects << builder.built_obj
    end
  end

  class HumanoidBuilder
    def initialize(agent, engine_sync:)
      @agent = agent  # Demiurge Agent item
      @engine_sync = engine_sync
      @layers = [ "male", "robe_male" ] # Default appearance, if not given
    end

    def layers(*layer_names)
      @layers = (layer_names).flatten
    end

    def built_obj
      Humanoid.new @layers, name: @agent.name, demi_item: @agent, engine_sync: @engine_sync
    end
  end
end
