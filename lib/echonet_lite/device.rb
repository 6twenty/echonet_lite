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

    def handle_frame(frame)
      # Compare TID to pending request in order to remove request locking
      if @pending_request && @pending_request.key?(frame.tid)
        @pending_request = nil
      end

      return if frame.type == :response_not_possible

      property_data = frame.property_data.dup

      frame.opc.times do
        epc = property_data.shift
        pdc = property_data.shift
        edt = property_data.shift(pdc)

        receive_property(epc, pdc, edt)
      end
    end

    def update
      profile.class.properties.each do |key, detail|
        next if key.is_a?(Numeric) # Skip EPC aliases
        next unless detail[:access].include?(:get) # Skip set requests

        request_property(detail[:epc])

        while @pending_request
          sleep 0.01
        end
      end

      self
    end

    def request_property(epc_or_name)
      if @pending_request
        raise EchonetLiteError, "Device already has a pending request: #{@pending_request}"
      end

      detail = profile.class.properties[epc_or_name]
      tid = EchonetLite.send_OPC1(ip, @eoj, ESV_CODES[:get], detail[:epc])

      @pending_request = { tid => detail[:name] }
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
