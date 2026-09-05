require "test_helper"

# Every deployed environment needs a section in each of these, and a missing
# one is not a config nit: solid_cable's production section is what
# SolidCable.connects_to reads, and its absence took the first staging deploy
# down with `undefined method 'connects_to' for nil` after the image had built,
# pushed and booted. The failure surfaces only on the box.
class DeploymentConfigTest < ActiveSupport::TestCase
  DEPLOYED_ENVIRONMENTS = %w[ staging production ].freeze
  CONFIGS = %w[ database cable cache queue recurring ].freeze

  CONFIGS.each do |config|
    DEPLOYED_ENVIRONMENTS.each do |environment|
      test "config/#{config}.yml has a #{environment} section" do
        assert_includes load_config(config).keys, environment,
          "#{environment} boots against config/#{config}.yml and would fail on the host, not here"
      end
    end
  end

  test "every deployed environment has an environment file" do
    DEPLOYED_ENVIRONMENTS.each do |environment|
      assert File.exist?(Rails.root.join("config/environments/#{environment}.rb")), environment
    end
  end

  # Kamal reads these before it builds anything, and a YAML error in one of
  # them is a deploy that fails after the image has pushed.
  test "every kamal destination parses and names a service" do
    assert YAML.load_file(Rails.root.join("config/deploy.yml"))["service"].present?

    DEPLOYED_ENVIRONMENTS.each do |destination|
      config = YAML.load_file(Rails.root.join("config/deploy.#{destination}.yml"))

      assert config["servers"].present?, "#{destination} has no servers"
      assert_equal "/up", config.dig("proxy", "healthcheck", "path")
      assert_equal false, config.dig("env", "clear", "SOLID_QUEUE_IN_PUMA"),
        "#{destination} runs jobs in their own container, so Puma must not also supervise them"
    end
  end

  private
    def load_config(name)
      YAML.load(ERB.new(Rails.root.join("config/#{name}.yml").read).result, aliases: true)
    end
end
