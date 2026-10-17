# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261017140000_detach_untransformable_submission_photos")

RSpec.describe DetachUntransformableSubmissionPhotos, :test_queue_adapter do
  it "detaches photos Active Storage cannot transform and leaves the rest alone" do
    svg = create(:submission)
    svg.photo.attach(io: Rails.root.join("spec/fixtures/avatar.svg").open, filename: "avatar.svg", content_type: "image/svg+xml")
    svg.save!(validate: false)
    photo = create(:photo_submission)
    video = create(:video_submission)

    ActiveRecord::Migration.suppress_messages { described_class.new.up }

    expect(svg.reload.photo).not_to be_attached
    expect(photo.reload.photo).to be_attached
    expect(video.reload.photo).to be_attached
    expect(ActiveStorage::PurgeJob).to have_been_enqueued.once
  end
end
