require 'mkit/status'
require 'mkit/utils'
require 'mkit/exceptions'
require 'mkit/app/helpers/interface_helper'

module MKIt
  class Interface
    def self.ip
      main_pool = Pool.find_by_name(MKIt::Utils.me)
      main_pool.ip
    end

    def self.up
      main_pool = Pool.find_by_name(MKIt::Utils.me)
      interface_name = "#{main_pool.name}0"
      interface_type = "tap"
      ip = main_pool.ip
      mask = main_pool.netmask
      MKIt::InterfaceHelper.create(name: interface_name, ctype: interface_type)
      MKIt::InterfaceHelper.up(name: interface_name, ip: ip, mask: mask)
    end

    def self.down
      main_pool = Pool.find_by_name(MKIt::Utils.me)
      interface_name = "#{main_pool.name}0"
      interface_type = "tap"
      MKIt::InterfaceHelper.down(name: interface_name)
      MKIt::InterfaceHelper.remove(name: interface_name, ctype: interface_type)
    end
  end
end
