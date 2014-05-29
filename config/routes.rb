Baseball2::Application.routes.draw do

  root 'static_pages#home'

  post '/upload' => 'static_pages#upload'
end
