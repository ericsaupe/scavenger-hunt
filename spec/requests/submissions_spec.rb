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

  def direct_uploaded(content_type:, byte_size:, io: Rails.root.join("spec/fixtures/video.mp4").open, checksum: OpenSSL::Digest::MD5.base64digest(io.read))
    io.rewind
    blob = ActiveStorage::Blob.create_before_direct_upload!(filename: "clip", content_type:, byte_size:, checksum:)
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

    it "refuses an SVG and keeps the row rendering" do
      svg = ActiveStorage::Blob.create_and_upload!(io: Rails.root.join("spec/fixtures/avatar.svg").open, filename: "avatar.svg", content_type: "image/svg+xml").signed_id
      send_photo(svg)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That image type can&#39;t be used. Take a photo instead")
      expect(submission.reload.photo).not_to be_attached
    end

    it "renders a checklist whose photo cannot be transformed" do
      submission.photo.attach(io: Rails.root.join("spec/fixtures/avatar.svg").open, filename: "avatar.svg", content_type: "image/svg+xml")
      submission.save!(validate: false)

      get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/rails/active_storage/blobs/redirect/")
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

  describe "a photo queued while offline" do
    it "keeps a teammate's photo that arrived first and drops the queued one" do
      existing = ActiveStorage::Blob.create_and_upload!(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "teammate.jpg")
      submission.photo.attach(existing)
      queued = uploaded_photo

      patch "/submissions/#{submission.id}", params: {submission: {photo: queued, captured_at: Time.current.iso8601, keep_existing: "1"}}, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ERB::Util.html_escape("A teammate already found #{submission.item.name}"))
      expect(submission.reload.photo.blob).to eq(existing)
      expect(ActiveStorage::Blob.find_signed(queued)).to be_nil
    end

    it "lands normally when nobody found the item in the meantime" do
      send_photo(uploaded_photo)
      patch "/submissions/#{submission.id}", params: {submission: {photo: uploaded_photo, captured_at: Time.current.iso8601, keep_existing: "1"}}, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "replaces the team's own photo when the queued one was a retake" do
      send_photo(uploaded_photo)
      first_blob = submission.photo.blob

      send_photo(uploaded_photo)

      expect(response).to have_http_status(:ok)
      expect(submission.reload.photo.blob).not_to eq(first_blob)
    end
  end

  describe "media limits" do
    it "accepts a video of 150 megabytes" do
      send_photo(direct_uploaded(content_type: "video/mp4", byte_size: 150.megabytes))

      expect(response).to have_http_status(:ok)
      expect(submission.photo).to be_attached
    end

    it "refuses a video over 150 megabytes" do
      send_photo(direct_uploaded(content_type: "video/mp4", byte_size: 150.megabytes + 1))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Videos must be 150 MB or smaller")
      expect(submission.photo).not_to be_attached
    end

    it "discards the uploaded file when refusing it" do
      signed_id = direct_uploaded(content_type: "video/mp4", byte_size: 150.megabytes + 1)
      send_photo(signed_id)

      expect(ActiveStorage::Blob.find_signed(signed_id)).to be_nil
    end

    it "accepts a video longer than sixty seconds and lets the worker take it back", ffprobe_duration: 61 do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
      signed_id = direct_uploaded(content_type: "video/mp4", byte_size: 1.megabyte)
      send_photo(signed_id)

      expect(response).to have_http_status(:ok)
      expect(submission.photo).not_to be_attached
      expect(ActiveStorage::Blob.find_signed(signed_id)).to be_nil
      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with("submissions_#{team.id}",
        hash_including(target: "flash", locals: {message: "Videos must be 60 seconds or shorter. Try a shorter clip."}))
    end

    it "takes back a video whose upload did not match its checksum" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
      signed_id = direct_uploaded(content_type: "video/mp4", byte_size: 1.megabyte, checksum: "abc")
      send_photo(signed_id)

      expect(response).to have_http_status(:ok)
      expect(submission.photo).not_to be_attached
      expect(ActiveStorage::Blob.find_signed(signed_id)).to be_nil
      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with("submissions_#{team.id}",
        hash_including(target: "flash", locals: {message: "The video didn't upload completely. Please try again."}))
    end

    it "queues the playable version of an accepted video", :test_queue_adapter do
      expect { send_photo(direct_uploaded(content_type: "video/mp4", byte_size: 1.megabyte)) }
        .to have_enqueued_job(TranscodeVideoJob).with(submission)
      expect(response.body).to include("Processing video")
    end

    it "refuses a file that is neither a photo nor a video" do
      send_photo(direct_uploaded(content_type: "application/pdf", byte_size: 1.kilobyte, io: StringIO.new("%PDF-1.4 not a video")))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Only photos and videos can be uploaded")
      expect(submission.photo).not_to be_attached
    end
  end
end
