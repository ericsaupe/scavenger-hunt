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

  describe "joining" do
    it "refreshes the team count in every open party chat" do
      hunt = create(:hunt)
      create(:team, hunt:)
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)

      create(:team, hunt:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to)
        .with(hunt.chat_stream, hash_including(target: hunt.chat_team_count_id, partial: "messages/team_count"))
    end
  end

  describe "avatars" do
    it "gives every team a random sixteen-character seed, so same-named teams in other hunts look different" do
      team = create(:team, name: "Owls")
      twin = create(:team, name: "Owls")

      expect(team.avatar_seed).to match(/\A\h{16}\z/)
      expect(twin.avatar_seed).not_to eq(team.avatar_seed)
      expect(twin.avatar_url).not_to eq(team.avatar_url)
    end

    it "keeps a seed chosen on the form and replaces anything that is not one" do
      hunt = create(:hunt)
      chosen = Team.new_avatar_seed

      expect(hunt.start_a_new_team("Owls", avatar_seed: chosen).avatar_seed).to eq(chosen)
      expect(hunt.start_a_new_team("Crows", avatar_seed: "../not-a-seed").avatar_seed).to match(/\A\h{16}\z/)
      expect(hunt.start_a_new_team("Owls", avatar_seed: Team.new_avatar_seed).avatar_seed).to eq(chosen)
    end

    it "shuffles to a new seed and a new avatar" do
      team = create(:team)
      before = [team.avatar_seed, team.avatar_url]

      team.shuffle_avatar!

      expect(team.reload.avatar_seed).not_to eq(before.first)
      expect(team.avatar_url).not_to eq(before.last)
    end

    it "links to a critter whose fallback carries the team's initial, without exposing the seed" do
      team = create(:team, name: "owls")

      expect(team.avatar_url).to eq("/avatars/team/#{Avatar.digest("team", team.avatar_seed)}.svg?initial=O")
      expect(team.avatar_url).not_to include(team.avatar_seed)
    end
  end

  describe "#score and #total_score" do
    let(:hunt) { create(:hunt) }
    let(:team) { create(:team, hunt:) }

    def find(item, denied: false)
      submission = team.submissions.find_by(item:)
      submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
      submission.update!(denied_points: denied)
    end

    it "adds the category points of found items and leaves out denied ones from the score" do
      hunt.categories.first.update!(points: 3)
      bonus = create(:category, hunt:, points: 10)
      bonus_item = create(:item, category: bonus)
      team.submissions.create!(item: bonus_item)
      first, second, third = hunt.categories.first.items.order(:id).to_a

      find(first)
      find(second, denied: true)
      find(bonus_item)

      expect(team.score).to eq(13)
      expect(team.total_score).to eq(16)
      expect(third).to be_present
    end

    it "is zero before anything is found" do
      expect(team.score).to eq(0)
      expect(team.total_score).to eq(0)
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
