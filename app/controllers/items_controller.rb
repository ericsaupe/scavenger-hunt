# frozen_string_literal: true

class ItemsController < ApplicationController
  def show
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    @item = @hunt.items.includes(submissions: :photo_attachment).find(params[:id])
    @submissions = @item.submissions.with_attached_photo
    hunt_items = @hunt.items
    @next = hunt_items.where("items.id > ?", @item.id).order("items.id ASC").first || hunt_items.first
    @previous = hunt_items.where("items.id < ?", @item.id).order("items.id DESC").first || hunt_items.last
  end
end
