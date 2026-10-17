# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Active Storage redirects" do
  let(:submission) { create(:photo_submission) }

  it "keeps the signed link alive well past the time a browser may reuse the redirect" do
    expect(ActiveStorage.service_urls_expire_in).to eq(15.minutes)
    expect(ActiveStorageRedirectCaching::REDIRECT_CACHE).to be < ActiveStorage.service_urls_expire_in
  end

  it "lets a browser cache a variant redirect for five minutes" do
    get submission.small_variant_url

    expect(response).to have_http_status(:found)
    expect(response.headers["Cache-Control"]).to include("max-age=300")
  end

  it "lets a browser cache a blob redirect for five minutes" do
    get submission.media_url

    expect(response).to have_http_status(:found)
    expect(response.headers["Cache-Control"]).to include("max-age=300")
  end
end
