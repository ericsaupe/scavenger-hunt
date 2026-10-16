# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Hunts" do
  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end

  def add_team_with_photos(hunt)
    team = create(:team, hunt:)
    hunt.items.first(2).each do |item|
      team.submissions.find_by(item:).photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    end
  end

  it "renders the results with the same number of queries however many teams there are" do
    hunt = create(:hunt)
    add_team_with_photos(hunt)
    path = "/scavenger_hunts/#{hunt.code}/results"
    get path
    few = queries_for(path)

    3.times { add_team_with_photos(hunt) }
    many = queries_for(path)

    expect(response).to have_http_status(:ok)
    expect(many).to eq(few)
  end
end
