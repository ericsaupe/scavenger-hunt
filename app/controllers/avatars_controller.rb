# frozen_string_literal: true

class AvatarsController < ApplicationController
  skip_before_action :set_user_id

  def show
    return head :not_found unless Avatar.valid_digest?(params[:kind], params[:digest])

    avatar = Avatar.lookup(params[:kind], params[:digest])
    response.headers["Content-Security-Policy"] = "script-src 'none'"

    if avatar
      expires_in 365.days, public: true, immutable: true
      render body: avatar.svg, content_type: "image/svg+xml"
    else
      expires_in Avatar::FAILURE_TTL, public: true
      @initial = params[:initial].to_s.first.to_s.upcase
      render params[:kind], formats: :svg, content_type: "image/svg+xml"
    end
  end
end
