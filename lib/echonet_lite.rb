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
  ENL_PORT = 3610
  ENL_MULTICAST_ADDRESS = "224.0.23.0"

  # These values never change
  EHD1 = 0x10 # (Echonet Lite)
  EHD2 = 0x81 # (Format 1)
  TID = [0x00, 0x00] # Transaction ID (will increment)
  SEOJ = Profiles::ManagementControlRelatedDeviceGroup::Controller.new.yield_self do |profile|
    [profile.class_group_code, profile.class_code, 0x01]
  end

  REQUEST_CODES = {
    getc: 0x60,
    setc: 0x61,
    get: 0x62,
    infreq: 0x63,
    setget: 0x6E,
    inf: 0x73,
    infc: 0x74
  }

  RESPONSE_CODES = {
    setres: 0x71,
    getres: 0x72,
    infc_res: 0x7A,
    setget_res: 0x7E,
    seti_sna: 0x50,
    setc_snd: 0x51,
    get_sna: 0x52,
    inf_sna: 0x53,
    setget_sna: 0x5E
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
    udp_send(ip, encode_msg(next_tid, SEOJ, deoj, esv, epc, edt))
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
