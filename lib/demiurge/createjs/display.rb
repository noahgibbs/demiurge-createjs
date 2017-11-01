module Demiurge::Createjs
  def self.build_display_object(block)
    builder = DisplayBuilder.new
    builder.instance_eval(&block)
  end

  class DisplayBuilder
    attr_reader :built_objects

    def initialize(agent)
      @agent = agent
      @built_objects = []
      disp = agent.get_action("$display")["block"]
      raise("No display action available for DisplayBuilder!") unless disp
      self.instance_eval(&disp) # Create the built objects from the block
    end

    def manasource_humanoid(&block)
      builder = HumanoidBuilder.new(@agent)
      builder.instance_eval(&block)
      @built_objects << builder.built_obj
    end
  end

  class HumanoidBuilder
    def initialize(agent)
      @agent = agent  # Demiurge Agent item
      @layers = [ "male", "robe_male" ] # Default appearance, if not given
    end

    def layers(*layer_names)
      @layers = (layer_names).flatten
    end

    def built_obj
      Humanoid.new @layers, name: @agent.name, demi_agent: @agent
    end
  end
end
