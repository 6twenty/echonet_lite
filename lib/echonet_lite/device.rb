module EchonetLite
  class Device
    LOOKUP = {}

    def self.from_eoj(eoj, ip)
      LOOKUP["#{ip}_#{eoj.join('-')}"] ||= begin
        self.new(ip, eoj)
      end
    end

    attr_reader :ip, :profile, :properties

    def initialize(ip, eoj)
      @ip = ip
      @id = eoj[2]
      @eoj = eoj
      @profile= Profiles.from_eoj(eoj, self)
      @properties = {}
    end

    def request_property(epc)
      EchonetLite.send_OPC1(ip, @eoj, REQUEST_CODES[:get], epc)
    end

    def receive_property(epc, pdc, edt)
      Property.new(epc, pdc, edt, profile).tap do |property|
        properties[property.name] = property.data
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      property_name = method_name.to_s.sub(/^request_/, '').to_sym

      profile.class::EPC.key?(property_name) ? true : super
    end

    def method_missing(method_name, *arguments, &block)
      property_name = method_name.to_s.sub(/^request_/, '').to_sym

      return super unless profile.class::EPC.key?(property_name)

      request_property(profile.class::EPC[property_name])
    end
  end
end
