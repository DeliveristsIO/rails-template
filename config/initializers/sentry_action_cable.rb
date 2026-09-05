# frozen_string_literal: true

# sentry-rails 7.0.0 prepends handle_open/handle_close onto the ActionCable
# connection as *private* methods. That was right when the connection called
# them on itself. Rails edge split the socket from the connection, and
# ActionCable::Server::Socket now calls them on the connection from outside:
#
#   NoMethodError: private method 'handle_close' called for an instance of
#   ActionCable::Connection::Base
#
# So the socket raises the moment it opens, closes, raises again on the way
# out, and the browser reconnects forever. Nothing logs a failure on the page,
# the WebSocket handshake even returns 101 — the live progress screen simply
# never updates, which is the one screen this product demos.
#
# Restoring the visibility Rails expects is the whole fix. Delete this when
# sentry-rails catches up with the socket/connection split.
# Sentry hangs its prepend off the same load hook and only requires the module
# from inside it, so this has to run on the hook too — a bare `defined?` at
# initializer time finds nothing and skips silently.
ActiveSupport.on_load(:action_cable_connection) do
  if defined?(Sentry::Rails::ActionCableExtensions::Connection)
    Sentry::Rails::ActionCableExtensions::Connection.class_eval do
      public :handle_open, :handle_close
    end
  end
end
