$LOAD_PATH << './lib'
require 'rest-client'
require 'slackConversation'
require 'MySettings'
require 'dotenv/load'
require 'sinatra'

class App < Sinatra::Base
    enable :sessions

    def initialize
        super()
        @logger = Logger.new(STDOUT)
        @mySettings=MySettings.new
        @@jobs={}
        @logger.info("Endpoint: #{ENV["BOT_ENDPOINT"]}")
        @logger.info("Slack Bot Interaction Endpoint: #{ENV["BOT_ENDPOINT"]}/slack")
        @logger.info("Redirect Endpoint: #{ENV["BOT_ENDPOINT"]}/oauth2/redirect")
        @logger.info("Slack Authorization Endpoint: #{ENV["SLACK_AUTHORIZATION_ENDPOINT"]}")
        @logger.info("Slack Token Endpoint: #{ENV["SLACK_TOKEN_ENDPOINT"]}")
        @logger.info("SNS Endpoint:  #{ENV["BOT_ENDPOINT"]}/sns")
    end

    get '/health' do
        'ok'
    end

    get '/' do
        if @mySettings.get('slack') == nil
            add_to_slack_button = %(
                <a href=\"/oauth2/login\">
                    <img alt=\"Add to Slack\" height=\"40\" width=\"139\" src=\"https://platform.slack-edge.com/img/add_to_slack.png\"/>
                </a>
            )
            status 200
            body add_to_slack_button
        else  
            status 200
            body "Yup, we have a slack token already"
        end
    end

    get '/oauth2/login' do
        if @mySettings.get('slack') == nil
            encoded_scope=URI.escape(["channels:read","groups:read","mpim:read","im:read","chat:write","channels:join","chat:write.public","chat:write.customize","users.profile:read"].join(' '))
            authorization_uri = "#{ENV['SLACK_AUTHORIZATION_ENDPOINT']}?scope=#{encoded_scope}&client_id=#{ENV['SLACK_CLIENT_ID']}"
            redirect authorization_uri
        end
    end

    get '/oauth2/redirect' do
        if @mySettings.get('slack') == nil
            @logger.info("recived oauth2-redirect: #{params}")
            query = {
                client_id: ENV['SLACK_CLIENT_ID'], 
                code: params['code'], 
                client_secret: ENV['SLACK_API_SECRET']
            }
            begin
                response = RestClient.post(ENV['SLACK_TOKEN_ENDPOINT'], query)
            rescue RestClient::ExceptionWithResponse => e
                @logger.error(e.response)
                status 500
            end
            response_obj = JSON.parse(response.body)
            if response_obj["ok"] == true
                body "Awesome, I got a token!"
                @logger.info("got new token: #{response_obj['access_token']}")
                @mySettings.store('slack',response_obj)
                status 200
            else 
                body response.body
                status 500
            end
        end
    end

    def confirm_sns(payload)
        @logger.info "Mr. Meeseeks: Trying to Confirm Subscription: #{payload["TopicArn"]}"
        response = RestClient.get(payload["SubscribeURL"])
        if response.code == 200
          @logger.info "Mr. Meeseeks: Subscription Success: #{payload["TopicArn"]}"
        else
          @logger.error "#{response.body}"
        end
    end

    post '/sns' do
        payload = JSON.parse(request.body.read)
        case payload["Type"]
            when "SubscriptionConfirmation"
                @logger.info "Mr. Meeseeks: Trying to Confirm Subscription: #{payload["TopicArn"]}"
                begin
                    response = RestClient.get(payload["SubscribeURL"])
                rescue RestClient::ExceptionWithResponse => e
                    @logger.error("Unable to confirm SNS Subscription")
                    @logger.error(e.response)
                end
            when "Notification"
                if payload["Subject"].start_with? "APPROVAL NEEDED:"
                    approval_request = SlackConversation.new(payload)
                    @@jobs[payload['MessageId']] = approval_request
                end
        end
        #pp payload
        status 200
    end

    post '/slack' do
        response=JSON.parse(params[:payload])
        if !response["actions"][0]["value"].start_with? "ignore"
            id = response["actions"][0]["value"].split(":")[1]
            @@jobs[id].processUpdate(response)
            @@jobs.delete(id)
        end
    end
end

