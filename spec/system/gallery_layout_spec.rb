# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Gallery layout" do
  let(:hunt) { create(:hunt) }
  let(:team) { create(:team, hunt:) }
  let!(:photo) { create(:photo_submission, item: hunt.items.first, team:) }

  def resize(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def measure
    page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector("#items figure")
        const media = card.querySelector("img, video")
        const rect = media.getBoundingClientRect()
        return {
          scrollable: document.documentElement.scrollHeight > window.innerHeight + 1,
          cardWidth: card.style.width,
          mediaHeight: Math.round(rect.height),
          mediaBottom: Math.round(rect.bottom),
          barTop: Math.round(document.querySelector(".bottom-bar").getBoundingClientRect().top)
        }
      })()
    JS
  end

  it "fits the page to a laptop screen without scrolling" do
    resize(1440, 800)
    visit "/scavenger_hunts/#{hunt.code}/items/#{hunt.items.first.id}"
    expect(page).to have_css("#items figure[style*='width']")

    layout = measure
    expect(layout["scrollable"]).to be(false)
    expect(layout["mediaBottom"]).to be < layout["barTop"]
    expect(layout["mediaHeight"]).to be > 200
  end

  it "keeps the scrolling card on a short landscape phone" do
    resize(812, 375)
    visit "/scavenger_hunts/#{hunt.code}/items/#{hunt.items.first.id}"
    expect(page).to have_css("#items figure")

    layout = measure
    expect(layout["cardWidth"]).to eq("")
    expect(layout["mediaHeight"]).to be > 300
    expect(layout["scrollable"]).to be(true)
  end
end
