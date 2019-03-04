module EchonetLite
  class Property
    attr_reader :data

    # EPC = Echonet property code (operation status etc)
    # PDC = Property data counter (EDT bytes)
    # EDT = Property value data (on, off etc)
    def initialize(epc, pdc, edt, profile)
      @epc = epc
      @pdc = pdc
      @edt = edt
      @profile = profile
      @data = profile.process_epc(@epc, @edt)
    end

    def name
      return :unknown unless @profile.can_process_epc?(@epc)

      @name ||= @profile.class::EPC.invert[@epc]
    end
  end
end
