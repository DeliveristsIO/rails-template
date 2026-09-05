source "https://rubygems.org"

# Pin Rails to a known-compatible commit.
gem "rails", github: "rails/rails", branch: "main"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing"

# Rails locale data including pluralization rules [https://github.com/svenfuchs/rails-i18n]
gem "rails-i18n"

# Feature flag management [https://github.com/flippercloud/flipper]
gem "flipper", github: "flippercloud/flipper", branch: "main"
gem "flipper-active_record", github: "flippercloud/flipper", branch: "main"
gem "flipper-ui", github: "flippercloud/flipper", branch: "main"

# Blocks and throttles abusive requests [https://github.com/rack/rack-attack]
gem "rack-attack"

# Subscriptions and the billing portal [https://github.com/stripe/stripe-ruby]
gem "stripe", "~> 18"

# CSV support for Ruby 3.4+ [https://github.com/ruby/csv]
gem "csv"

# Error tracking and performance monitoring [https://sentry.io/]
gem "sentry-ruby"
gem "sentry-rails"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Load environment variables from .env file [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Finds missing and unused I18n translations [https://github.com/glebm/i18n-tasks]
  gem "i18n-tasks", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Stub HTTP requests in tests [https://github.com/bblimke/webmock]
  gem "webmock", require: false

  # Mocking and stubbing library [https://github.com/freerange/mocha]
  gem "mocha", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Preview email in the browser instead of sending it [https://github.com/ryanb/letter_opener]
  gem "letter_opener"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
