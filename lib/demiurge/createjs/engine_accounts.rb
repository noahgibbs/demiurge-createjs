# TODO: Deprecate this. For the reasons below, but also because we
# want to be able to save/load/reload engine state in a way that isn't
# compatible with storing the player accounts in there. Player
# settings? Maybe, but probably not. Remember, this would only work
# with settings we want to reload and revert with the world
# state. That works well with things about the player's in-game
# existence (bank contents, say) but not with things that are
# fundamentally out-of-character and out-of-game (email, Twitter
# handle, time zone, password.)



# Accounts and their relatives are a potentially bottomless hole of
# technical interest and difficulty.  I'm handling this in a really
# simple way: Bcrypt exchange over HTTPS/WSS is built into
# Demiurge-Createjs, and it's not too hard to plug something else in
# if you're so inclined. Accounts, by default, get synced into the
# engine state, but it'd be easy to write a little Ruby plugin like
# the one below to synchronize accounts in some other way.
#
# This, too, is a potential goldmine and/or landmine of possible weird
# behavior: if account information is sync'd into the engine state,
# what does that mean about potential state rollbacks and what it does
# to your registered accounts and passwords? If account information
# lives in some other storage medium, what about information stored
# under the account name?
#
# This works for now. But mostly, it's easy to replace if it needs to
# work in some other way.

# This module should be included into the Demiurge-Createjs app.  The
# engine_sync object should be set early on, using the
# set_accounts_engine_sync method.
module Demiurge::Createjs
  module EngineAccounts
    def websocket_send(socket, *args)
      socket.send MultiJson.dump(args)
    end

    def set_accounts_engine_sync(engine_sync)
      @engine_accounts_obj = engine_sync
    end

    def account_state
      players_obj = @engine_accounts_obj.engine.item_by_name("players")
      players_obj.nil? ? nil : players_obj.state
    end

    # Process an authorization message
    def on_auth_message(websocket, msg_type, *args)
      unless account_state
        player_data = @engine_accounts_obj.engine.item_by_name("players")
        player_data.state = {}
        raise("Couldn't set account state!") unless account_state
      end

      if msg_type == "register_account"
        username, salt, hashed = args[0]["username"], args[0]["salt"], args[0]["bcrypted"]
        if account_state[username]
          # Technically this is a failed registration, not a login.
          websocket_send websocket, "failed_login", "Account #{username.inspect} already exists!"
          return
        end
        account_state[username] = { "account" => { "salt" => salt, "hashed" => hashed, "method" => "bcrypt" } }

        return
      end
      if msg_type == "hashed_login"
        username, hashed = args[0]["username"], args[0]["bcrypted"]
        unless account_state[username]
          websocket_send websocket, "failed_login", "No such user as #{username.inspect}!"
          return
        end
        if account_state[username]["account"]["hashed"] == hashed
          # Let the browser side know that a login succeeded
          websocket_send websocket, "login", username: username
          # Let the app know that a login succeeded
          self.on_login(websocket, username, @engine_accounts_obj)
        else
          websocket_send websocket, "failed_login", "Wrong password for user #{username.inspect}!"
        end
        return
      end

      # TODO: some kind of rate-limiting to reduce our willingness to give out user salts in bulk
      if msg_type == "get_salt"
        username = args[0]["username"]
        unless account_state[username]
          websocket_send websocket, "failed_login", "No such usr as #{username.inspect}!"
          return
        end
        user_salt = account_state[username]["account"]["salt"]
        websocket_send websocket, "login_salt", user_salt
        return
      end

      raise "Unrecognized authorization message: #{msg_data.inspect}!"
    end
  end
end
