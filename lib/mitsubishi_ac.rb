require "mitsubishi_ac/version"
require "echonet_lite"

module MitsubishiAc
  Error = Class.new(StandardError)

  # def self.frames
  #   @@frame_pool
  # end

  # def self.start
  #   @@frame_pool = []

    # EchonetLite.listen do |msg, addr|
    #   puts [msg, addr].unshift("RECEIVE:").inspect

    #   _, port, ip, _ = addr

    #   msg = EchonetLite.decode_msg(msg.first)

    #   puts [msg, ip, port].unshift("DECODED:").inspect

    #   @@frame_pool << EchonetLite::Frame.new(msg, ip, port)
    # end
  # end

  def self.discover
    known_devices = []

    thread = EchonetLite.listen do |msg, addr|
      _, port, ip, _ = addr
      msg = EchonetLite.decode_msg(msg.first)
      frame = EchonetLite::Frame.new(msg, ip)

      if frame.ESV == EchonetLite::ESV::MAP[:getres]
        known_devices << EchonetLite::Device.new(frame)
      end
    end

    EchonetLite.search

    # Give it 5 seconds for devices to respond
    sleep 5

    thread.exit

    known_devices
  end
end
