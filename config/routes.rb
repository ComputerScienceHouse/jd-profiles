Profiles::Application.routes.draw do
    root 'users#me'
    match '/search', to: 'users#search', via: 'post'
    match '/groups', to: 'users#list_groups', via: 'get'
    match '/users', to: 'users#list_users', via: 'get'
    match '/years', to: 'users#list_years', via: 'get'
    match '/user/:uid', to: 'users#user', via: 'get', constraints: { :uid => /[\w+\.]+/ } 
    match '/me', to: 'users#me', via: 'get'
    match '/image/:uid', to: 'users#image', via: 'get', constraints: { :uid => /[\w+\.]+/ } 
    match '/autocomplete', to: 'users#autocomplete', via: 'get'
    match '/update', to: 'users#update', via: 'post'
    match '/profiles', to: 'users#user', via: 'get' 
    match '/group/:group', to: 'users#group', via: 'get'
    match '/year/:year', to: 'users#year', via: 'get'
    match '/autocomplete', to: 'users#autocomplete', via: 'get'
    match '/clearcache', to: 'users#clear_cache', via: 'get'
end
