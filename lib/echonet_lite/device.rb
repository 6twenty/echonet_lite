module EchonetLite
  class Device
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

    def update_property(epc_or_name, edt)
      detail = profile.properties[epc_or_name]
      data = process_epc(detail[:epc], edt)

      properties[detail[:name]] = data
    end

    def update
      profile.properties.each do |key, detail|
        next if key.is_a?(Numeric) # Skip the EPC aliases
        next unless detail[:access].include?(:get) # Only get requests

        get_property(detail[:epc])
      end
    end

    def get_property(epc_or_name)
      detail = profile.properties[epc_or_name]
      esv = EchonetLite::Frame::ESV_CODES[:get]
      epc = detail[:epc]
      request_frame = Frame.for_request(@eoj, esv, epc, ip: ip)

      request_frame.send

      unless properties[detail[:name]]
        p ["Failed to update property", detail[:name], request_frame.response_frames]
      end
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
  end
end
