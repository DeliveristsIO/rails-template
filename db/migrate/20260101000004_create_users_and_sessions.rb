class CreateUsersAndSessions < ActiveRecord::Migration[8.2]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false

      # The plan is on the user rather than in a subscriptions table because a
      # user has exactly one, and the history of what they used to be on lives
      # in Stripe, which is the system of record for money. These columns are a
      # cache of what Stripe last told us; `User#subscription_live?` is what
      # decides whether the cache is still true.
      t.string :plan, null: false, default: "free"
      t.string :subscription_status
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.datetime :plan_period_ends_at

      t.timestamps
    end

    add_index :users, :email_address, unique: true
    add_index :users, :stripe_customer_id, unique: true
    add_index :users, :stripe_subscription_id, unique: true

    # A row per signed-in browser, so a session can be ended from the server
    # side rather than only by the cookie expiring.
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
