Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # The plan this account is on, and the one page that changes it. Singular
  # because a user has exactly one: `show` lists the tiers and says which one
  # is live, `create` starts the checkout for a named plan, and everything
  # after that — switching, cancelling, a card that expired — happens in
  # Stripe's own portal rather than in three controllers of ours.
  resource :subscription, only: %i[ show create ] do
    post :portal
    get :success
  end

  # Stripe posts here from its own servers. No session, no CSRF token, no
  # locale — the signature is the authentication.
  post "webhooks/stripe" => "payments/stripe_webhooks#create", as: :stripe_webhook

  # Feature flags, behind HTTP basic auth: this can switch parts of the product
  # off for every visitor. The auth lives inside the mounted app rather than in
  # a routing constraint so an unauthorised request gets a 401 challenge — a
  # constraint answers 404, which never prompts a browser and loses the header
  # on Flipper's own internal redirects.
  mount FlipperGate.app => "/flipper"

  # The whole of the account surface: show the form, start a session, end it.
  # No reset and no confirmation — add them when the product needs them rather
  # than carrying dead routes from the first commit.
  get "sign_up" => "registrations#new", as: :sign_up
  post "sign_up" => "registrations#create"
  get "sign_in" => "sessions#new", as: :sign_in
  post "sign_in" => "sessions#create"
  delete "sign_out" => "sessions#destroy", as: :sign_out

  root "home#show"
end
