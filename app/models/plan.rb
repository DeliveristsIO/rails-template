# frozen_string_literal: true

# What an account is allowed to do, and what that costs.
#
# A value object rather than a table. The tiers are a product decision that
# belongs in the repository with the code that enforces them — a row somebody
# edited in an admin screen last March is not an answer to "why did this
# account get refused". Stripe holds the money and the billing history; this
# holds the ceilings.
#
# TEMPLATE: rename the ceilings below to whatever this product actually meters,
# then define one `Model.ceiling_for(user)` per ceiling rather than scattering
# `Plan.for(user).thing` through the views. Two rules are worth keeping. Every
# number on the free plan must be the constant it replaced, unchanged, so an
# account that has paid nothing can do today exactly what it could do
# yesterday; and a plan raises a ceiling, never lowers one.
class Plan
  FREE = "free"
  STARTER = "starter"
  TEAM = "team"
  BUSINESS = "business"

  # Prices are read from the environment so a repricing is a deploy setting
  # rather than a code change.
  DEFINITIONS = {
    FREE => { cents: 0, projects: 3, seats: 1, api_requests_per_hour: 300 },
    STARTER => { cents: 900, projects: 10, seats: 3, api_requests_per_hour: 1_200 },
    TEAM => { cents: 2_900, projects: 50, seats: 10, api_requests_per_hour: 4_000 },
    BUSINESS => { cents: 7_900, projects: 250, seats: 50, api_requests_per_hour: 20_000 }
  }.freeze

  KEYS = DEFINITIONS.keys.freeze
  PAID = (KEYS - [ FREE ]).freeze

  attr_reader :key

  class << self
    def all = KEYS.map { |key| new(key) }

    def paid = PAID.map { |key| new(key) }

    def find(key) = KEYS.include?(key.to_s) ? new(key.to_s) : nil

    def free = new(FREE)

    # The plan a user is actually on. A user whose subscription has lapsed
    # reads as free here even if the column still says otherwise, because the
    # column is a cache of what Stripe last told us and the subscription
    # status is the thing that says whether it is still true.
    def for(user)
      return free if user.nil? || !user.subscription_live?

      find(user.plan) || free
    end
  end

  def initialize(key)
    @key = key
  end

  DEFINITIONS[FREE].each_key do |ceiling|
    define_method(ceiling) { DEFINITIONS.fetch(key).fetch(ceiling) }
  end

  def free? = key == FREE
  def paid? = !free?

  def name = I18n.t("plans.#{key}.name")
  def summary = I18n.t("plans.#{key}.summary")

  # Cents rather than a formatted string: the view formats it, and a currency
  # this product does not sell in has no business being invented here. The
  # environment wins, so repricing a tier is a deploy setting rather than a
  # code change.
  def price_cents = (ENV["PLAN_#{key.upcase}_CENTS"].presence || cents).to_i

  def ==(other) = other.is_a?(Plan) && other.key == key
  alias eql? ==
  def hash = key.hash
end
