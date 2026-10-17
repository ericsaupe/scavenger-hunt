# frozen_string_literal: true

# Rails lets browsers cache the redirect to a signed service URL for exactly as
# long as that URL stays valid, so a cached redirect reused near the end of the
# window points at a link the service has just rejected and the image breaks.
# Keep the redirect cacheable for a third of the link's life.
module ActiveStorageRedirectCaching
  REDIRECT_CACHE = 5.minutes

  def show
    super
    expires_in REDIRECT_CACHE
  end
end

Rails.application.config.to_prepare do
  ActiveStorage::Representations::RedirectController.prepend(ActiveStorageRedirectCaching)
  ActiveStorage::Blobs::RedirectController.prepend(ActiveStorageRedirectCaching)
end
