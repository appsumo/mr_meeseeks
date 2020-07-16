require 'dotenv/load'
require 'aws-sdk'

class MySettings


    def initialize
        Aws.config.update({
            region: 'us-west-2',
            credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
        })
    
        @settings_table = 'Mr_Meeseeks2_config'
        @dynamodb = Aws::DynamoDB::Client.new
    end



    def store(setting,hash)
        params = {
            table_name: @settings_table,
            item: {
                setting: setting,
                data: hash
            }
        }
        begin
            @dynamodb.put_item(params)   
        rescue  Aws::DynamoDB::Errors::ServiceError => error
            puts "Unable to add item:"
            puts "#{error.message}"
        end
    end

    def get(key)
        params = {
            table_name: @settings_table,
            key: {
                setting: key
            }
        }
        begin
            result = @dynamodb.get_item(params)
            if result.item == nil
                puts 'Could not find setting'
                nil
            else
                result.item['data']
            end
        rescue  Aws::DynamoDB::Errors::ServiceError => error
            puts 'Unable to find setting:'
            puts error.message
        end
    end

end 