# frozen_string_literal: true

Rails.application.routes.draw do
  root 'home#index'

  resources :hunts, only: %i[index new create show], param: :code, path: 'scavenger_hunts' do
    resources :teams, only: %i[create show]
    resources :items, only: %i[show]
    get :results
    get :print
    post :unlock_results, on: :member
  end

  resources :submissions, only: %i[update]
end
