require 'mkit/status'
require 'mkit/exceptions'
require 'mkit/app/helpers/interface_helper'

class Lease < ActiveRecord::Base
  belongs_to :pool
  belongs_to :service

  before_destroy :down

  def confirm
    self.status = MKIt::PoolStatus::IN_USE
  end

  def up
    MKIt::InterfaceHelper.create(name: interface_name, ctype: interface_type)
    MKIt::InterfaceHelper.up(name: interface_name, ip: ip, mask: pool.netmask)
    self.status = MKIt::PoolStatus::IN_USE
  end

  def down
    MKIt::InterfaceHelper.down(name: interface_name)
    MKIt::InterfaceHelper.remove(name: interface_name, ctype: interface_type)
    self.status = MKIt::PoolStatus::RESERVED
  end
end
