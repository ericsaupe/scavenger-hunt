# frozen_string_literal: true

class ItemsController < ApplicationController
  def show
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    @item = @hunt.items.with_photo_submissions.find(params[:id])
    @submissions = @item.submissions.includes(:votes).with_attached_photo.order(:team_id)
    hunt_items = @hunt.items.with_photo_submissions
    @next = hunt_items.where("items.id > ?", @item.id)
      .order("items.id ASC").first || hunt_items.first
    @previous = hunt_items.where("items.id < ?", @item.id)
      .order("items.id DESC").first || hunt_items.last
  end
end
