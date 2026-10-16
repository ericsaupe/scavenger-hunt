# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker
  get "offline", to: "pwa#offline"

  resources :hunts, only: %i[index new create show], param: :code, path: "scavenger_hunts" do
    get :join, on: :collection
    resources :teams, only: %i[create show] do
      post :pending_uploads, on: :member
    end
    resources :items, only: %i[show]
    resources :messages, only: %i[create]
    get :results
    get :presenter
    get "presenter/remote", to: "presentations#remote", as: :presenter_remote
    resource :presentation, only: %i[update] do
      post :claim
      patch :playback
    end
    resource :push_subscription, only: %i[create update destroy]
    get :print
    get :download_results, on: :member
    post :unlock_leaderboard, on: :member
    post :unlock_results, on: :member
  end

  get :banner, to: "banners#show"

  resources :submissions, only: %i[update] do
    resources :votes, only: %i[create]
    get :vote_menu
  end
end
