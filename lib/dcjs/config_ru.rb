require "faye/websocket"
require "rack/coffee"

Faye::WebSocket.load_adapter('thin')

module DCJS
  def self.root_dir dir
    @root_dir = File.absolute_path(dir)
  end

  def self.rack_builder builder
    @rack_builder = builder

    coffee_root = File.join(__dir__, "..", "..")
    @rack_builder.use Rack::Coffee, :root => coffee_root, :urls => "/dcjs"
  end

  def self.coffeescript_dirs *dirs
    dirs = [*dirs].flatten
    STDERR.puts "Using Rack::Coffee, :root => #{(@root_dir + "/").inspect}, :urls => #{dirs.map { |d| "/" + d }.inspect}"
    @rack_builder.use Rack::Coffee, :root => (@root_dir + "/"), :urls => dirs.map { |d| "/" + d }
  end

  def self.static_dirs *dirs
    dirs = [*dirs].flatten

    @rack_builder.use Rack::Static, :urls => dirs.map { |d| "/" + d }
  end

  def self.static_files *files
    @static_files = [*files].flatten
  end

  def self.handler
    static_files = @static_files.map { |f| "/" + f }
    lambda do |env|
      if Faye::WebSocket.websocket? env
        Demiurge::Createjs.websocket_handler env
      else
        if static_files.include?(env["PATH_INFO"])
          file = env["PATH_INFO"]
          file = file[1..-1] if file[0] == "/"
          return [200, {'Content-Type' => 'text/html'}, [File.read(file)]]
        else
          return [404, {}, [""]]
        end
      end
    end
  end
end
