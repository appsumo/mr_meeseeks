$LOAD_PATH << File.dirname(__FILE__)
require 'sinatra/base'
require 'dotenv/load'
require 'slack-ruby-client'
require 'json'
require 'uri'
require 'net/http'
require 'rest-client'
require 'Mr_Meeseeks'

class API < Sinatra::Base
  @@pending_requests={}
  set :logging, true

  def confirm_sns(payload)
    logger.info "Mr. Meeseeks: Trying to Confirm Subscription: #{payload["TopicArn"]}"
    response = RestClient.get(payload["SubscribeURL"])
    if response.code == 200
      logger.info "Mr. Meeseeks: Subscription Success: #{payload["TopicArn"]}"
    else
      logger.error "#{response.body}"
    end
  end

  def process_message(message)
    id=message["MessageId"]
    new_message=Bot.new(id,message["Subject"],message["Message"])
    @@pending_requests[id]=new_message
  end

  # Stupid health check endpoint
  get '/health' do
    'ok'
  end

  post '/slack' do
    response=JSON.parse(params[:payload])
    action= response["actions"][0]["value"].split(":")[0]
    act_on_id= response["actions"][0]["value"].split(":")[1]
    @@pending_requests[act_on_id].decide(action,response["user"]["name"])
    @@pending_requests.delete(act_on_id)
  end

  post '/sns' do
    payload = JSON.parse(request.body.read)
    case payload["Type"]
      when "SubscriptionConfirmation"
        confirm_sns(payload)
      when "Notification"
        process_message(payload)
      else
        logger.info payload
      end
    halt 200
  end

end
