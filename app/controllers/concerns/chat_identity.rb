# frozen_string_literal: true

module ChatIdentity
  extend ActiveSupport::Concern

  included do
    helper_method :chat_name, :chat_team
  end

  def chat_name
    cookies.signed[:chat_name].presence
  end

  def chat_name=(name)
    cookies.permanent.signed[:chat_name] = name
  end

  def chat_team(hunt)
    return @chat_team if defined?(@chat_team)

    @chat_team = hunt.teams.find_by(id: cookies.signed[:last_team_id])
  end
end
