
# Accounts and their relatives are a potentially bottomless hole of
# technical interest and difficulty.  I'm handling this in a really
# simple way: Bcrypt exchange over HTTPS/WSS is built into
# Demiurge-Createjs, and it's not too hard to plug something else in
# if you're so inclined. Accounts, by default, get synced into a JSON
# file, but it'd be easy to write a little Ruby plugin to synchronize
# accounts in some other way. To Postgres, maybe?
#
# This works for now. But mostly, it's easy to replace if it needs to
# work in some other way.

# This module should be included into the Demiurge-Createjs app.  The
# engine_sync object should be set early on, using the
# set_accounts_engine_sync method.
module Demiurge::Createjs
  module JsonAccounts
    ACCOUNT_NAME_REGEX = /[a-zA-Z0-9]+/
    def websocket_send(socket, *args)
      socket.send MultiJson.dump(args)
    end

    def set_accounts_json_filename(filename)
      @accounts_json_filename = filename
      @accounts_old_json_filename = filename + ".old"
      sync_account_state
    end

    def sync_account_state
      unless @account_state
        if File.exist?(@accounts_json_filename)
          @account_state = MultiJson.load(File.read @accounts_json_filename)
        else
          @account_state = {}
        end
      end

      if File.exist?(@accounts_json_filename)
        FileUtils.mv @accounts_json_filename, @accounts_old_json_filename
      end
      File.open(@accounts_json_filename, "w") do |f|
        f.write MultiJson.dump(@account_state, :pretty => true)
      end
    end

    # Process an authorization message
    def on_auth_message(websocket, msg_type, *args)
      sync_account_state

      if msg_type == "register_account"
        username, salt, hashed = args[0]["username"], args[0]["salt"], args[0]["bcrypted"]
        if @account_state[username]
          websocket_send websocket, "failed_registration", "Account #{username.inspect} already exists!"
          return
        end
        unless username =~ ACCOUNT_NAME_REGEX
          websocket_send websocket, "failed_registration", "Account name contains illegal characters: #{username.inspect}!"
          return
        end
        @account_state[username] = { "account" => { "salt" => salt, "hashed" => hashed, "method" => "bcrypt" } }
        sync_account_state
        websocket_send websocket, "registration", { "account" => username }

        return
      end
      if msg_type == "hashed_login"
        username, hashed = args[0]["username"], args[0]["bcrypted"]
        unless @account_state[username]
          websocket_send websocket, "failed_login", "No such user as #{username.inspect}!"
          return
        end
        if @account_state[username]["account"]["hashed"] == hashed
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
        unless @account_state[username]
          websocket_send websocket, "failed_login", "No such usr as #{username.inspect}!"
          return
        end
        user_salt = @account_state[username]["account"]["salt"]
        websocket_send websocket, "login_salt", user_salt
        return
      end

      raise "Unrecognized authorization message: #{msg_data.inspect}!"
    end
  end
end
