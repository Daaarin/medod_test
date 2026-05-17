Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#create"
      get "auth/me", to: "auth#show"
      resources :users, only: %i[index]
      resources :tasks, only: %i[index show create update destroy]
      resources :tags, only: %i[index create update destroy]
      post "tasks/:task_id/tags/:tag_id", to: "task_tags#create"
      delete "tasks/:task_id/tags/:tag_id", to: "task_tags#destroy"
      post "tasks/:task_id/accept", to: "task_acceptances#accept"
      post "tasks/:task_id/decline", to: "task_acceptances#decline"
      resources :task_occurrences, only: [] do
        post :postpone, on: :member
        post :execute, on: :member
        post :skip, on: :member
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development? || Rails.env.test?
    mount Rswag::Api::Engine => "/api-docs"
    mount Rswag::Ui::Engine => "/api-docs"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
