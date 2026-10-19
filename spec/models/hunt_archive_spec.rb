# frozen_string_literal: true

require "rails_helper"

RSpec.describe Hunt, "photo download" do
  include ActiveSupport::Testing::TimeHelpers

  self.use_transactional_tests = false

  before { @started_at = Time.current }

  let!(:hunt) { create(:hunt) }

  after do
    hunt.submissions.found.each { |submission| submission.photo.purge }
    hunt.reload.archive.purge
    hunt.destroy
    GoodJob::Job.where(created_at: @started_at..).destroy_all
  end

  def count_builds(delay: 0)
    Concurrent::AtomicFixnum.new.tap do |builds|
      allow_any_instance_of(Hunt).to receive(:create_archive_file).and_wrap_original do |original, *args|
        builds.increment
        sleep delay
        original.call(*args)
      end
    end
  end

  def advisory_locks
    ActiveRecord::Base.connection.select_value("SELECT count(*) FROM pg_locks JOIN pg_database ON pg_database.oid = pg_locks.database WHERE locktype = 'advisory' AND datname = current_database()")
  end

  it "builds the download once when several people ask for it together" do
    builds = count_builds(delay: 0.2)
    ready = Concurrent::CyclicBarrier.new(4)

    blobs = Array.new(4) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.cache do
            ready.wait(5)
            Hunt.find(hunt.id).tap(&:refresh_archive).archive.blob_id
          end
        end
      end
    end.map(&:value)

    expect(builds.value).to eq(1)
    expect(blobs.uniq.size).to eq(1)
    expect(advisory_locks).to eq(0)
  end

  it "hands out the last download while someone else is building a fresh one" do
    hunt.refresh_archive
    last = hunt.archive.blob_id
    travel 1.minute
    create(:team, hunt:).submissions.first.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    builds = count_builds
    holder = ActiveRecord::Base.connection_pool.checkout
    key = "hashtextextended(#{holder.quote("hunt_archive:#{hunt.id}")}, 0)"
    holder.select_value("SELECT pg_advisory_lock(#{key})")

    hunt.refresh_archive

    expect(builds.value).to eq(0)
    expect(hunt.archive.blob_id).to eq(last)

    holder.select_value("SELECT pg_advisory_unlock(#{key})")
    hunt.refresh_archive

    expect(builds.value).to eq(1)
    expect(hunt.archive.blob_id).not_to eq(last)
  ensure
    holder&.select_value("SELECT pg_advisory_unlock_all()")
    ActiveRecord::Base.connection_pool.checkin(holder) if holder
  end
end
