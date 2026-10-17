# frozen_string_literal: true

class ChatNamesController < ApplicationController
  def update
    hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    name = params[:name].to_s.squish.first(Message::MAX_NAME_LENGTH)
    if name.blank?
      return render turbo_stream: turbo_stream.replace(hunt.chat_composer_id, partial: "messages/composer", locals: {hunt:, name: nil, error: "Enter a name so everyone knows who's talking."}), status: :unprocessable_content
    end

    self.chat_name = name
    render turbo_stream: turbo_stream.replace(hunt.chat_composer_id, partial: "messages/composer", locals: {hunt:, name:})
  end
end
