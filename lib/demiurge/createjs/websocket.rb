module Demiurge::Createjs
  # This is a setting that the individual App objects can check.
  def self.get_record_traffic
    @record_traffic
  end

  def self.record_traffic(record = true)
    @record_traffic = record
  end

  def self.websocket_handler(env)
    ws = Faye::WebSocket.new(env)

    ws.on :open do |event|
      puts "Socket open"
      @app.on_open(transport: ws, event: event) if @app && @app.respond_to?(:on_open)
    end

    ws.on :message do |event|
      File.open("incoming_traffic.json", "a") { |f| f.write event.data + "\n" } if @record_traffic
      data = MultiJson.load event.data
      handle_message ws, data
    end

    ws.on :error do |event|
      @app.on_error(ws) if @app && @app.respond_to?(:on_error)
    end

    ws.on :close do |event|
      @app.on_close(transport: ws, event: event) if @app && @app.respond_to?(:on_close)
      ws = nil
    end

    # Return async Rack response
    ws.rack_response
  end

  def self.handle_message(ws, data)
    if data[0] == "auth"
      @app.on_auth_message(ws, data[1], *data[2]) if @app && @app.respond_to?(:on_auth_message)
      return
    end
    @app.on_message(ws) if @app && @app.respond_to?(:on_message)
  end
end
