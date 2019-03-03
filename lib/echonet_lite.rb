require "socket"
require "ipaddr"

# require "echonet_lite/eoj"
# require "echonet_lite/epc"
# require "echonet_lite/esv"
require "echonet_lite/frame"
require "echonet_lite/property"
require "echonet_lite/profiles"
require "echonet_lite/device"

module EchonetLite
  ENL_PORT = 3610
  ENL_MULTICAST_ADDRESS = "224.0.23.0"

  # These values never change
  EHD1 = 0x10 # (Echonet Lite)
  EHD2 = 0x81 # (Format 1)

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

  LISTENERS = []

  def self.decode_msg(msg)
    msg.scan(/.{1,#{2}}/).map(&:hex)
  end

  def self.encode_msg(seoj, deoj, esv, epc, edt)
    tid = [0x36, 0x10] # (TODO: should this be able to change, e.g. increment?)
    opc = 0x01 # (TODO: support for multiple properties?)
    pdc = edt.size

    msg = [EHD1, EHD2, *tid, *seoj, *deoj, esv, opc, epc, pdc, *edt]

    msg.pack("C*")
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

  def self.send_OPC1(ip, seoj, deoj, esv, epc, edt = [])
    udp_send(ip, encode_msg(seoj, deoj, esv, epc, edt))
  end

  def self.start
    udps = UDPSocket.open
    udps.bind("0.0.0.0", ENL_PORT)
    mreq = IPAddr.new(ENL_MULTICAST_ADDRESS).hton + IPAddr.new("0.0.0.0").hton
    udps.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)

    Thread.start do
      loop do
        packet, addr = udps.recvfrom(65535)
        _, port, ip, _ = addr
        msg = packet.unpack("H*")
        msg = decode_msg(msg.first)
        frame = Frame.new(msg, ip)

        LISTENERS.each do |block|
          block.call(frame)
        end
      end
    end
  end

  def self.add_listener(&block)
    LISTENERS << block
  end

  def self.remove_listener(&block)
    LISTENERS.delete(block)
  end

  def self.discover
    devices = []

    listener = (frame) -> do
      is_node_profile = frame.source_profile.is_a?(Profiles::ProfileGroup::NodeProfile)
      has_instance_list = frame.properties.any? do |property|
        property.name == :self_node_instance_list_s
      end

      if frame.response? && is_node_profile && has_instance_list
        frame.properties.first.parsed.each do |instance|
          devices << Device.register(frame.ip, instance)
        end
      end
    end

    add_listener(&listener)

    ip = ENL_MULTICAST_ADDRESS
    seoj = Profiles::ManagementControlRelatedDeviceGroup::Controller.new.eoj
    deoj = Profiles::ProfileGroup::NodeProfile.new.eoj
    esv = REQUEST_CODES[:get]
    epc = Profiles::ProfileGroup::NodeProfile::EPC[:self_node_instance_list_s]

    send_OPC1(ip, seoj, deoj, esv, epc)

    # Give it 3 seconds for devices to respond
    sleep 3

    remove_listener(&listener)

    devices
  end
end
