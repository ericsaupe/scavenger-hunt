# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Photo URLs" do
  it "serves a processed thumbnail from the permanent URL" do
    submission = create(:photo_submission)

    get submission.small_variant_url
    expect(response).to have_http_status(:found)

    get response.location
    image = Vips::Image.new_from_buffer(response.body, "")
    expect(response.media_type).to eq("image/jpeg")
    expect([image.width, image.height].max).to eq(500)
  end

  it "serves the original video from the permanent URL" do
    submission = create(:video_submission)

    get submission.large_variant_url
    expect(response).to have_http_status(:found)

    get response.location
    expect(response.body).to eq(Rails.root.join("spec/fixtures/video.mp4").binread)
  end
end
