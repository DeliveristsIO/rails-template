# frozen_string_literal: true

require "test_helper"

# The live progress screen is the product demo, and it is invisible to every
# other test: a socket that dies on open still returns 101 and logs nothing the
# page can see. This asserts the one property Rails needs from whatever ends up
# prepended onto the connection.
class ActionCableConnectionTest < ActiveSupport::TestCase
  test "the connection exposes the hooks ActionCable::Server::Socket calls on it" do
    ActionCable::Connection::Base # the load hook only fires once the class is referenced

    %i[ handle_open handle_close ].each do |hook|
      assert ActionCable::Connection::Base.public_method_defined?(hook),
        "#{hook} is not public — a gem has prepended it privately and every WebSocket will die on open"
    end
  end
end
