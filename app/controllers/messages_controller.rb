# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :set_hunt

  def index
    @before = params[:before].presence&.to_i
    @messages = @hunt.recent_messages(before: @before)
    @more = @messages.any? && @hunt.earlier_messages?(@messages.first)
    render layout: false
  end

  def create
    return composer_error("Pick a name before you send a message.") if chat_name.blank?

    message = @hunt.messages.new(
      content: params.require(:message)[:content],
      user_id: cookies[:user_id],
      sender_name: chat_name,
      team: chat_team(@hunt),
      organizer: @hunt.owner?(cookies[:user_id])
    )
    return composer_error(message.errors.full_messages.to_sentence) unless message.valid?
    return composer_error("One message a second, please.", status: :too_many_requests) unless ChatThrottle.allow?(@hunt, cookies[:user_id])

    message.save!
    render turbo_stream: [
      turbo_stream.append(@hunt.chat_list_id, partial: "messages/message", locals: {message:, viewer_id: cookies[:user_id]}),
      turbo_stream.update(@hunt.chat_notice_id, "")
    ]
  end

  def destroy
    return head :forbidden unless @hunt.owner?(cookies[:user_id])

    message = @hunt.messages.find(params[:id])
    message.remove! unless message.removed?
    render turbo_stream: turbo_stream.replace(message, partial: "messages/message", locals: {message:, viewer_id: cookies[:user_id]})
  end

  private

  def set_hunt
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    head :forbidden unless @hunt.chat_available?
  end

  def composer_error(text, status: :unprocessable_content)
    render turbo_stream: turbo_stream.update(@hunt.chat_notice_id, text), status:
  end
end
