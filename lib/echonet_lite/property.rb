module EchonetLite
  class Property
    attr_reader :data

    # EPC = Echonet property code (operation status etc)
    # PDC = Property data counter (EDT bytes)
    # EDT = Property value data (on, off etc)
    def initialize(epc, pdc, edt, device)
      @epc = epc
      @pdc = pdc
      @edt = edt
      @device = device
      @data = device.process_epc(@epc, @edt)
    end

    def name
      @device.profile.class.properties[@epc][:name]
    end
  end
end
