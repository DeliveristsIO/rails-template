require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  test "supports the three launch languages" do
    assert_equal %i[ en de pl ], I18n.available_locales
  end

  # A locale with no translation must fall back rather than render the key at a
  # visitor. `bin/ci` runs i18n-tasks health, which is what catches a key that
  # exists in one language and not the others; this is the guard on the setting
  # that decides what happens when one slips through anyway.
  test "a missing translation falls back to English rather than to the key" do
    assert_equal [ :en ], Array(I18n.fallbacks[:de]).last(1)
    assert_equal "en", I18n.default_locale.to_s
  end
end
