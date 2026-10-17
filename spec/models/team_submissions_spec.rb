# frozen_string_literal: true

require "rails_helper"

RSpec.describe Team, "#ensure_submissions!" do
  self.use_transactional_tests = false

  let!(:hunt) { create(:hunt) }
  let!(:team) { create(:team, hunt:) }

  after { hunt.destroy }

  it "adds exactly one row per missing item even when two requests repair the team at once" do
    item = hunt.items.last
    team.submissions.find_by(item:).destroy!
    ready = Concurrent::CyclicBarrier.new(2)

    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready.wait(5)
          Team.find(team.id).ensure_submissions!
        end
      end
    end
    threads.each(&:join)

    expect(team.submissions.where(item:).count).to eq(1)
    expect(team.submissions.count).to eq(hunt.items.count)
  end

  it "makes no writes for a team that already has every row" do
    expect { team.ensure_submissions! }.not_to change { team.submissions.maximum(:updated_at) }
  end
end
