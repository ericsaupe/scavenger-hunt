# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams" do
  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end

  def find(team, item)
    team.submissions.find_by(item:).photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
  end

  it "renders the checklist with the same number of queries however many items there are" do
    hunt = create(:hunt)
    team = create(:team, hunt:)
    find(team, hunt.items.first)
    path = "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
    get path
    few = queries_for(path)

    category = create(:category, hunt:)
    create_list(:item, 4, category:)
    hunt.items.reload.each { |item| team.submissions.find_or_create_by!(item:) }
    hunt.items.last(3).each { |item| find(team, item) }
    many = queries_for(path)

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('data-testid="preview"').size).to eq(4)
    expect(many).to eq(few)
  end
end
