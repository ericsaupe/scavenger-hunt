# frozen_string_literal: true

class Message < ApplicationRecord
  MAX_CONTENT_LENGTH = 280
  MAX_NAME_LENGTH = 40
  PAGE_SIZE = 50

  belongs_to :hunt
  belongs_to :team, optional: true

  validates :content, presence: true, length: {maximum: MAX_CONTENT_LENGTH}
  validates :sender_name, presence: true, length: {maximum: MAX_NAME_LENGTH}
  validates :user_id, presence: true

  scope :visible, -> { where(deleted_at: nil) }
  scope :from_organizer, -> { where(organizer: true) }

  after_create_commit :broadcast_message
  after_update_commit :broadcast_removal, if: :saved_change_to_deleted_at?

  def remove!
    update!(deleted_at: Time.current)
  end

  def removed?
    deleted_at.present?
  end

  def own?(viewer_id)
    viewer_id.present? && user_id == viewer_id
  end

  def initial
    (team&.name.presence || sender_name).to_s.first.upcase
  end

  private

  def broadcast_message
    broadcast_append_to(hunt.chat_stream, target: hunt.chat_list_id, partial: "messages/message", locals: {message: self})
    return unless organizer?

    broadcast_organizer_update
    AnnouncementJob.perform_later(self)
  end

  def broadcast_removal
    broadcast_replace_to(hunt.chat_stream, partial: "messages/message", locals: {message: self})
    broadcast_organizer_update if organizer?
  end

  def broadcast_organizer_update
    latest = hunt.latest_organizer_message
    broadcast_replace_to(hunt.chat_stream, target: "chat_pinned_#{hunt_id}", partial: "messages/pinned", locals: {hunt:, message: latest})
    broadcast_replace_to(hunt.chat_stream, target: "organizer_card_#{hunt_id}", partial: "messages/organizer_card", locals: {hunt:, message: latest})
  end
end
