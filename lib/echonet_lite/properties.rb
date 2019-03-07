module EchonetLite
  class Properties < Hash
    def initialize(profile_class)
      @profile_class = profile_class
      @map = {}
    end

    def add(code, name, detail)
      self[code] = detail
      @map[name] = code
    end

    def all
      return self if @profile_class == Profiles::Base

      self.class.new(@profile_class).tap do |properties|
        [self, Profiles::Base.properties].each do |props|
          props.each { |key, value| properties.add(key, value[:name], value) }
        end
      end
    end

    def [](code_or_name)
      self.fetch(code_or_name) do
        self.fetch(@map[code_or_name]) do
          unless @profile_class == Profiles::Base
            Profiles::Base.properties[code_or_name]
          end
        end
      end
    end
  end
end
