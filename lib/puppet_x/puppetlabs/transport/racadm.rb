require 'net/ssh'
module PuppetX::Puppetlabs::Transport
  class Racadm
    attr_accessor :ssh
    attr_reader :name

    def initialize(opts)
      @name    = opts[:name]
      options  = opts[:options] || {}
      @options = options.inject({}){|h, (k, v)| h[k.to_sym] = v; h}
      @options[:host]     = opts[:server]
      @options[:user]     = opts[:username]
      @options[:password] = opts[:password]
      Puppet.debug("#{self.class} initializing connection to: #{@options[:host]}")
    end

    def connect
      i = 0
      begin
        port = @options[:port] ? @options[:port] : 22
        @ssh = Net::SSH.start(@options[:host], @options[:user], :port => port, :password => @options[:password],
                              :verify_host_key => false)
      rescue => e
        i += 1
         if i < 4
           Puppet.debug("PuppetX::Puppetlabs::Transport::Idrac failed to connect. retrying in 10 seconds...")
           sleep 10
           retry
         else
          raise e
         end
      end
    end

    def close
      Puppet.debug("#{self.class} closing connection to: #{@options[:host]}")
      @ssh.close if @ssh
    end

  end
end
