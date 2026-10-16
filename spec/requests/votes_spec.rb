# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Votes" do
  it "returns the flag count including the vote just cast" do
    hunt = create(:hunt, max_downvotes_to_lose_points: 3)
    submission = create(:team, hunt:).submissions.find_by(item: hunt.items.first)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    submission.votes.create!(user_id: "someone", value: "deny")

    post "/submissions/#{submission.id}/votes", params: {vote: {value: "deny"}}, headers: {"Accept" => "text/vnd.turbo-stream.html"}

    expect(response.body).to include(%(data-vote-value-value="deny"))
    expect(response.body).to match(%r{2 / 3\s*</span>})
  end
end
