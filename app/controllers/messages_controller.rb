class MessagesController < ApplicationController
  def create
    message = Message.new(message_params)
    hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    message.hunt = hunt
    message.user_id = cookies[:user_id]
    message.save!

    render json: {message: message}
  end

  private

  def message_params
    params.require(:message).permit(:content, :user_id)
  end
end
