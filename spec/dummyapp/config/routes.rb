Dummy::Application.routes.draw do
  root :to => 'home#index'
  resources :users do
    member { post :start_session }
  end

  match '/handle_rails_error' => 'home#handle_rails_error', :via => [:get, :post]
  match '/record_rails_error' => 'home#record_rails_error', :via => [:get, :post]
  match '/cause_exception' => 'home#cause_exception', :via => [:get, :post]
  match '/cause_exception_with_locals' => 'home#cause_exception_with_locals',
        :via => [:get, :post]
  put '/deprecated_report_exception' => 'home#deprecated_report_exception'
  match '/report_exception' => 'home#report_exception',
        :via => [:get, :post, :put]
  get '/current_user' => 'home#current_user'
  post '/file_upload' => 'home#file_upload'

  get '/set_session_data' => 'home#set_session_data'
  get '/use_session_data' => 'home#use_session_data'
  get '/test_rollbar_js' => 'home#test_rollbar_js'
  get '/test_rollbar_js_with_nonce' => 'home#test_rollbar_js_with_nonce'
end
