module Searchgasm
  module Modifiers
    class Lower < Base
      class << self
        def modifier_names
          super + ["downcase"]
        end
        
        def return_type
          :string
        end
      end
    end
  end
end