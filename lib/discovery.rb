require 'puppet'
$LOAD_PATH << '/opt/asm-deployer/lib'
require 'asm/api'

module Idrac
  class Discovery

    def initialize(opt)
      @server = opt[:server]
      @port = opt[:port]
      @username = opt[:username]
      @password = opt[:password]
      @timeout = opt[:timeout] || 1800
      @community_string = opt[:community_string]
      @credential_id = opt[:credential_id]
      @output = opt[:output]
      @discovery_job_name = nil
      @reference_id = nil
      @job_status = ''
    end

    attr_accessor :server, :port, :username, :password, :timeout, :community_string, :credential_id, :output,
                  :discovery_job_name, :reference_id

    def asm_manager_server_discovery_request
      result = ASM::Api::sign() {
        RestClient.post("http://localhost:9080/AsmManager/ServerDiscoveryRequest",
                        {:deviceType => "server",
                         :displayName => "discovery of server: #{SecureRandom.uuid}",
                         :refId => SecureRandom.uuid,
                         :refType => "discoveryIpRefType",
                         :credentialId => credential_id,
                         :ipAddress => server
                        }.to_json,
                        :accept => :json,
                        :content_type => :json)
      }
      @reference_id = JSON.parse(result)["refId"]
      STDERR.puts "Idrac::Discovery received refId: #{reference_id} from /AsmManager/ServerDiscoveryRequest" if @job_status
      reference_id
    end

    def java_resource_adapter_framework_discovery
      result = ASM::Api::sign() {
        RestClient.post("http://localhost:9080/JRAF/discovery",
                        {:refId => reference_id,
                         :refType => "discoveryIpRefType",
                         :displayName => "discovery of server:#{SecureRandom.uuid}",
                         :deviceType => "server",
                         :credentialId => credential_id,
                         :ipAddress => server
                        }.to_json,
                        :accept => :json,
                        :content_type => :json)
      }
      @discovery_job_name = JSON.parse(result)["jobName"]
      STDERR.puts "Idrac::Discovery received jobName: #{discovery_job_name} from /JRAF/discovery"
      discovery_job_name
    end

    def wait_for_complete
      start_time=DateTime.now

      until @job_status.include?("SUCCESSFUL") || @job_status.include?("FAILED") do
        job_status
        check_timeout(start_time)
        sleep 15
      end
      end_time=DateTime.now
      elapsed_seconds = ((end_time - start_time) * 24 * 60 * 60).to_i
      STDERR.puts "Idrac::Discovery waited #{elapsed_seconds} seconds for /JRAF/discovery to complete." if @job_status.include?("SUCCESSFUL")
      raise "Idrac::Discovery waited #{elapsed_seconds} seconds for /JRAF/discovery to fail." if @job_status.include?("FAILED")
      elapsed_seconds
    end

    def job_status
      @job_status = ASM::Api::sign { RestClient.get("http://localhost:9080/JRAF/jobhistory/#{discovery_job_name}/status", :accept => :json) } if discovery_job_name
    end

    def get_discovered_devices
      discovered_device_xml = ASM::Api::sign { RestClient.get("http://localhost:9080/JRAF/discovery/#{discovery_job_name}/devices", :accept => :xml) } if discovery_job_name
      @reference_id = Nokogiri::XML(discovered_device_xml).at_css("refId").text
      STDERR.puts "Idrac::Discovery received refId: #{reference_id} from /JRAF/discovery/#{discovery_job_name}/devices"
      reference_id
    end

    def asm_manager_server
      STDERR.puts "Idrac::Discovery getting server json from /AsmManager/Server/#{reference_id}"
      puts json = ASM::Api::sign { RestClient.get("http://localhost:9080/AsmManager/Server/#{reference_id}", :accept => :json) } if reference_id
      json
    end

    def check_timeout(start_time)
      current_time=DateTime.now
      elapsed_seconds = ((current_time - start_time) * 24 * 60 * 60).to_i
      STDERR.puts "Idrac::Discovery Waiting for discovery to complete. Timeout: #{timeout-elapsed_seconds} seconds " +
                      "Job status is #{@job_status}"
      raise("Idrac::discovery /JRAF/discovery was not successful in #{elapsed_seconds} seconds ") if elapsed_seconds >= timeout
      elapsed_seconds
    end

  end
end

