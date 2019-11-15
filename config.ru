require './server'
run Rack::Cascade.new [API]
