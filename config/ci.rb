# Run using bin/ci
# NOTE: CI assumes dependencies are already installed (via bin/setup or CI environment setup)

CI.run do
  step "Style: Ruby", "bin/rubocop --no-server -A"

  step "I18n: missing/unused translations", "bundle exec i18n-tasks health"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: Rails", "env PARALLEL_WORKERS=4 bin/rails test"
end
