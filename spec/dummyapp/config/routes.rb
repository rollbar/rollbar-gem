Dummy::Application.routes.draw do
  root :to => "home#index"
  resources :users do
    member { post :start_session }
  end

  get "cause_exception" => "home#cause_exception"
  put "deprecated_report_exception" => "home#deprecated_report_exception"
  match "report_exception" => "home#report_exception", :via => [:get, :post, :put]
  get "current_user" => "home#current_user"
end
