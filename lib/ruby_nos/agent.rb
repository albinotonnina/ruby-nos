module RubyNos
  class Agent
    include Initializable
    attr_accessor :uuid, :cloud, :pending_response_list, :udp_tx, :udp_rx,:processor, :rest_api

    def uuid
      @uuid ||= SecureRandom.uuid
    end

    def udp_tx
      @udp_tx ||= UDPSender.new
    end

    def udp_rx
      @udp_rx ||= UDPReceptor.new
    end

    def cloud
      @cloud  ||= Cloud.new
    end

    def processor
      @processor ||= Processor.new(self)
    end

    def configure
       at_exit {
         send_desconnection_message
       }
      listen
      join_cloud
      send_connection_messages
    end

    def send_message args={}
      message = build_message(args)
      udp_tx.send({host: args[:host], port: args[:port], message: message})
      message
    end

    private

    def send_connection_messages
      begin
        thread = Thread.new do
          i = 0
          loop do
            i = i+1
            RubyNos.logger.send(:info, "Iteration number #{i}")
            RubyNos.logger.send(:info, "Agents on the cloud #{cloud.list_of_agents.count}")
            send_message({type: 'DSC'})
            send_message({type: 'ENQ'})
            unless cloud.list_of_agents.empty?
              cloud.list_of_agents.each do |agent_uuid|
                if last_message_exists?(agent_uuid)
                  send_message({to: "AGT:#{uuid_for_message(agent_uuid)}", type: "PIN"})
                else
                  cloud.eliminate_from_list(agent_uuid)
                end
              end
            end
            sleep RubyNos.time_between_messages
          end
        end
        thread
      rescue Exception => e
        RubyNos.logger.send(:info, "Error executing the thread #{e.message}")
      end
    end

    def last_message_exists?(agent_uuid)
      remote_agent = cloud.info_on_the_list(agent_uuid)
      (Formatter.timestamp - remote_agent.timestamp) < RubyNos.keep_alive_time
    end

    def build_message args
      if args[:data]
        data = args[:data]
      elsif args[:type] == "PRS"
        data = receptor_info
      elsif args[:type] == "QNE"
        data = rest_api.to_hash if rest_api
      end

      if data
        Message.new({from: "AGT:#{uuid_for_message(uuid)}", to: args[:to] || "CLD:#{uuid_for_message(cloud.uuid)}", type: args[:type], sequence_number: args[:sequence_number], data: data}).serialize_with_optional_fields({options: [:dt]})
      else
        Message.new({from: "AGT:#{uuid_for_message(uuid)}", to: args[:to] || "CLD:#{uuid_for_message(cloud.uuid)}", type: args[:type], sequence_number: args[:sequence_number]}).serialize_message
      end
    end


    def receptor_info
      {present: 1, endpoints: ["UDP,#{udp_rx.socket.connect_address.ip_port},#{udp_rx.socket.connect_address.ip_address}"]}
    end

    def listen
      udp_rx.listen(processor)
    end

    def join_cloud
      send_message({type: 'PRS'})
      send_message({type: 'QNE'}) if rest_api
    end

    def formatter
      @formatter ||= Formatter.new
    end

    def uuid_for_message uuid
      if formatter.uuid_format?(uuid)
        formatter.uuid_to_string(uuid)
      else
        uuid
      end
    end

    def send_desconnection_message
      send_message({type: "PRS", data: {present: 0}})
    end
  end
end