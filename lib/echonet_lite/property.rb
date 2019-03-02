module EchonetLite
  class Property
    attr_reader :EPC, :PDC, :EDT

    def initialize(epc, pdc, edt)
      @EPC = epc
      @PDC = pdc
      @EDT = edt
    end
  end
end
