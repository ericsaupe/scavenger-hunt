# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Votes" do
  let(:hunt) { create(:hunt, max_downvotes_to_lose_points: 3) }
  let(:submission) do
    submission = create(:team, hunt:).submissions.find_by(item: hunt.items.first)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    submission
  end

  def vote(value)
    post "/submissions/#{submission.id}/votes", params: {vote: {value:}}, headers: {"Accept" => "text/vnd.turbo-stream.html"}
  end

  it "returns the flag count including the vote just cast" do
    submission.votes.create!(user_id: "someone", value: "deny")

    vote("deny")

    expect(response.body).to include(%(data-vote-value-value="deny"))
    expect(response.body).to match(%r{2 / 3\s*</span>})
  end

  it "keeps a single vote per viewer across a double tap" do
    cookies[:user_id] = "viewer"

    vote("love")
    vote("love")

    expect(response).to have_http_status(:ok)
    expect(submission.votes.where(user_id: "viewer").count).to eq(1)
  end

  it "reuses the row when a vote was inserted between the lookup and the insert" do
    submission.votes.create!(user_id: "viewer", value: "love")

    expect { submission.votes.create_or_find_by!(user_id: "viewer") }.not_to change(Vote, :count)
    expect(submission.votes.create_or_find_by!(user_id: "viewer")).to be_loved
  end
end
