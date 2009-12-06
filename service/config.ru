require 'sinatra'
 
set :run, false
set :environment, :production
 
require 'app'

run Sinatra::Application


