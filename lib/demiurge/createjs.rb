require "demiurge/createjs/version"

require "demiurge/createjs/websocket"

require "demiurge/createjs/humanoid"
require "demiurge/createjs/player"

# Demiurge-Createjs adds display libraries for an HTML game on top of
# the Demiurge engine for game state. It includes not only CreateJS
# but also Websocket, EventMachine and more.

module Demiurge
  module Createjs
    def self.run app
      @app = app
    end
  end
end
