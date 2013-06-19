Dummy::Application.routes.draw do
  root :to => "home#index"
  resources :users do
    member { post :start_session }
  end

  match "/cause_exception" => "home#cause_exception"
  match "/report_exception" => "home#report_exception"
  match "/current_user" => "home#current_user"
end
