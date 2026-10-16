# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Items" do
  let(:hunt) { create(:hunt, max_downvotes_to_lose_points: 3) }
  let(:items) { hunt.items.order(:id).to_a }

  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end

  def found_by_new_team(item)
    team = create(:team, hunt:)
    submission = team.submissions.find_by(item:)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    submission
  end

  it "shows the viewer's vote and the flags on each photo" do
    submission = found_by_new_team(items.first)
    submission.votes.create!(user_id: "viewer", value: "love")
    submission.votes.create!(user_id: "someone", value: "deny")
    submission.votes.create!(user_id: "someone else", value: "deny")
    cookies[:user_id] = "viewer"

    get "/scavenger_hunts/#{hunt.code}/items/#{items.first.id}"

    expect(response.body).to include(%(data-vote-value-value="love"))
    expect(response.body).to match(%r{2 / 3\s*</span>})
  end

  it "links to the previous and next found items, wrapping around the ends" do
    items.each { |item| found_by_new_team(item) }
    first, middle, last = items

    get "/scavenger_hunts/#{hunt.code}/items/#{middle.id}"
    expect(response.body).to include(%(href="/scavenger_hunts/#{hunt.code}/items/#{first.id}"), %(href="/scavenger_hunts/#{hunt.code}/items/#{last.id}"))

    get "/scavenger_hunts/#{hunt.code}/items/#{last.id}"
    expect(response.body).to include(%(href="/scavenger_hunts/#{hunt.code}/items/#{middle.id}"), %(href="/scavenger_hunts/#{hunt.code}/items/#{first.id}"))
  end

  it "renders the gallery with the same number of queries however many teams found the item" do
    found_by_new_team(items.first).votes.create!(user_id: "someone", value: "deny")
    path = "/scavenger_hunts/#{hunt.code}/items/#{items.first.id}"
    get path
    few = queries_for(path)

    3.times { found_by_new_team(items.first).votes.create!(user_id: "someone", value: "love") }
    many = queries_for(path)

    expect(response).to have_http_status(:ok)
    expect(many).to eq(few)
  end
end
