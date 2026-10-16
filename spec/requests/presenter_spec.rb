# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Presenter" do
  let(:hunt) { create(:hunt, owner_id: "owner") }
  let(:items) { hunt.items.order(:id).to_a }
  let(:first_team) { create(:team, hunt:) }
  let(:second_team) { create(:team, hunt:) }

  before { cookies[:user_id] = "owner" }

  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end

  def found(team, item)
    submission = team.submissions.find_by(item:)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    submission
  end

  def presenter_link(submission)
    %(href="/scavenger_hunts/#{hunt.code.upcase}/presenter?submission_id=#{submission.id}")
  end

  it "links to the neighbouring photos in item and team order, wrapping around the ends" do
    first = found(first_team, items.first)
    second = found(second_team, items.first)
    third = found(first_team, items.second)

    get "/scavenger_hunts/#{hunt.code}/presenter?submission_id=#{second.id}"
    expect(response.body).to include(presenter_link(first), presenter_link(third))
    expect(hunt.reload.presentation_submission).to eq(second)

    get "/scavenger_hunts/#{hunt.code}/presenter?submission_id=#{third.id}"
    expect(response.body).to include(presenter_link(second), presenter_link(first))
  end

  it "renders with the same number of queries however many photos there are" do
    found(first_team, items.first)
    path = "/scavenger_hunts/#{hunt.code}/presenter"
    get path
    few = queries_for(path)

    found(second_team, items.first)
    found(first_team, items.second)
    found(second_team, items.third)
    many = queries_for(path)

    expect(response).to have_http_status(:ok)
    expect(many).to eq(few)
  end
end
