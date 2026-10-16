# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pending uploads" do
  include ActiveSupport::Testing::TimeHelpers

  let(:hunt) { create(:hunt, ends_at: 5.minutes.ago) }
  let(:team) { create(:team, hunt:) }
  let(:other_team) { create(:team, hunt:) }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  def report(team, count, client: "phone-a")
    post "/scavenger_hunts/#{hunt.code}/teams/#{team.id}/pending_uploads", params: {count:, client:}, as: :json
  end

  it "remembers how many photos each team still has queued" do
    report(team, 2)
    expect(response).to have_http_status(:no_content)
    report(other_team, 1)

    expect(hunt.pending_upload_count).to eq(3)
  end

  it "adds up the queues of every phone on a team" do
    report(team, 2, client: "phone-a")
    report(team, 1, client: "phone-b")
    expect(hunt.pending_upload_count).to eq(3)

    report(team, 0, client: "phone-a")
    expect(hunt.pending_upload_count).to eq(1)
  end

  it "needs to know which phone is reporting" do
    post "/scavenger_hunts/#{hunt.code}/teams/#{team.id}/pending_uploads", params: {count: 2}, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(hunt.pending_upload_count).to eq(0)
  end

  it "forgets the count after a short while" do
    report(team, 2)

    travel_to (Team::PENDING_UPLOADS_TTL + 1.second).from_now do
      expect(hunt.pending_upload_count).to eq(0)
    end
  end

  it "tells the organizer on the results page while the grace window is open" do
    report(team, 2)
    get "/scavenger_hunts/#{hunt.code}/results"

    expect(response.body).to include("2 photos still uploading")
  end

  it "says nothing once the grace window has closed" do
    hunt.update!(ends_at: Hunt::LATE_UPLOAD_GRACE.ago - 1.minute)
    report(team, 2)
    get "/scavenger_hunts/#{hunt.code}/results"

    expect(response.body).not_to include("still uploading")
  end

  it "says nothing when no team reported queued photos, but keeps refreshing during the grace window" do
    get "/scavenger_hunts/#{hunt.code}/results"

    expect(response.body).not_to include("still uploading")
    expect(response.body).to include('data-testid="grace-window"')
  end

  it "stops refreshing once the grace window has closed" do
    hunt.update!(ends_at: Hunt::LATE_UPLOAD_GRACE.ago - 1.minute)
    get "/scavenger_hunts/#{hunt.code}/results"

    expect(response.body).not_to include('data-testid="grace-window"')
  end
end
