# frozen_string_literal: true

Rails.application.routes.draw do
  root "hunts#index"

  resources :hunts, only: %i[create show], param: :code, path: 'scavenger_hunts' do
    resources :teams, only: %i[create show]
    resources :items, only: %i[show]
    get :results
  end

  resources :submissions, only: %i[update]
end
