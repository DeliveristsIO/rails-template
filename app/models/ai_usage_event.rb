# frozen_string_literal: true

# One row per LLM call, so what a feature costs to run is a query rather than a
# guess — and so a free tier's ceilings can be calibrated against what the
# traffic actually spends rather than against an estimate.
#
# TEMPLATE: `FEATURES` is the list of things in this product that call a model.
# Name them after the user-visible feature, not after the class that makes the
# call, because the question this table answers is "what does X cost us".
#
# Metering must never break the feature it observes: `record!` swallows its own
# failures, because losing a usage row is cheaper than losing the answer.
class AiUsageEvent < ApplicationRecord
  FEATURES = %w[ generation ].freeze

  validates :feature, inclusion: { in: FEATURES }

  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..) }

  def self.record!(feature:, provider: nil, ai_model: nil, llm_calls: 1,
                   input_tokens: 0, output_tokens: 0, cache_read_tokens: 0,
                   cache_creation_tokens: 0, duration_ms: 0)
    create!(feature:, provider:, ai_model:, llm_calls:,
            input_tokens:, output_tokens:, cache_read_tokens:, cache_creation_tokens:, duration_ms:)
  rescue StandardError => e
    Rails.logger.error("ai usage metering failed: #{e.class}: #{e.message}")
    nil
  end

  def total_tokens
    input_tokens + output_tokens
  end
end
