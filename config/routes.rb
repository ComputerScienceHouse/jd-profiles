Profiles::Application.routes.draw do
    root 'users#me'
    match '/search', to: 'users#search', via: 'post'
    match '/groups', to: 'users#list_groups', via: 'get'
    match '/users', to: 'users#list_users', via: 'get'
    match '/years', to: 'users#list_years', via: 'get'
    match '/user/:uid', to: 'users#user', via: 'get', constraints: { :uid => /[\w+\.]+/ } 
    match '/image/:uid', to: 'users#image', via: 'get', constraints: { :uid => /[\w+\.]+/ } 
    match '/edit', to: 'users#edit', via: 'get'
    match '/update', to: 'users#update', via: 'post'
    match '/profiles', to: 'users#user', via: 'get' 
    match '/group/:group', to: 'users#group', via: 'get'
    match '/year/:year', to: 'users#year', via: 'get'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
