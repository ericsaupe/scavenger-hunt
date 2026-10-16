# frozen_string_literal: true

module NetworkHelpers
  def go_offline
    page.driver.browser.network_conditions = {offline: true, latency: 0, download_throughput: 0, upload_throughput: 0}
  end

  def go_online
    page.driver.browser.delete_network_conditions
    page.execute_script("window.dispatchEvent(new Event('online'))")
  end

  def wait_for_service_worker
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      navigator.serviceWorker.ready.then(() => {
        if (navigator.serviceWorker.controller) return done(true)
        navigator.serviceWorker.addEventListener("controllerchange", () => done(true), { once: true })
      })
    JS
  end

  def wait_for_page_cached
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const url = location.href
      const cached = async () => {
        for (const name of (await caches.keys()).filter((name) => name.startsWith("pages-"))) {
          if (await (await caches.open(name)).match(url, { ignoreVary: true })) return true
        }
        return false
      }
      const poll = async () => {
        for (let i = 0; i < 100; i++) {
          if (await cached()) return done(true)
          await new Promise((resolve) => setTimeout(resolve, 100))
        }
        done(false)
      }
      poll()
    JS
  end

  def clear_upload_queue
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const request = indexedDB.deleteDatabase("scavenger-hunt-party")
      request.onsuccess = request.onerror = request.onblocked = () => done(true)
    JS
  end

  def forget_service_worker
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      Promise.all([
        navigator.serviceWorker.getRegistrations().then((registrations) => Promise.all(registrations.map((r) => r.unregister()))),
        caches.keys().then((names) => Promise.all(names.map((name) => caches.delete(name))))
      ]).then(() => done(true), () => done(false))
    JS
  end
end

RSpec.configure do |config|
  config.include NetworkHelpers, type: :system

  config.around(:each, :secure_origin) do |example|
    original = Capybara.app_host
    Capybara.app_host = "http://localhost"
    example.run
  ensure
    Capybara.app_host = original
  end

  config.after(:each, type: :system) do
    page.driver.browser.delete_network_conditions if page.driver.browser.respond_to?(:delete_network_conditions)
  end
end
