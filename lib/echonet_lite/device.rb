module EchonetLite
  class Device
    attr_reader :last_frame, :ip, :EOJ

    def initialize(frame)
      @last_frame = frame
      @ip = frame.ip
      @EOJ = frame.SEOJ
    end
  end
end
