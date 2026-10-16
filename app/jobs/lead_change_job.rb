# frozen_string_literal: true

class LeadChangeJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(hunt)
    leader, score = hunt.with_lock { reserve_announcement(hunt) }
    return if leader.nil?

    PushNotification.new(hunt, :lead_change,
      title: "#{leader.name} takes the lead",
      body: "#{leader.name} is on top of the #{hunt.name} leaderboard with #{ActionController::Base.helpers.pluralize(score, "point")}.",
      url: hunt_results_path(hunt.code)).deliver
  end

  private

  def reserve_announcement(hunt)
    hunt.update!(lead_recheck_at: nil) if hunt.lead_recheck_at && hunt.lead_recheck_at <= Time.current
    return unless hunt.leaderboard_visible?

    leader, score = hunt.leader
    return if leader.nil? || leader.id == hunt.leading_team_id
    return defer(hunt) if hunt.lead_announced_at && hunt.lead_announced_at > Hunt::LEAD_CHANGE_INTERVAL.ago

    hunt.update!(leading_team_id: leader.id, lead_announced_at: Time.current)
    [leader, score]
  end

  def defer(hunt)
    return if hunt.lead_recheck_at

    recheck_at = hunt.lead_announced_at + Hunt::LEAD_CHANGE_INTERVAL
    hunt.update!(lead_recheck_at: recheck_at)
    self.class.set(wait_until: recheck_at).perform_later(hunt)
    nil
  end
end
