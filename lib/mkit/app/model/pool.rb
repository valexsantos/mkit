require 'mkit/app/model/lease'
require 'mkit/status'
require 'mkit/exceptions'

class Pool < ActiveRecord::Base
  has_many :lease, dependent: :destroy

  def check_status
    if status == MKIt::PoolStatus::EXAUSTED
      raise PoolExaustedException.new
    end
  end

  def next_lease_ip
    self.check_status
    ips = range.split('-')
    next_ip = ips[0]
    next_ip = next_ip.to_i
    lease.select(:status == MKIt::PoolStatus::IN_USE || :status == MKIt::PoolStatus::RESERVED).each { |l|
      leased_ip = l.ip.split('.')[3]
      leased_ip = leased_ip.to_i
      if leased_ip >= next_ip
        next_ip = leased_ip+1
      end
    }
    if next_ip > ips[1].to_i
      self.status = MKIt::PoolStatus::EXAUSTED
      self.save
      raise PoolExaustedException.new
    end

    ip_add = self.ip.split('.')

    "#{ip_add[0]}.#{ip_add[1]}.#{ip_add[2]}.#{next_ip}"
  end

  def request(service:, status:)
    lease_ip = next_lease_ip
    idx = lease_ip.split('.')[3]
    new_lease = Lease.new(
      pool: self,
      service: service,
      interface_name: "vmkit#{idx}",
      interface_type: 'tun',
      status: status,
      ip: lease_ip
    )
    new_lease.save
    new_lease
  end

  def request_for(service)
     request(service: service, status:  MKIt::PoolStatus::IN_USE)
  end

  def reserve_for(service)
     request(service: service, status:  MKIt::PoolStatus::RESERVED)
  end
end

