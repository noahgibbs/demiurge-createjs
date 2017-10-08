module Demiurge::Createjs
  class Transport
    def initialize(websocket)
      @socket = websocket
    end

    def game_message(msg_name, *args)
      out_str = MultiJson.dump ["game_msg", msg_name, *args]
      File.open("outgoing_traffic.json", "a") { |f| f.write out_str + "\n" } if Demiurge::Createjs.get_record_traffic
      @socket.send out_str
    end
  end
end
