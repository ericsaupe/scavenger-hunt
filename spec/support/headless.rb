# frozen_string_literal: true

Capybara.register_driver(:selenium_chrome_headless) do |app|
  options_key = :options
  browser_options = Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.add_argument("--headless")
    opts.add_argument("--disable-gpu") if Gem.win_platform?
    # Workaround https://bugs.chromium.org/p/chromedriver/issues/detail?id=2650&q=load&sort=-id&colspec=ID%20Status%20Pri%20Owner%20Summary
    opts.add_argument("--disable-site-isolation-trials")
    opts.add_preference("download.default_directory", Capybara.save_path)
    opts.add_preference(:download, default_directory: Capybara.save_path)
  end

  Capybara::Selenium::Driver.new(app, **{:browser => :chrome, options_key => browser_options})
end

Capybara.configure do |config|
  config.app_host = "http://lvh.me"
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    if ActiveModel::Type::Boolean.new.cast(ENV.fetch("SHOW_TEST_BROWSER", false))
      driven_by :selenium_chrome
    else
      driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
    end
  end
end
