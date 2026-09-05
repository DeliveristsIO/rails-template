require "test_helper"

# The tiers are shipped copy and shipped enforcement at the same time: the
# pricing table and the refusal read the same object, so a plan that says one
# thing on the page and another in a validation cannot exist.
class PlanTest < ActiveSupport::TestCase
  # The promise the whole tier system is built on. An account that has paid
  # nothing must be able to do today exactly what it could do before there
  # were plans at all.
  test "the free plan has a number for every ceiling" do
    free = Plan.free

    assert_equal 3, free.projects
    assert_equal 1, free.seats
    assert_equal 300, free.api_requests_per_hour
  end

  test "a paid plan never lowers a ceiling" do
    Plan.paid.each do |plan|
      Plan::DEFINITIONS[Plan::FREE].each_key do |ceiling|
        next if ceiling == :cents

        assert_operator plan.public_send(ceiling), :>=, Plan.free.public_send(ceiling),
                        "#{plan.key} lowers #{ceiling}"
      end
    end
  end

  test "the plans are ordered by price and each one buys something" do
    assert_equal 0, Plan.free.price_cents
    assert_equal Plan.paid.map(&:price_cents).sort, Plan.paid.map(&:price_cents)
    Plan.paid.each { |plan| assert_operator plan.price_cents, :>, 0 }
  end

  # Repricing a tier has to be a deploy setting, or the number in the code and
  # the number Stripe charges drift the first time somebody wants a promotion.
  test "the environment reprices a tier" do
    ENV["PLAN_STARTER_CENTS"] = "1200"

    assert_equal 1_200, Plan.find(Plan::STARTER).price_cents
  ensure
    ENV.delete("PLAN_STARTER_CENTS")
  end

  test "an unknown plan key is nobody's plan" do
    assert_nil Plan.find("enterprise")
    assert_nil Plan.find(nil)
  end

  # The column is a cache of what Stripe last said. The subscription status is
  # what decides whether it is still true, which is the difference between a
  # card that stopped working and an account that keeps its raised ceilings.
  test "a lapsed subscription reads as free however the column reads" do
    user = users(:reader)
    user.update!(plan: Plan::BUSINESS, subscription_status: "past_due")

    assert_equal Plan::FREE, Plan.for(user).key
    assert_equal Plan.free.projects, Plan.for(user).projects
  end

  test "a live subscription reads as the plan it paid for" do
    user = users(:reader)
    user.update!(plan: Plan::TEAM, subscription_status: "trialing")

    assert_equal Plan::TEAM, Plan.for(user).key
  end

  test "nobody at all is on the free plan" do
    assert_equal Plan::FREE, Plan.for(nil).key
  end

  # Every tier has to be sayable in every language the app ships in, or the
  # pricing table renders a translation-missing span at a customer.
  test "every plan is named in every locale" do
    I18n.available_locales.each do |locale|
      Plan.all.each do |plan|
        assert I18n.exists?("plans.#{plan.key}.name", locale), "plans.#{plan.key}.name missing for #{locale}"
        assert I18n.exists?("plans.#{plan.key}.summary", locale), "plans.#{plan.key}.summary missing for #{locale}"
      end
    end
  end
end
