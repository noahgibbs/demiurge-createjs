# A Demiurge-Createjs app implements a login policy using "on_login".
# One very common policy? You get one login, and if you log in with
# the same name, the old login goes away. This is that policy.

module Demiurge::Createjs
  module LoginUnique
    def log_out_player(player)
      @player_by_transport ||= {}
      @player_by_username ||= {}

      return unless player
      username = player.name
      transport = player.websocket
      player.deregister  # Remove from EngineSync
      @player_by_username.delete(username)
      @player_by_transport.delete(transport)
    end

    def on_close(transport:, event:)
      @player_by_transport ||= {}
      @player_by_username ||= {}
      p [:close, event.code, event.reason].inspect
      log_out_player(@player_by_transport[transport])
    end

    def on_login(transport, username, engine_sync)
      @player_by_transport ||= {}
      @player_by_username ||= {}

      if @player_by_transport[transport]
        # Hrm. This websocket is already used, somehow. Disallow this
        # attempt.  One way this can happen is if a player is sending
        # login requests after they are already logged in.
        STDERR.puts "Websocket #{transport.inspect} has already logged in!"
        transport.send "failed_login", "Your websocket has already logged in!"
        return
      end

      if @player_by_username[username]
        STDERR.puts "This player is already logged in! Log 'em out."
        log_out_player(@player_by_username[username])
        # Then don't return from the method, but log in this new
        # connection as the "real" player.
      end

      # Now create a Player object, indexed by transport
      if self.respond_to?(:on_create_player)
        player = on_create_player(transport, username)
      else
        STDERR.puts "PLEASE DEFINE AN on_create_player METHOD IN YOUR GAME OBJECT!"
        return
      end
      @player_by_username[username] = player
      @player_by_transport[transport] = player
    end

  end
end
