# frozen_string_literal: true

class HuntTemplatesController < ApplicationController
  caches_action :show, expires_in: 1.day

  def show
    @template = Templater.find!(params[:slug])
    redirect_to hunt_template_path(@template) if params[:slug] != @template.slug
  end
end
