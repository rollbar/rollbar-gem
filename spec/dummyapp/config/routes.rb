Dummy::Application.routes.draw do
  authenticated :user do
    root :to => 'home#index'
  end
  root :to => "home#index"
  devise_for :users
  resources :users do
    member { post :start_session }
  end

  match "/cause_exception" => "home#cause_exception"
  match "/report_exception" => "home#report_exception"
  match "/current_user" => "home#current_user", as: 'current_user'
end
