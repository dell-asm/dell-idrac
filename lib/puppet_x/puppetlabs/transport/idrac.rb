module PuppetX::Puppetlabs::Transport
  class Idrac
    attr_reader :name
    def initialize(opts)
      @name    = opts[:name]
      options  = opts[:options] || {}
      @options = options.inject({}){|h, (k, v)| h[k.to_sym] = v; h}
      @options[:host]     = opts[:server]
      @options[:user]     = opts[:username]
      @options[:password] = opts[:password]
    end

    def connect
      #satifies transport interface requirements
    end

    def endpoint
      @options
    end

  end
end
