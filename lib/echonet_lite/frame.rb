module EchonetLite
  class Frame
    attr_reader :ip, :protocol_type, :format, :properties, :valid
    attr_reader :EHD1, :EHD2, :TID, :SEOJ, :DEOJ, :ESV

    def initialize(data, ip)
      @ip = ip

      decode(data)
    end

    def valid?
      @valid
    end

    def decode(data)
      if data.size < 12
        @valid = false
        return
      end

      decode_header(data[0...4])
      decode_data(data[4..-1])

      @valid = true
    end

    # EHD1 (1), EHD2 (1), TID (2)
    #
    # EHD1 = 0x10 (Echonet Lite)
    # EHD2 = 0x81 (Format 1)
    # TID = Transaction ID
    def decode_header(data)
      @EHD1 = data[0]
      @EHD2 = data[1]
      @TID = data[2...4]

      if @EHD1 == 0x10
        @protocol_type = 'ECHONET_Lite'
      elsif @EHD1 >= 0x80
        @protocol_type = 'ECHONET'
      else
        @protocol_type = 'UNKNOWN'
      end

      if @EHD2 == 0x81
        @format = '1'
      elsif @EHD2 == 0x82
        @format = '2'
      else
        @format = 'UNKNOWN'
      end
    end

    # SEOJ (3), DEOJ (3), ESV (1), OPC (1), EPC n (1), PDC n (1), EDT n [...]
    #
    # EOJ[0] = Class group code
    # EOJ[1] = Class code
    # EOJ[2] = Instance code
    #
    # SEOJ = Source object
    # DEOJ = Destination object
    # ESV = Service code (GET, SET etc)
    # OPC = Target property counter (number of properties to follow)
    # EPC = Echonet property code (operation status etc)
    # PDC = Property data counter (EDT bytes)
    # EDT = Property value data (on, off etc)
    def decode_data(data)
      @SEOJ = data[0...3]
      @DEOJ = data[3...6]
      @ESV = data[6]
      @OPC = data[7]

      @properties = []
      property_data = data[8..].dup

      @OPC.times do
        epc = property_data.shift
        pdc = property_data.shift
        edt = property_data.shift(pdc)

        @properties << Property.new(epc, pdc, edt)
      end
    end
  end
end
