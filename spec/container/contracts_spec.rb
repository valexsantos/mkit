# frozen_string_literal: true

require 'spec_helper'
require 'mkit/container/docker/api'

# Every runtime implementation must provide the whole contract.
CONTRACTS = {
  MKIt::Container::Containers => %i[run start stop remove find exec logs log_path tty? follow_logs attach_exec],
  MKIt::Container::Networks => %i[create find attach detach remove exists?],
  MKIt::Container::Volumes => %i[create find remove],
  MKIt::Container::Events => %i[each]
}.freeze

IMPLEMENTATIONS = {
  MKIt::Container::Containers => MKIt::Container::Docker::Containers,
  MKIt::Container::Networks => MKIt::Container::Docker::Networks,
  MKIt::Container::Volumes => MKIt::Container::Docker::Volumes,
  MKIt::Container::Events => MKIt::Container::Docker::Events
}.freeze

describe 'container contracts' do
  CONTRACTS.each do |contract, methods|
    describe contract.name do
      methods.each do |m|
        it "leaves ##{m} abstract" do
          next if m == :exists? # concrete helper derived from #find

          assert_raises(NotImplementedError) { contract.new.public_send(m) }
        end
      end

      it 'is fully implemented by the docker runtime' do
        impl = IMPLEMENTATIONS.fetch(contract)
        methods.each do |m|
          assert_equal impl, impl.instance_method(m).owner, "#{impl} must implement ##{m}" unless m == :exists?
        end
      end
    end
  end

  it 'names the missing method in the error' do
    err = assert_raises(NotImplementedError) { MKIt::Container::Volumes.new.create('x') }
    assert_match(/must implement #create/, err.message)
  end

  it 'derives Networks#exists? from #find' do
    nets = Class.new(MKIt::Container::Networks) { def find(name) = name == 'a' ? {} : nil }.new
    assert nets.exists?('a')
    refute nets.exists?('b')
  end
end
