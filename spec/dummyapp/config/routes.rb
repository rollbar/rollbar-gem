Dummy::Application.routes.draw do
  authenticated :user do
    root :to => 'home#index'
  end
  root :to => "home#index"
  devise_for :users
  resources :users

  match "/cause_exception" => "home#cause_exception"
  match "/report_exception" => "home#report_exception"
end
