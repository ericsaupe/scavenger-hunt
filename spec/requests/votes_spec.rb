# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Votes" do
  include ActiveSupport::Testing::TimeHelpers

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

    expect(response.body).to include(%(data-vote-value-value="deny"), "Flagged", %(aria-pressed="true"))
    expect(response.body).to match(%r{2 of 3 flags\s*</span>})
  end

  it "shows the threshold as the count once flags go past it" do
    %w[a b c].each { |user_id| submission.votes.create!(user_id:, value: "deny") }

    vote("deny")

    expect(submission.votes.denied.count).to eq(4)
    expect(response.body).to match(%r{3 of 3 flags\s*</span>})
    expect(response.body).to include("Doesn't count")
  end

  describe "reactions on the big screen" do
    let(:stream) { hunt.presenter_stream }

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
      hunt.update!(presentation_slide: "submission:#{submission.id}")
      cookies[:user_id] = "viewer"
    end

    it "floats a reaction and updates the counts when the photo is on screen" do
      vote("love")

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
        .with(stream, hash_including(target: "reactions", partial: "presentations/reaction", locals: {value: "love"})).once
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(stream, hash_including(target: "submission_#{submission.id}_reactions", partial: "presentations/reaction_counts")).once
    end

    it "floats one reaction per viewer per second but always refreshes the counts" do
      vote("love")
      vote("deny")
      cookies[:user_id] = "someone else"
      vote("deny")

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(stream, hash_including(locals: {value: "love"})).once
      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(stream, hash_including(locals: {value: "deny"})).once
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(stream, hash_including(target: "submission_#{submission.id}_reactions")).exactly(3).times

      travel 2.seconds do
        cookies[:user_id] = "viewer"
        vote("love")
      end

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(stream, hash_including(locals: {value: "love"})).twice
    end

    it "updates the counts but floats nothing when a vote is taken back" do
      submission.votes.create!(user_id: "viewer", value: "love")

      vote("love")

      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to).with(stream, anything)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(stream, hash_including(target: "submission_#{submission.id}_reactions")).once
    end

    it "stays quiet when the photo is not the one on screen" do
      hunt.update!(presentation_slide: "finale")

      vote("love")

      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to).with(stream, anything)
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to).with(stream, anything)
    end

    it "checks the stored slide without building the whole sequence" do
      presentation = Presentation.new(hunt)
      expect(presentation).not_to receive(:keys)

      expect(presentation.presenting?(submission)).to be(true)
      submission.photo.purge
      expect(presentation.presenting?(submission)).to be(false)
    end
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
