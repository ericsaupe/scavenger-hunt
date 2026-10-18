# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Big screen fit" do
  let(:hunt) { create(:hunt, owner_id: "host", remote_holder_id: "host") }
  let(:team) { create(:team, hunt:) }

  before do
    @landscape = create(:photo_submission, item: hunt.items.first, team:)
    @portrait = create(:submission, item: hunt.items.second, team:)
    rotated = Vips::Image.new_from_file(Rails.root.join("spec/fixtures/test.jpg").to_s).rot90.write_to_buffer(".jpg")
    @portrait.photo.attach(io: StringIO.new(rotated), filename: "portrait.jpg", content_type: "image/jpeg")
    @video = create(:video_submission, item: hunt.items.third, team:)
  end

  def present(submission, width, height)
    hunt.update!(presentation_slide: "submission:#{submission.id}")
    emulate_viewport(width, height)
    visit "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
    expect(page).to have_css("#current_slide figure[style*='width']")
    settled
  end

  def settled
    layout = nil
    20.times do
      layout = measure
      break if (layout["width"].to_f / layout["height"] - layout["natural"]).abs < 0.02
      sleep 0.1
    end
    layout
  end

  def measure
    page.evaluate_script(<<~JS)
      (() => {
        const stage = document.querySelector("#current_slide")
        const figure = stage.querySelector("figure")
        const media = figure.querySelector("img, video")
        const frame = figure.getBoundingClientRect()
        const barTop = document.querySelector("[data-testid='join-line']").parentElement.getBoundingClientRect().top
        const pillBottom = document.querySelector("[data-testid='progress']").getBoundingClientRect().bottom
        const chat = document.querySelector("[data-testid='screen-chat']")
        const footer = document.querySelector("[data-fit-footer]")
        return {
          stagePaddingBottom: parseFloat(getComputedStyle(stage).paddingBottom),
          footerHeight: footer.offsetHeight,
          width: media.offsetWidth,
          height: media.offsetHeight,
          natural: media.naturalWidth ? media.naturalWidth / media.naturalHeight : media.videoWidth / media.videoHeight,
          room: barTop - pillBottom - (figure.offsetHeight - media.offsetHeight),
          stageWidth: (chat ? chat.getBoundingClientRect().left : innerWidth) - 104,
          top: frame.top, bottom: frame.bottom, left: frame.left, right: frame.right,
          barTop, pillBottom,
          chatLeft: chat ? chat.getBoundingClientRect().left : null,
          scrollable: document.documentElement.scrollHeight > innerHeight + 1
        }
      })()
    JS
  end

  def expect_fit(layout, viewport_height)
    expect(layout["width"].to_f / layout["height"]).to be_within(0.02).of(layout["natural"])
    expect(layout["top"]).to be >= layout["pillBottom"]
    expect(layout["bottom"]).to be <= layout["barTop"]
    expect(layout["left"]).to be >= 0
    expect(layout["scrollable"]).to be(false)
    expect(layout["stagePaddingBottom"]).to eq(layout["footerHeight"] + 16)
    expect(layout["height"]).to be > 0.5 * viewport_height
  end

  it "scales a landscape photo, a portrait photo and a video with the screen" do
    landscape = present(@landscape, 1920, 1080)
    expect_fit(landscape, 1080)
    expect(landscape["height"]).to be > 0.9 * landscape["room"]
    expect(landscape["natural"]).to be > 1.4

    portrait = present(@portrait, 1920, 1080)
    expect_fit(portrait, 1080)
    expect(portrait["height"]).to be > 0.9 * portrait["room"]
    expect(portrait["natural"]).to be < 0.7

    video = present(@video, 1920, 1080)
    expect_fit(video, 1080)
    expect(video["height"]).to be > 0.9 * video["room"]
    expect(video["natural"]).to be_within(0.02).of(16.0 / 9)
    expect(video["width"]).to be > 1300

    small = present(@landscape, 1280, 720)
    expect_fit(small, 720)
    expect(small["height"]).to be > 0.9 * small["room"]
    expect(small["height"]).to be < landscape["height"]

    small_portrait = present(@portrait, 1280, 720)
    expect_fit(small_portrait, 720)
    expect(small_portrait["height"]).to be < portrait["height"]
  end

  it "keeps the print beside the chat column and lets wide media use the full column width" do
    Flipper.enable(:chat)
    hunt.update!(screen_chat: "all")

    video = present(@video, 1920, 1080)
    expect_fit(video, 1080)
    expect(video["right"]).to be <= video["chatLeft"]
    expect(video["width"]).to be > 0.9 * video["stageWidth"]

    portrait = present(@portrait, 1920, 1080)
    expect_fit(portrait, 1080)
    expect(portrait["right"]).to be <= portrait["chatLeft"]
    expect(portrait["height"]).to be > 0.9 * portrait["room"]
  end

  it "leaves the watcher's phone and the remote preview on the fixed-size print" do
    hunt.update!(presentation_slide: "submission:#{@landscape.id}")
    emulate_viewport(390, 844)
    visit "/scavenger_hunts/#{hunt.code}/presenter"
    expect(page).to have_css("#current_slide figure:not([style*='width'])")
    expect(page).to have_css("#current_slide figure:not([data-controller~='fit'])")
    expect(page).to have_css("[data-testid='vote-menu']")
  end
end
