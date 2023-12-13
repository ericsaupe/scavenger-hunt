class MessagesController < ApplicationController
  def create
    message = Message.new(message_params)
    hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    message.hunt = hunt
    message.user_id = cookies[:user_id]
    message.save!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("hunt_chat_#{hunt.id}", partial: "messages/message",
          locals: {message:})
      end
      format.js
    end
  end

  private

  def message_params
    params.require(:message).permit(:content, :user_id)
  end
end
