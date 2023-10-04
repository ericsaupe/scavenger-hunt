# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  resources :hunts, only: %i[index new create show], param: :code, path: "scavenger_hunts" do
    resources :teams, only: %i[create show]
    resources :items, only: %i[show]
    get :results
    get :print
    get :download_results, on: :member
    post :unlock_results, on: :member
  end

  get :banner, to: "banners#show"

  resources :submissions, only: %i[update]
end
