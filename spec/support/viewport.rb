# frozen_string_literal: true

module ViewportHelpers
  def emulate_viewport(width, height)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 2, mobile: width < 768)
    @viewport_emulated = true
  end
end

RSpec.configure do |config|
  config.include ViewportHelpers, type: :system

  config.after(:each, type: :system) do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if @viewport_emulated
  end
end
