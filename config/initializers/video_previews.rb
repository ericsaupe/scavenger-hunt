# frozen_string_literal: true

module RestrictedVideoPreview
  private

  def draw_relevant_frame_from(file)
    open_tempfile do |frame|
      frame.binmode
      VideoTranscoder.run([self.class.ffmpeg_path, *VideoTranscoder::INPUT_OPTIONS, "-i", file.path,
        *Shellwords.split(ActiveStorage.video_preview_arguments), "-"], into: frame)
      frame.rewind
      yield frame
    end
  rescue VideoTranscoder::Error => error
    raise ActiveStorage::PreviewError, error.message
  end
end

module RestrictedVideoProbe
  private

  def probe_from(file)
    VideoTranscoder.probe(file.path)
  end
end

ActiveStorage::Previewer::VideoPreviewer.prepend(RestrictedVideoPreview)
ActiveStorage::Analyzer::VideoAnalyzer.prepend(RestrictedVideoProbe)
