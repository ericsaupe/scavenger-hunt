# frozen_string_literal: true

Rails.application.routes.draw do
  root "hunts#index"

  resources :hunts, only: %i[show]
end
