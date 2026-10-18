# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Checklist sections" do
  let(:hunt) { create(:hunt).tap { |hunt| hunt.categories.first.update!(name: "One Point") } }
  let(:category) { hunt.categories.first }
  let(:team) { create(:team, hunt:) }
  let(:team_path) { "/scavenger_hunts/#{hunt.code}/teams/#{team.id}" }

  def find_item(item)
    team.submissions.find_by(item:).photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "#{item.id}.jpg")
  end

  def wait_for_live_updates
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
    expect(page).not_to have_css("turbo-cable-stream-source:not([connected])", visible: :all)
  end

  def section(category)
    find("section", text: category.name)
  end

  def top_of(selector)
    page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().top")
  end

  it "folds a section from its header and remembers it after a reload" do
    visit team_path
    expect(page).to have_button(category.items.first.name)

    click_on category.name
    expect(page).to have_css("section[data-folded]", text: "0 of 3 found")
    expect(page).not_to have_button(category.items.first.name)

    page.refresh
    expect(page).to have_css("section[data-folded]", text: "0 of 3 found")
    expect(page).not_to have_button(category.items.first.name)

    click_on category.name
    expect(page).to have_button(category.items.first.name)

    page.refresh
    expect(page).to have_button(category.items.first.name)
    expect(page).not_to have_css("section[data-folded]")
  end

  it "keeps the found count up to date while folded" do
    visit team_path
    click_on category.name
    expect(page).to have_css("section[data-folded]", text: "0 of 3 found")
    wait_for_live_updates

    find_item(category.items.first)
    expect(page).to have_css("section[data-folded]", text: "1 of 3 found")
  end

  it "folds a finished section and keeps it open once it is unfolded" do
    category.items.each { |item| find_item(item) }
    visit team_path
    expect(page).to have_css("section[data-folded][data-complete]", text: "All 3 found")
    expect(page).not_to have_css("[data-testid='preview']")

    click_on category.name
    expect(page).to have_css("[data-testid='preview']", count: 3)

    page.refresh
    expect(page).to have_css("[data-testid='preview']", count: 3)
    expect(page).not_to have_css("section[data-folded]")
  end

  it "folds a section once a teammate finds its last item" do
    category.items.first(2).each { |item| find_item(item) }
    visit team_path
    expect(page).to have_css("[data-testid='preview']", count: 2)
    expect(page).not_to have_css("section[data-folded]")
    wait_for_live_updates

    find_item(category.items.last)
    expect(page).to have_css("section[data-folded][data-complete]", text: "All 3 found")
  end

  it "still folds a finished section that the team folded and unfolded earlier" do
    visit team_path
    click_on category.name
    click_on category.name
    expect(page).to have_button(category.items.first.name)
    wait_for_live_updates

    category.items.each { |item| find_item(item) }
    expect(page).to have_css("section[data-folded][data-complete]", text: "All 3 found")
  end

  it "keeps the team's place when a section above them folds" do
    create_list(:item, 9, category:)
    later = create(:category, hunt:, name: "Five Points")
    create_list(:item, 10, category: later)
    items = category.items.order(:id).to_a
    items.first(11).each { |item| find_item(item) }
    emulate_viewport(390, 844)
    visit team_path
    expect(page).to have_css("[data-testid='preview']", count: 11)

    later_items = "#section_#{later.id}_items"
    page.execute_script("scrollTo(0, scrollY + document.querySelector(arguments[0]).getBoundingClientRect().top - 300)", later_items)
    expect(top_of("section")).to be < 0
    before = top_of(later_items)
    wait_for_live_updates

    find_item(items.last)
    expect(page).to have_css("section[data-folded]", text: "All 12 found")
    expect(top_of(later_items)).to be_within(1).of(before)
    expect(section(later)).to have_button(later.items.first.name)
  end
end
