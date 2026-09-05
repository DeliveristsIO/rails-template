class CreateAiUsageEvents < ActiveRecord::Migration[8.2]
  def change
    create_table :ai_usage_events do |t|
      t.string :feature, null: false
      t.string :provider
      t.string :ai_model
      t.integer :llm_calls, null: false, default: 0
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cache_read_tokens, null: false, default: 0
      t.integer :cache_creation_tokens, null: false, default: 0
      t.integer :duration_ms, null: false, default: 0

      t.timestamps
    end

    add_index :ai_usage_events, :feature
    add_index :ai_usage_events, :created_at
  end
end
