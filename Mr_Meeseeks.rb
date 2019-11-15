require 'json'
require 'rest-client'
require 'date'
require 'aws-sdk-codepipeline'
require 'dotenv/load'

class Mr_Meeseeks
  def initialize(id,subject,message)
    data = JSON.parse(message)
    @aws_region         = data["region"]
    @id                 = id
    @subject            = subject
    @pipelineName       = data["approval"]["pipelineName"]
    @stageName          = data["approval"]["stageName"]
    @actionName         = data["approval"]["actionName"]
    @expires            = data["approval"]["expires"]
    @consoleLink        = data["consoleLink"]
    @approvalReviewLink = data["approval"]["approvalReviewLink"]
    @token              = data["approval"]["token"]
    @slack_token        = ENV['SLACK_TOKEN']
    @slack_channel      = ENV['SLACK_CHANEL']
    @message_ts         = ""
    @slack_encoded_channel = ""

    self.ask_for_approval
   end

   def ask_for_approval
         message = {
           type: "interactive_message",
           channel: @slack_channel,
           blocks:[
             { type: "section", text: { type: "mrkdwn", text: "I’m Mr. Meeseeks, look at me!" } },
             { type: "section", text: { type: "mrkdwn", text: "#{@subject}\n*<#{@approvalReviewLink}|AWS CodePipeline Dashboard>*" } },
             { type: "section",
                 fields: [
                     { type: "mrkdwn", text: "*Pipeline:*\n#{@pipelineName}" },
                     { type: "mrkdwn", text: "*Stage:*\n#{@stageName}" }
                 ]
             },
             { type: "section", text: { type: "mrkdwn", text: "*Action:* #{@actionName}" } },
             { type: "section", text: { type: "mrkdwn", text: "*Expires:* #{Date.parse(@expires).rfc2822}" } },
             { type: "actions",
                 elements: [
                     { type: "button", text: { type: "plain_text", emoji: true, text: "Approve" }, style: "primary", value: "Approved:#{@id}" },
                     { type: "button", text: { type: "plain_text", emoji: true, text: "Reject" }, style: "danger",  value: "Rejected:#{@id}" }
                   ]
             },
             { "type": "divider" }
           ]
         }
         result = RestClient.post("https://slack.com/api/chat.postMessage", message.to_json, headers = { content_type: :json, Authorization: "Bearer #{@slack_token}"})
         json_data = JSON.parse(result.body)
         @message_ts = json_data["ts"]
         @slack_encoded_channel = json_data["channel"]
   end


   def decide(action,who)
     aws_client = Aws::CodePipeline::Client.new(:region => @aws_region)
     resp = aws_client.put_approval_result({
       pipeline_name: @pipelineName,
       stage_name: @stageName,
       action_name: @actionName,
       result: {
         summary: "Mr. Meeseeks: #{who} made me do this!",
         status: action, # required, accepts Approved, Rejected
       },
       token: @token
     })

     message = {
       replace_original: true,
       ts: @message_ts,
       channel: @slack_encoded_channel,
       type: "interactive_message",
       blocks:[
         { type: "section", text: { type: "mrkdwn", text: "I’m Mr. Meeseeks, look at me!" } },
         { type: "section", text: { type: "mrkdwn", text: "#{@subject}\n*<#{@approvalReviewLink}|AWS CodePipeline Dashboard>*" } },
         { type: "section",
             fields: [
                 { type: "mrkdwn", text: "*Pipeline:*\n#{@pipelineName}" },
                 { type: "mrkdwn", text: "*Stage:*\n#{@stageName}" }
             ]
         },
         { type: "section", text: { type: "mrkdwn", text: "*Action:* #{@actionName}" } },
         { type: "section", text: { type: "mrkdwn", text: "#{who} has #{action} this request." } },
         { "type": "divider" }
       ]
     }
     result = RestClient.post("https://slack.com/api/chat.update", message.to_json, headers = { content_type: :json, Authorization: "Bearer #{@slack_token}"})
   end

end
