# frozen_string_literal: true

require "rails_helper"

RSpec.describe PurgeUnattachedBlobsJob do
  def create_blob
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/test.jpg").open,
      filename: "test.jpg"
    )
  end

  it "purges only blobs that have been unattached for more than a day" do
    old_unattached = create_blob
    old_unattached.update_column(:created_at, 2.days.ago)
    fresh_unattached = create_blob
    attached = create(:photo_submission).photo.blob
    attached.update_column(:created_at, 2.days.ago)

    described_class.perform_now

    expect(ActiveStorage::Blob.exists?(old_unattached.id)).to be(false)
    expect(ActiveStorage::Blob.exists?(fresh_unattached.id)).to be(true)
    expect(ActiveStorage::Blob.exists?(attached.id)).to be(true)
  end
end
