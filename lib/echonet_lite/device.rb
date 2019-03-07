module EchonetLite
  class Device
    RATE_LIMIT = 1 # Seconds
    LOOKUP = {}

    def self.init(eoj, ip)
      LOOKUP["#{eoj}#{ip}"] ||= new(eoj, ip)
    end

    attr_reader :ip, :profile, :properties

    def initialize(eoj, ip)
      @ip = ip
      @class_group_code, @class_code, @id = eoj
      @eoj = eoj
      @profile = Profiles::LOOKUP.dig(@class_group_code, @class_code)
      @properties = {}
    end

    def receive_property(epc_or_name, edt)
      detail = profile.properties[epc_or_name]
      data = process_epc(detail[:epc], edt)

      properties[detail[:name]] = data
    end

    def update
      return properties if updated_recently?

      profile.properties.each do |key, detail|
        next unless detail[:access].include?(:get) # Only get requests

        get_property(detail[:epc])
      end

      properties
    end

    def updated_recently?
      return false unless @last_updated

      (Time.now - @last_updated) < RATE_LIMIT
    end

    def get_property(name)
      detail = profile.properties[name]
      esv = Frame::ESV_CODES[:get]
      epc = detail[:epc]
      request_frame = Frame.for_request(@eoj, esv, epc, ip: ip)
      current_value = properties.delete(detail[:name])

      request_frame.send

      unless properties[detail[:name]]
        p ["Failed to get property", detail[:name], request_frame.response_frames]
        properties[detail[:name]] = current_value
      end

      properties[detail[:name]]
    end

    def set_property(name, value)
      detail = profile.properties[name]
      esv = Frame::ESV_CODES[:setc]
      epc = detail[:epc]
      request_frame = Frame.for_request(@eoj, esv, epc, value, ip: ip)
      previous_value = properties[name]

      # Assume it will be successful
      properties[name] = value

      request_frame.send

      if request_frame.response_not_possible?
        # Revert to previous value
        properties[name] = previous_value
      end
    end

    def encode_epc(epc, value)
      detail = profile.properties[epc]

      send("encode_epc_#{detail[:type]}", value, detail)
    end

    def encode_epc_hash(value, detail)
      detail[:values].invert[value]
    end

    def encode_epc_temp(value, detail)
      value
    end

    def process_epc(epc, edt)
      detail = profile.properties[epc]

      send("process_epc_#{detail[:type]}", edt.dup, detail)
    end

    def process_epc_eoj_list(edt, detail)
      instances_count = edt.shift || 0

      instances_count.times.map do
        eoj = edt.shift(3)
        Device.init(eoj, ip)
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

    def process_epc_bytes(edt, detail)
      edt
    end
  end
end
