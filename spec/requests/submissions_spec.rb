# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Submissions" do
  let(:hunt) { create(:hunt) }
  let(:team) { create(:team, hunt:) }
  let(:submission) { team.submissions.first }
  let(:headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

  def uploaded_photo
    ActiveStorage::Blob.create_and_upload!(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg").signed_id
  end

  def direct_uploaded(content_type:, byte_size:, io: Rails.root.join("spec/fixtures/video.mp4").open)
    blob = ActiveStorage::Blob.create_before_direct_upload!(filename: "clip", content_type:, byte_size:, checksum: "abc")
    blob.service.upload(blob.key, io)
    blob.signed_id
  end

  def send_photo(photo, captured_at: Time.current)
    patch "/submissions/#{submission.id}", params: {submission: {photo:, captured_at: captured_at.iso8601}}, headers: headers
    submission.reload
  end

  describe "the grace window after the hunt ends" do
    it "stores when the photo was captured" do
      captured_at = 2.minutes.ago.change(usec: 0)
      send_photo(uploaded_photo, captured_at:)

      expect(submission.photo).to be_attached
      expect(submission.captured_at).to eq(captured_at)
    end

    it "accepts a photo captured before the end that arrives within fifteen minutes" do
      hunt.update!(ends_at: 5.minutes.ago)
      send_photo(uploaded_photo, captured_at: 10.minutes.ago)

      expect(response).to have_http_status(:ok)
      expect(submission.photo).to be_attached
    end

    it "refuses a photo captured before the end once the grace window has passed" do
      hunt.update!(ends_at: 20.minutes.ago)
      send_photo(uploaded_photo, captured_at: 25.minutes.ago)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("The hunt ended before this photo was sent")
      expect(submission.photo).not_to be_attached
    end

    it "refuses a photo captured after the end" do
      hunt.update!(ends_at: 5.minutes.ago)
      send_photo(uploaded_photo, captured_at: 1.minute.ago)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("The hunt ended before this photo was sent")
      expect(submission.photo).not_to be_attached
    end

    it "refuses a photo sent after the end without a capture time" do
      hunt.update!(ends_at: 5.minutes.ago)
      patch "/submissions/#{submission.id}", params: {submission: {photo: uploaded_photo}}, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(submission.reload.photo).not_to be_attached
    end

    it "refuses a photo posted directly as a file after the end" do
      hunt.update!(ends_at: 5.minutes.ago)
      patch "/submissions/#{submission.id}", params: {submission: {photo: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/test.jpg"), "image/jpeg"), captured_at: 1.minute.ago.iso8601}}, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(submission.reload.photo).not_to be_attached
    end

    it "judges the grace window by the submission's own hunt, not a team sent by the client" do
      hunt.update!(ends_at: 5.minutes.ago)
      other_team = create(:team)
      patch "/submissions/#{submission.id}", params: {submission: {photo: uploaded_photo, captured_at: 1.minute.ago.iso8601, team_id: other_team.id, item_id: other_team.submissions.first.item_id}}, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(submission.reload.team).to eq(team)
      expect(submission.photo).not_to be_attached
    end

    it "redirects with the error for a plain form post" do
      hunt.update!(ends_at: 5.minutes.ago)
      patch "/submissions/#{submission.id}", params: {submission: {photo: uploaded_photo, captured_at: 1.minute.ago.iso8601}}

      expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/teams/#{team.id}")
      expect(flash[:error]).to eq("The hunt ended before this photo was sent")
    end
  end

  describe "media limits" do
    it "accepts a video of fifty megabytes" do
      send_photo(direct_uploaded(content_type: "video/mp4", byte_size: 50.megabytes))

      expect(response).to have_http_status(:ok)
      expect(submission.photo).to be_attached
    end

    it "refuses a video over fifty megabytes" do
      send_photo(direct_uploaded(content_type: "video/mp4", byte_size: 50.megabytes + 1))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Videos must be 50 MB or smaller")
      expect(submission.photo).not_to be_attached
    end

    it "discards the uploaded file when refusing it" do
      signed_id = direct_uploaded(content_type: "video/mp4", byte_size: 50.megabytes + 1)
      send_photo(signed_id)

      expect(ActiveStorage::Blob.find_signed(signed_id)).to be_nil
    end

    it "refuses a file that is neither a photo nor a video" do
      send_photo(direct_uploaded(content_type: "application/pdf", byte_size: 1.kilobyte, io: StringIO.new("%PDF-1.4 not a video")))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Only photos and videos can be uploaded")
      expect(submission.photo).not_to be_attached
    end
  end
end
