# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Hunt templates" do
  it "shows every group and item on a list without creating a hunt" do
    template = Templater.find!("christmas-light-spectacle")

    expect { get "/scavenger_hunts/lists/christmas-light-spectacle" }.not_to change(Hunt, :count)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Christmas Light Spectacle")
    template.categories.each do |category|
      expect(response.body).to include(ERB::Util.html_escape(category.name))
      category.items.each { |item| expect(response.body).to include(ERB::Util.html_escape(item)) }
    end
    expect(response.body).to include(new_hunt_path(template: "Christmas Light Spectacle"))
    expect(response.body).not_to match(/victory/i)
  end

  it "sends other spellings of a slug to the one address it caches under" do
    get "/scavenger_hunts/lists/Christmas-Light-SPECTACLE"

    expect(response).to redirect_to("/scavenger_hunts/lists/christmas-light-spectacle")
  end

  it "404s for a list that does not exist" do
    get "/scavenger_hunts/lists/not-a-list"

    expect(response).to have_http_status(:not_found)
  end
end
