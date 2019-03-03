module EchonetLite
  class Property
    attr_reader :profile

    # EPC = Echonet property code (operation status etc)
    # PDC = Property data counter (EDT bytes)
    # EDT = Property value data (on, off etc)
    def initialize(epc, pdc, edt, profile)
      @epc = epc
      @pdc = pdc
      @edt = edt
      @profile = profile
    end

    def name
      @name ||= profile.class::EPC.invert[@epc]
    end

    def data
      @data ||= profile.parse_edt(name, @edt)
    end
  end
end
