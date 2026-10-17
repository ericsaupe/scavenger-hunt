# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Single-flight variants" do
  self.use_transactional_tests = false

  let(:blob) { ActiveStorage::Blob.create_and_upload!(io: Rails.root.join("spec/fixtures/poster.jpg").open, filename: "poster.jpg") }

  before { @started_at = Time.current }

  after do
    GoodJob::Job.where(created_at: @started_at..).destroy_all
    variant_records = ActiveStorage::VariantRecord.where(blob_id: blob.id)
    variant_records.find_each { |record| record.image.purge }
    variant_records.delete_all
    blob.purge
  end

  def request_variant(ready)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.cache do
          ready.wait(5)
          ActiveStorage::Blob.find(blob.id).variant(resize_to_limit: [10, 10]).processed.key
        end
      end
    end
  end

  it "resizes a new variant once when several requests ask for it together" do
    transforms = Concurrent::AtomicFixnum.new
    allow_any_instance_of(ActiveStorage::Variation).to receive(:transform).and_wrap_original do |original, *args, &block|
      transforms.increment
      sleep 0.2
      original.call(*args, &block)
    end
    blob
    ready = Concurrent::CyclicBarrier.new(4)

    keys = Array.new(4) { request_variant(ready) }.map(&:value)

    expect(transforms.value).to eq(1)
    expect(keys.uniq.size).to eq(1)
    expect(blob.service.exist?(keys.first)).to be(true)
    expect(ActiveRecord::Base.connection.select_value("SELECT count(*) FROM pg_locks JOIN pg_database ON pg_database.oid = pg_locks.database WHERE locktype = 'advisory' AND datname = current_database()")).to eq(0)
  end
end
