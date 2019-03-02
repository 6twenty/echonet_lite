require "socket"
require "ipaddr"

require "echonet_lite/eoj"
require "echonet_lite/epc"
require "echonet_lite/esv"
require "echonet_lite/frame"
require "echonet_lite/property"
require "echonet_lite/device"

module EchonetLite
  ENL_PORT = 3610
  ENL_MULTICAST_ADDRESS = "224.0.23.0"

  # These values never change
  EHD1 = 0x10 # (Echonet Lite)
  EHD2 = 0x81 # (Format 1)

  def self.decode_msg(msg)
    msg.scan(/.{1,#{2}}/).map(&:hex)
  end

  def self.encode_msg(seoj, deoj, esv, epc, edt)
    msg = [
      EHD1, # EHD1
      EHD2, # EHD2
      0x36, 0x10, # TID (TODO: should this be able to change, e.g. increment?)
      seoj[0],seoj[1],seoj[2], # SEOJ
      deoj[0],deoj[1],seoj[2], # DEOJ
      esv, # ESV
      0x01, # OPC (TODO: support for multiple properties)
      epc # EPC
    ]

    if esv == ESV::MAP[:get]
      msg << 0x00 # PDC
    else
      msg << 0x01 # PDC (TODO: what if edt is more than 1 byte?)
      msg += edt # EDT
    end

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

  def self.send_OPC1(ip, seoj, deoj, esv, epc, edt = nil)
    udp_send(ip, encode_msg(seoj, deoj, esv, epc, edt))
  end

  def self.search
    ip = ENL_MULTICAST_ADDRESS
    seoj = [0x05, 0xFF, 0x01] # Why?
    deoj = [0x0E, 0xF0, 0x01] # Why?
    esv = ESV::MAP[:get]
    epc = 0x9F

    send_OPC1(ip, seoj, deoj, esv, epc)
  end

  def self.listen(&block)
    udps = UDPSocket.open
    udps.bind("0.0.0.0", ENL_PORT)
    mreq = IPAddr.new(ENL_MULTICAST_ADDRESS).hton + IPAddr.new("0.0.0.0").hton
    udps.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)

    Thread.start do
      loop do
        packet, addr = udps.recvfrom(65535)
        msg = packet.unpack("H*")
        block.call(msg, addr)
      end
    end
  end
end
