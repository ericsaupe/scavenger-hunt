# frozen_string_literal: true

module RestrictedVideoPreviewInput
  private

  def draw_relevant_frame_from(file, &block)
    draw self.class.ffmpeg_path, *VideoTranscoder::INPUT_OPTIONS, "-i", file.path, *Shellwords.split(ActiveStorage.video_preview_arguments), "-", &block
  end
end

ActiveStorage::Previewer::VideoPreviewer.prepend(RestrictedVideoPreviewInput)
