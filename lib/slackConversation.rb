$LOAD_PATH << './lib'

require 'dotenv/load'
require 'rest-client'
require 'MySettings'
require 'aws-sdk'



# "{\"region\":\"us-west-2\",
# \"consoleLink\":\"https://console.aws.amazon.com/codesuite/codepipeline/pipelines/litmus/view?region=us-west-2\",
# \"approval\":{
#     \"pipelineName\":\"litmus\",
#     \"stageName\":\"Build\",
#     \"actionName\":\"approve-build\",
#     \"token\":\"af4e33bd-9be4-454c-b237-0cd7d5a7acd8\",
#     \"expires\":\"2020-07-22T17:09Z\",
#     \"externalEntityLink\":null,
#     \"approvalReviewLink\":\"https://console.aws.amazon.com/codesuite/codepipeline/pipelines/litmus/view?region=us-west-2#/Build/approve-build/approve/af4e33bd-9be4-454c-b237-0cd7d5a7acd8\",
#     \"customData\":null}
#     }"

class SlackConversation

    def initialize(payload)
        @logger = Logger.new(STDOUT)
        mySettings=MySettings.new
        @slacktoken = mySettings.get('slack')['access_token']
        @slackTs = nil
        @channel = ENV['SLACK_CHANEL']
        @payload = payload
        @message = JSON.parse(payload['Message'])

        aws_client = Aws::CodePipeline::Client.new(:region => @message['region'])
        pipeline_state = aws_client.get_pipeline_state(:name => @message["approval"]['pipelineName'])
        @summary = pipeline_state.stage_states[0].action_states[0].latest_execution.summary
        @git = pipeline_state.stage_states[0].action_states[0].revision_url 
        self.generateDialog
    end

    def executePipelineDecision
        aws_client = Aws::CodePipeline::Client.new(:region => @message['region'])
        resp = aws_client.put_approval_result({
            pipeline_name: @message["approval"]['pipelineName'],
            stage_name: @message["approval"]["stageName"],
            action_name: @message["approval"]["actionName"],
            result: {
                summary: "Mr. Meeseeks: #{@who} made me do this!",
                status: @action, # required, accepts Approved, Rejected
            },
            token: @message["approval"]['token']
        })
    end

    def processUpdate(awsMessage)      
        @action = awsMessage["actions"][0]["value"].split(":")[0]
        @who = awsMessage["user"]["name"]
        self.executePipelineDecision
        self.generateDialog
    end


    # blocks:[
    #     { type: "section", text: { type: "mrkdwn", text: "I’m Mr. Meeseeks, look at me!" } },
    #     { type: "section", text: { type: "mrkdwn", text: "#{@payload['subject']}\n*<#{@message["approval"]['approvalReviewLink']}|AWS CodePipeline>*" } },
    #     { type: "section", text: { type: "mrkdwn", text: "*Summary*\n#{@summary} *<#{@git}|Git>*" } },
    #     { type: "section",
    #         fields: [
    #             { type: "mrkdwn", text: "*Pipeline:*\n#{@message["approval"]['pipelineName']}" },
    #             { type: "mrkdwn", text: "*Stage:*\n#{@message["approval"]["stageName"]}" }
    #         ]
    #     },
    #     { type: "section", text: { type: "mrkdwn", text: "*Action:* #{@message["approval"]["actionName"]}" } }
    # ]

    def generateDialog()
        message = {
            type: "interactive_message",
            channel: @channel,
            blocks:[
                {
                    type: "section",
                    fields: [
                        {
                            type: "mrkdwn",
                            text: "*Pipeline:*\n#{@message["approval"]['pipelineName']}"
                        },
                        {
                            type: "mrkdwn",
                            text: "*Stage*\n#{@message["approval"]["stageName"]}"
                        }
                    ]
                },
                {
                    type: "section",
                    text: {
                        type: "mrkdwn",
                        text: "*Action*: #{@message["approval"]["actionName"]}"
                    },
                    accessory: {
                        type: "button",
                        text: {
                            type: "plain_text",
                            text: "AWS CodePipeline",
                            emoji: true
                        },
                        url: @message["approval"]['approvalReviewLink'],
                        value: "ignore1"
                    }
                },
                {
                    type: "section",
                    text: {
                        type: "mrkdwn",
                        text: "*Summary:* #{@summary}"
                    },
                    accessory: {
                        type: "button",
                        text: {
                            type: "plain_text",
                            text: "Github"
                        },
                        url: @git,
                        value: "ignore2"
                    }
                }
            ]
        }

        if @slackTs == nil
            # We are asking the question
            url = "https://slack.com/api/chat.postMessage"
            message[:blocks] << { type: "section", text: { type: "mrkdwn", text: "*Expires:* #{Date.parse(@message["approval"]["expires"]).rfc2822}" } }
            message[:blocks] << { type: "actions", elements: [
                        { type: "button", text: { type: "plain_text", emoji: true, text: "Approve" }, style: "primary", value: "Approved:#{@payload["MessageId"]}" },
                        { type: "button", text: { type: "plain_text", emoji: true, text: "Reject" }, style: "danger",  value: "Rejected:#{@payload["MessageId"]}" }
                    ]
                }
            message[:blocks] << { "type": "divider" }
        else
            # We are updating the conversation of what happened.
            url = "https://slack.com/api/chat.update"
            message["replace_original"] = true 
            message["ts"] = @slackTs
            message[:blocks] <<  { type: "context", elements: [	{ type: "mrkdwn", text: "*#{@who}* has #{@action} this request." } ] }
            message[:blocks] << { "type": "divider" }
        end

        sendMessage(url,message)
    end

    def sendMessage(url,message)
        begin
            raw_result = RestClient.post(url, message.to_json, headers = { content_type: :json, Authorization: "Bearer #{@slacktoken}"})
            result = JSON.parse(raw_result.body)
            if result["ok"] == true 
                @slackTs = result["ts"]
            else
                @logger.error "Error starting slack conversation:"
                @logger.error result
            end
        rescue RestClient::ExceptionWithResponse => e
            @logger.error("having troupble talking to: #{url}")
            @logger.error("Unable to send message: #{message}")
            @logger.error(e.response)
        end
    end

end 
