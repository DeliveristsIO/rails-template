# An account: an email address, a password, and whatever Stripe last said about
# what it is paying for. Deliberately small — password reset, email
# verification and profiles are all absent, because none of them are needed to
# sign in and every one of them is friction on the first form a visitor meets.
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # Typed on a phone, mid-flow, by someone who wants in. Case and a trailing
  # space must not create a second account.
  normalizes :email_address, with: ->(email) { email.to_s.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  # BCrypt truncates silently past 72 bytes, so the maximum is the algorithm's
  # rather than a policy.
  validates :password, length: { minimum: 12, maximum: 72 }, allow_nil: true

  validates :plan, inclusion: { in: Plan::KEYS }

  # A subscription Stripe is still charging for. `trialing` counts because a
  # trial is a subscription somebody is inside; everything else — past_due,
  # unpaid, canceled, incomplete — does not, so a card that stopped working
  # drops the account to the free ceilings rather than leaving it on a tier
  # nobody is paying for.
  LIVE_STATUSES = %w[ active trialing ].freeze

  def subscription_live? = LIVE_STATUSES.include?(subscription_status)

  # `plan` is the string Stripe last told us; `current_plan` is the object that
  # answers what this account may do, which is not the same thing the moment a
  # payment fails.
  def current_plan = Plan.for(self)

  # Adopting what Stripe says, in one place, because every event that can
  # change a subscription ends here: the checkout that created it, the update
  # that switched or renewed it, and the deletion that ended it. Idempotent by
  # construction — Stripe redelivers, and the second delivery must land on the
  # same row values as the first.
  def adopt_subscription!(id:, status:, plan:, customer_id: nil, period_ends_at: nil)
    live = LIVE_STATUSES.include?(status.to_s)

    update!(
      stripe_subscription_id: id,
      stripe_customer_id: customer_id.presence || stripe_customer_id,
      subscription_status: status.to_s.presence,
      plan: (live && Plan::KEYS.include?(plan.to_s)) ? plan.to_s : Plan::FREE,
      plan_period_ends_at: period_ends_at
    )
  end
end
