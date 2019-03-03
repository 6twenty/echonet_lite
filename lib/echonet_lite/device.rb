module EchonetLite
  class Device
    DEVICES = {}

    def self.register(ip, profile)
      DEVICES[ip] ||= new(ip, profile)
    end

    attr_reader :ip, :profile

    def initialize(ip, profile)
      @ip = ip
      @profile = profile
    end
  end
end
