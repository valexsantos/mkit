require 'async/dns'
require 'async/dns/system'
require 'mkit/mkit_interface'
require 'ipaddr'

# INTERFACES = [
#   [:udp, "127.0.0.20", 53],
#   [:tcp, "127.0.0.20", 53],
# ]
# @resolver = RubyDNS::Resolver.new(
#   [:udp, "192.168.4.254", 53],
#   [:tcp, "192.168.4.254", 53]
# )
# 
# # Use upstream DNS for name resolution.
UPSTREAM = RubyDNS::Resolver.new([
   [:udp, "8.8.8.8", 53],
   [:tcp, "8.8.8.8", 53]
 ])

Name = Resolv::DNS::Name
IN = Resolv::DNS::Resource::IN

module MKIt
  class DNS < Async::DNS::Server
    def initialize
      addr = MKIt::Interface.ip
      listen_addr = [
        [:udp, addr, 53],
        [:tcp, addr, 53],
      ]
      super(listen_addr)
      @logger.info!
      @resolver = RubyDNS::Resolver.new(Async::DNS::System.nameservers)
    end
    def process(name, resource_class, transaction)
      host = DnsHost.find_by_name(name)
      if host.nil?
        transaction.passthrough!(@resolver)
      else
        ipaddr = IPAddr.new host.ip
        if resource_class == Resolv::DNS::Resource::IN::A
          transaction.respond!(ipaddr.to_s)
        elsif resource_class == Resolv::DNS::Resource::IN::AAAA
          transaction.respond!(ipaddr.ipv4_mapped.to_s)
        else
          transaction.fail!(:NXDomain)
        end
      end
    end
  end
end


