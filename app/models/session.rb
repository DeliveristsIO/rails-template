# A row per signed-in browser, so a session can be ended from the server side
# rather than only by the cookie expiring.
class Session < ApplicationRecord
  belongs_to :user
end
