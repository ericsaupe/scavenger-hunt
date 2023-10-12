# frozen_string_literal: true

FactoryBot.define do
  factory :submission do
    item
    team

    factory :photo_submission do
      after :create do |submission|
        submission.photo.attach(
          io: Rails.root.join("spec/fixtures/test.jpg").open,
          filename: "test.jpg"
        )
      end
    end

    factory :video_submission do
      after :create do |submission|
        submission.photo.attach(
          io: Rails.root.join("spec/fixtures/video.mp4").open,
          filename: "video.mp4"
        )
      end
    end
  end
end
