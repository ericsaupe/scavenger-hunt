# frozen_string_literal: true

class ItemsController < ApplicationController
  def show
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    found_item_ids = @hunt.items.with_photo_submissions.order(:id).ids
    index = found_item_ids.index(params[:id].to_i) or raise ActiveRecord::RecordNotFound
    item_ids = [found_item_ids[index], found_item_ids[index - 1], found_item_ids[(index + 1) % found_item_ids.size]]
    @item, @previous, @next = Item.where(id: item_ids).index_by(&:id).values_at(*item_ids)
    @submissions = @item.submissions.found.includes(:votes, team: :hunt, photo_attachment: :blob).order(:team_id).to_a
  end
end
