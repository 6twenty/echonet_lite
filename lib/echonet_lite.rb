require "socket"
require "ipaddr"

require "echonet_lite/frame"
require "echonet_lite/property"
require "echonet_lite/profiles"
require "echonet_lite/device"

require "echonet_lite/properties/air_conditioner_related_device_group"
require "echonet_lite/properties/management_control_related_device_group"
require "echonet_lite/properties/profile_group"

module EchonetLite
  EchonetLiteError = Class.new(StandardError)

  ENL_PORT = 3610
  ENL_MULTICAST_ADDRESS = "224.0.23.0"

  EHD1 = 0x10 # (Echonet Lite)
  EHD2 = 0x81 # (Format 1)
  TID = [0x00, 0x00] # Transaction ID (will increment)
  SEOJ = Profiles::ManagementControlRelatedDeviceGroup::Controller.new.yield_self do |profile|
    [profile.class_group_code, profile.class_code, 0x01]
  end

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

  @@thread = nil

  def self.decode_msg(msg)
    msg.scan(/.{1,#{2}}/).map(&:hex)
  end

  def self.encode_msg(tid, seoj, deoj, esv, epc, edt)
    opc = 0x01 # No support for multiple properties
    pdc = edt.size

    msg = [EHD1, EHD2, *tid, *seoj, *deoj, esv, opc, epc, pdc, *edt]

    msg.pack("C*")
  end

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

  def self.udp_send(ip, msg)
    if ip == ENL_MULTICAST_ADDRESS
      udp_s = UDPSocket.open
      saddr_s = Socket.pack_sockaddr_in(ENL_PORT, ENL_MULTICAST_ADDRESS)
      mif_s = IPAddr.new("0.0.0.0").hton
      udp_s.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, mif_s)
      udp_s.send(msg, 0, saddr_s)
      udp_s.close
    else
      udp_socket = UDPSocket.new
      udp_socket.connect(ip, ENL_PORT)
      udp_socket.send(msg, 0)
      udp_socket.close
    end
  end

  def self.send_OPC1(ip, deoj, esv, epc, edt = [])
    next_tid.tap do |tid|
      udp_send(ip, encode_msg(tid, SEOJ, deoj, esv, epc, edt))
    end
  end

  def self.setup
    udps = UDPSocket.open
    udps.bind("0.0.0.0", ENL_PORT)
    mreq = IPAddr.new(ENL_MULTICAST_ADDRESS).hton + IPAddr.new("0.0.0.0").hton
    udps.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)

    @@thread = Thread.start do
      loop do
        packet, addr = udps.recvfrom(65535)
        _, port, ip, _ = addr
        msg = packet.unpack("H*")
        msg = decode_msg(msg.first)
        frame = Frame.new(msg, ip)
      end
    end
  end

  def self.discover
    self.setup if @@thread.nil?

    epc = Profiles::ProfileGroup::NodeProfile.properties[:self_node_instance_list_s][:epc]
    deoj = Profiles::ProfileGroup::NodeProfile.new.yield_self do |profile|
      [profile.class_group_code, profile.class_code, 0x01]
    end

    Device.new(ENL_MULTICAST_ADDRESS, deoj).request_property(epc)

    # Allow time for devices to respond
    sleep 1

    Device::LOOKUP.values
  end
end
