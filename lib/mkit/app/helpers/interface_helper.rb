module MKIt
  module InterfaceHelper
    module_function
    def create(name:, ctype:)
      %x{ip tuntap add mode #{ctype} #{name}}
    end
    def remove(name:, ctype:)
      %x{ip tuntap del mode #{ctype} #{name}}
    end
    def up(name:, ip:, mask:)
      %x{ifconfig #{name} #{ip}/#{mask} up}
    end
    def down(name:)
      %x{ifconfig #{name} 0.0.0.0 down}
    end
  end
end
