module EchonetLite
  class Frame
    SELF_IP = "0.0.0.0"
    SELF_PROFILE = Profiles::ManagementControlRelatedDeviceGroup::Controller
    SELF_ID = 0x01

    ENL_PORT = 3610
    ENL_MULTICAST_ADDRESS = "224.0.23.0"
    TIMEOUT = 1 # Seconds
    MAX_RETRIES = 3

    EHD1 = 0x10 # (Echonet Lite)
    EHD2 = 0x81 # (Format 1)
    TID = [0x00, 0x00] # Transaction ID (will increment)

    RESPONSE_NOT_POSSIBLE_RANGE = 0x50..0x5F
    REQUEST_RANGE = 0x60..0x6F
    RESPONSE_RANGE = 0x70..0x7F

    ESV_CODES = {
      seti: 0x60, # Property value write request (no response required)
      setc: 0x61, # Property value write request (response required)
      get: 0x62, # Property value read request
      inf_req: 0x63, # Property value notification request
      setget: 0x6E, # Property value write & read request
      set_res: 0x71, # Property value write response
      get_res: 0x72, # Property value read response
      inf: 0x73, # Property value notification
      infc: 0x74, # Property value notification (response required)
      infc_res: 0x7A, # Property value notification response
      setget_res: 0x7E, # Property value write & read response
      seti_sna: 0x50, # Property value write request (response not possible)
      setc_sna: 0x51, # Property value write request (response not possible)
      get_sna: 0x52, # Property value read (response not possible)
      inf_sna: 0x53, # Property value notification (response not possible)
      setget_sna: 0x5E # Property value write & read (response not possible)
    }

    def self.next_tid
      TID[1] = TID[1].next

      if TID[1] > 0xFF
        TID[1] = 0x00
        TID[0] = TID[0].next

        if TID[0] > 0xFF
          TID[0] = 0x00
        end
      end

      TID
    end

    def self.for_request(deoj, esv, epc, edt = [], ip: SELF_IP)
      from_bytes([
        EHD1,
        EHD2,
        *next_tid,
        SELF_PROFILE.class_group_code,
        SELF_PROFILE.class_code,
        SELF_ID,
        *deoj,
        esv,
        0x01,
        epc,
        Array(edt).size,
        *edt
      ], ip)
    end

    def self.from_bytes(data, ip)
      data = decode(data)

      if REQUEST_RANGE.cover?(data[:esv])
        if ip == ENL_MULTICAST_ADDRESS
          RequestMulticastFrame.new(data, source_ip: SELF_IP, destination_ip: ip)
        else
          RequestFrame.new(data, source_ip: SELF_IP, destination_ip: ip)
        end
      elsif RESPONSE_RANGE.cover?(data[:esv])
        ResponseFrame.new(data, source_ip: ip, destination_ip: SELF_IP)
      elsif RESPONSE_NOT_POSSIBLE_RANGE.cover?(data[:esv])
        ResponseNotPossibleFrame.new(data, source_ip: ip, destination_ip: SELF_IP)
      else
        raise EchonetLiteError, "Unknown ESV: #{data[:esv]}"
      end
    end

    # EHD1 (1), EHD2 (1), TID (2), SEOJ (3), DEOJ (3), ESV (1), OPC (1), EPC n (1), PDC n (1), EDT n [...]
    #
    # EOJ[0] = Class group code
    # EOJ[1] = Class code
    # EOJ[2] = Instance code
    #
    # EHD1 = 0x10 (Echonet Lite)
    # EHD2 = 0x81 (Format 1)
    # TID = Transaction ID
    # SEOJ = Source object
    # DEOJ = Destination object
    # ESV = Service code (GET, SET etc)
    # OPC = Target property counter (number of properties to follow)
    # EPC = Echonet property code (operation status etc)
    # PDC = Property data counter (EDT bytes)
    # EDT = Property value data (on, off etc)
    def self.decode(data)
      if data.size < 12
        raise EchonetLiteError, "Frame could not decode data: #{data}"
      end

      decoded = {
        ehd1: data[0],
        ehd2: data[1],
        tid: data[2..3],
        seoj: data[4..6],
        deoj: data[7..9],
        esv: data[10],
        opc: data[11]
      }

      if data.size > 12
        decoded.merge!({
          epc: data[12],
          pdc: data[13],
          edt: data[14..]
        })
      end

      decoded
    end

    attr_reader :source_ip, :destination_ip, :response_frames
    attr_reader :ehd1, :ehd2, :tid, :seoj, :deoj, :esv, :opc, :epc, :pdc, :edt

    def initialize(data, source_ip:, destination_ip:)
      @data = data
      @source_ip = source_ip
      @destination_ip = destination_ip
      @retry_count = 0

      data[:edt] ||= []

      data.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end

    def protocol_type
      if ehd1 == 0x10
        "ECHONET_Lite"
      elsif ehd1 >= 0x80
        "ECHONET"
      else
        "UNKNOWN"
      end
    end

    def format
      if ehd2 == 0x81
        "1"
      elsif ehd2 == 0x82
        "2"
      else
        "UNKNOWN"
      end
    end

    def is_response_to?(frame)
      self.is_a?(ResponseFrame) &&
      frame.is_a?(RequestFrame) &&
      frame.tid == self.tid
    end

    class RequestFrame < Frame
      @@send_queue = []
      @@sending = false

      # Ensures only one frame can send at a time
      def self.send(frame)
        @@send_queue << frame

        unless @@sending
          @@sending = true

          while @@send_queue.any?
            @@send_queue.shift.send!
          end

          @@sending = false
        end
      end

      def device
        @device ||= Device.new(deoj, ip)
      end

      def ip
        @destination_ip
      end

      def can_retry?
        @retry_count < MAX_RETRIES
      end

      def retry!
        @retry_count = @retry_count.next

        puts "[Frame] Retrying"

        send
      end

      def multicast?
        false
      end

      def send
        self.class.send(self)
      end

      def send!
        @response_frames = []

        if response_expected?
          # Start UDP server to listen for responses
          udp = UDPSocket.open
          udp.bind(SELF_IP, ENL_PORT)
          mreq = IPAddr.new(ENL_MULTICAST_ADDRESS).hton + IPAddr.new(SELF_IP).hton
          udp.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)
        end

        msg = [ehd1, ehd2, *tid, *seoj, *deoj, esv, opc, epc, pdc, *edt].pack("C*")

        udp_send(msg)

        if response_expected?
          listener_thread = Thread.new do
            await_packet(udp)
          end

          # If no response, abort after <TIMEOUT>
          timer_thread = Thread.new do
            sleep TIMEOUT

            listener_thread.kill
          end

          listener_thread.join
          timer_thread.kill
        end

        not_possible = response_frames.any?(ResponseNotPossibleFrame)
        no_response = response_frames.size == 0

        if (not_possible || no_response) && can_retry?
          udp&.close
          return retry!
        end

        response_frames.each do |frame|
          if frame.is_a?(ResponseNotPossibleFrame)
            p ["ResponseNotPossible", frame]
          elsif frame.edt.size > 0
            frame.device.receive_property(frame.epc, frame.edt)
          end
        end
      ensure
        udp&.close
      end

      def udp_send(msg)
        UDPSocket.open do |udp|
          udp.connect(ip, ENL_PORT)
          udp.send(msg, 0)
        end
      end

      def await_packet(udp)
        packet, addr = udp.recvfrom(65535)
        ip, port = addr.values_at(3, 1)
        msg = packet.unpack("H*").first
        data = msg.scan(/.{1,#{2}}/).map(&:hex)
        frame = Frame.from_bytes(data, ip)

        if frame.is_response_to?(self)
          response_frames << frame
        end

        if should_await_again?(frame)
          await_packet(udp)
        end
      end

      def should_await_again?(frame)
        !frame.is_response_to?(self)
      end

      def response_not_required?
        esv == ESV_CODES[:seti]
      end

      def response_expected?
        !response_not_required?
      end

      def response_not_possible?
        response_frame&.is_a?(ResponseNotPossibleFrame)
      end

      def response_frame
        response_frames&.first
      end
    end

    class RequestMulticastFrame < RequestFrame
      def multicast?
        true
      end

      def udp_send(msg)
        UDPSocket.open do |udp|
          saddr_s = Socket.pack_sockaddr_in(ENL_PORT, ip)
          mif_s = IPAddr.new(SELF_IP).hton
          udp.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, mif_s)
          udp.send(msg, 0, saddr_s)
        end
      end

      def should_await_again?(frame)
        true
      end
    end

    class ResponseFrame < Frame
      def device
        @device ||= Device.init(seoj, ip)
      end

      def ip
        @source_ip
      end
    end

    class ResponseNotPossibleFrame < ResponseFrame

    end
  end
end
