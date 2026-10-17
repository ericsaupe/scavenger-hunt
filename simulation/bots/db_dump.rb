hunt = Hunt.find_by!(code: ENV.fetch("HUNT_CODE"))
puts({
  hunt: hunt.attributes.slice("code", "owner_id", "starts_at", "ends_at", "presentation_slide", "screen_chat", "lead_announced_at", "leading_team_id", "show_announced_at", "password_entered"),
  teams: hunt.teams.map { |t| {id: t.id, name: t.name, score: t.score, total: t.total_score, found: t.submissions.found.count} },
  submissions: hunt.submissions.found.includes(:item, :team, :votes).map { |s| {id: s.id, item: s.item.name, team: s.team.name, video: s.video?, playback: s.playback.attached?, captured_at: s.captured_at, created: s.updated_at, loves: s.votes.count(&:loved?), flags: s.votes.count(&:denied?), denied: s.denied_points?} },
  messages: hunt.messages.order(:id).map { |m| {id: m.id, sender: m.sender_name, team: m.team&.name, organizer: m.organizer?, announcement: m.announcement?, removed: m.removed?, created_at: m.created_at.iso8601(3)} },
  push_subscriptions: hunt.push_subscriptions.map { |p| p.attributes.slice("user_id", "endpoint", "notify_starting_soon", "notify_results", "notify_show", "notify_lead_change", "notify_announcements") },
  jobs: GoodJob::Job.order(:created_at).map { |j| {klass: j.job_class, queue: j.queue_name, scheduled_at: j.scheduled_at&.iso8601(3), performed_at: j.performed_at&.iso8601(3), finished_at: j.finished_at&.iso8601(3), error: j.error} },
  blobs: {total: ActiveStorage::Blob.count, unattached: ActiveStorage::Blob.unattached.count},
  cable_messages: SolidCable::Message.count
}.to_json)
