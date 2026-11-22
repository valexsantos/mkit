# frozen_string_literal: true

require 'spec_helper'
require 'support/in_memory_db'
require 'support/logger'
require 'mkit/app/model/service'
require 'mkit/app/model/mkit_job'

ActiveRecord::Schema.define do
  create_table :services, force: true do |t|
    t.string :name
    t.string :pods_network
  end
  create_table :pods, force: true do |t|
    t.string :name
    t.string :pod_id
    t.string :ip
    t.string :status
    t.integer :service_id
  end
end

describe Service do
  let(:service) { described_class.create!(name: 'web') }

  before do
    Pod.delete_all
    Service.delete_all
  end

  def resource(min)
    OpenStruct.new(min_replicas: min)
  end

  def create_saga(name)
    { topic: :create_pod_saga, data: { pod_name: name } }
  end

  describe '#start' do
    before do
      service.stubs(:create_pods_network)
      MkitJob.stubs(:publish)
    end

    it 'starts the pods that exist' do
      service.stubs(:resource).returns(resource(2))
      a = Pod.create!(name: 'a', service_id: service.id)
      b = Pod.create!(name: 'b', service_id: service.id)
      MkitJob.expects(:publish).with(topic: :start_pod, service_id: service.id, pod_id: a.id)
      MkitJob.expects(:publish).with(topic: :start_pod, service_id: service.id, pod_id: b.id)
      MkitJob.expects(:publish).with(has_entry(topic: :create_pod_saga)).never
      service.start
    end

    it 'creates the pods missing to reach min_replicas, without starting them twice' do
      service.stubs(:resource).returns(resource(3))
      existing = Pod.create!(name: 'a', service_id: service.id)
      MkitJob.expects(:publish).with(topic: :start_pod, service_id: service.id, pod_id: existing.id).once
      MkitJob.expects(:publish).with(has_entries(topic: :create_pod_saga)).twice
      service.start
      assert_equal 3, Pod.where(service_id: service.id).count
    end

    it 'recreates all the pods of a service that lost them' do
      service.stubs(:resource).returns(resource(2))
      MkitJob.expects(:publish).with(has_entries(topic: :create_pod_saga)).twice
      MkitJob.expects(:publish).with(has_entries(topic: :start_pod)).never
      service.start
      pods = Pod.where(service_id: service.id)
      assert_equal 2, pods.count
      assert(pods.all? { |p| p.status == MKIt::Status::CREATED && p.name.size == 12 })
      assert_equal 2, pods.map(&:name).uniq.size
    end

    it 'does not create pods above min_replicas' do
      service.stubs(:resource).returns(resource(1))
      Pod.create!(name: 'a', service_id: service.id)
      Pod.create!(name: 'b', service_id: service.id)
      MkitJob.expects(:publish).with(has_entries(topic: :create_pod_saga)).never
      service.start
      assert_equal 2, Pod.where(service_id: service.id).count
    end

    it 'makes sure the network exists before starting' do
      service.stubs(:resource).returns(resource(1))
      service.expects(:create_pods_network)
      service.start
    end

    it 'expects at least one pod when there is no resource section' do
      service.stubs(:resource).returns(nil)
      MkitJob.expects(:publish).with(has_entries(topic: :create_pod_saga)).once
      service.start
    end
  end

  describe '#spawn_pods' do
    it 'creates the pods and publishes the saga of each' do
      service.stubs(:resource).returns(resource(1))
      published = []
      MkitJob.stubs(:publish).with { |args| published << args[:data][:pod_name] }
      service.spawn_pods(2)
      assert_equal Pod.where(service_id: service.id).pluck(:name).sort, published.sort
    end

    it 'creates nothing for zero' do
      MkitJob.expects(:publish).never
      service.spawn_pods(0)
    end
  end
end
