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
      @profile = Profiles.from_eoj(eoj, self)
      @properties = {}
    end

    def init
      profile.class.properties.each do |key, detail|
        next if key.is_a?(Numeric) # Skip EPC lookups

        if detail[:access].include?(:get)
          sleep(2) # TODO, surely there's a better way...
          request_property(detail[:epc])
        end
      end
    end

    def request_property(epc_or_name)
      epc = profile.class.properties[epc_or_name][:epc]
      tid = EchonetLite.send_OPC1(ip, @eoj, ESV_CODES[:get], epc)
    end

    def receive_property(epc, pdc, edt)
      Property.new(epc, pdc, edt, self).tap do |property|
        properties[property.name] = property.data
      end
    end

    def process_epc(epc, edt)
      detail = profile.class.properties[epc]

      send("process_epc_#{detail[:type]}", edt.dup, detail)
    end

    def process_epc_eoj_list(edt, detail)
      instances_count = edt.shift || 0

      instances_count.times.map do
        instance_eoj = edt.shift(3)
        Device.from_eoj(instance_eoj, ip)
      end
    end

    def process_epc_hash(edt, detail)
      detail[:values][edt[0]]
    end

    def process_epc_temp(edt, detail)
      edt[0] == 0x7E ? :unknown : edt[0]
    end

    def process_epc_string(edt, detail)
      edt.pack("C*").strip
    end
  end
end
