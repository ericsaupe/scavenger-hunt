# frozen_string_literal: true

require "rails_helper"

RSpec.describe Team do
  context "associations" do
    it { is_expected.to belong_to(:hunt).class_name("Hunt") }
    it { is_expected.to have_many(:submissions).class_name("Submission") }
    it { is_expected.to have_many(:items).class_name("Item") }
  end

  context "with unique names" do
    let(:team) { create(:team) }

    it "does not allow duplicate neams within the same hunt" do
      [team.name, team.name.upcase, team.name.downcase].each do |name|
        new_team = build(:team, hunt: team.hunt, name:)
        expect(new_team).not_to be_valid
      end

      different_hunt_team = build(:team, name: team.name)
      expect(different_hunt_team).to be_valid
    end
  end

  context "victory_photo_url" do
    let(:hunt) { team.hunt }
    let(:team) { create(:team) }

    before do
      allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000")
      create_list(:photo_submission, 3, team: team)
    end

    it "returns a random submission image" do
      expect(team.victory_photo_url).to be_present
    end

    it "favors submissions with loved votes" do
      loved_submission = create(:submission, team: team)
      create(:upvote, submission: loved_submission)
      expect(team.victory_photo_url).to eq(loved_submission.large_variant_url)
    end

    it "selects a submission from a category when passed" do
      loved_submission = create(:submission, team: team)
      create(:upvote, submission: loved_submission)
      winning_submission = create(:submission, team: team)
      hunt.update(victory_item_id: winning_submission.item.id)
      expect(team.victory_photo_url(victory_item_id: hunt.victory_item_id)).to eq(winning_submission.large_variant_url)
    end
  end
end
