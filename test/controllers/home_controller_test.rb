require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "the landing page renders" do
    get root_path

    assert_response :success
    assert_select "h1", I18n.t("home.hero.heading")
  end

  # Three languages from the first view, negotiated the way a browser
  # negotiates them.
  test "serves the language the browser asks for" do
    get root_path, headers: { "Accept-Language" => "de-DE,de;q=0.9" }

    assert_select "h1", I18n.t("home.hero.heading", locale: :de)
  end

  test "an explicit locale parameter wins over the browser" do
    get root_path(locale: "pl"), headers: { "Accept-Language" => "de-DE,de;q=0.9" }

    assert_select "h1", I18n.t("home.hero.heading", locale: :pl)
  end

  test "an unknown locale falls back rather than raising" do
    get root_path(locale: "zz")

    assert_response :success
    assert_select "h1", I18n.t("home.hero.heading", locale: :en)
  end

  # A page that renders a translation-missing span at a visitor is a page
  # nobody looked at in that language.
  test "no locale renders a missing translation" do
    I18n.available_locales.each do |locale|
      get root_path(locale: locale)

      assert_no_match(/translation missing/i, response.body, locale.to_s)
    end
  end

  test "the masthead offers a way in and a way out of the account" do
    get root_path
    assert_select "a[href=?]", sign_in_path

    sign_in_as
    get root_path
    assert_select "a[href=?]", subscription_path
  end
end
