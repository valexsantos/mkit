# frozen_string_literal: true

require 'spec_helper'
require 'support/in_memory_db'
require 'mkit/app/model/resource'

ActiveRecord::Schema.define do
  create_table :resources, force: true do |t|
    t.string :service_id
    t.integer :min_replicas, default: 1
    t.integer :max_replicas, default: 1
    t.string :cpu_limits
    t.string :memory_limits
    t.string :memory_swap_limits
  end
end

describe Resource do
  def build(yaml)
    described_class.create(yaml)
  end

  def invalid(yaml, message)
    err = assert_raises(MKIt::InvalidConfigurationException) { described_class.validate(yaml) }
    assert_match(/#{Regexp.escape(message)}/, err.message)
  end

  describe 'replicas' do
    it 'defaults to a single replica without a resources section' do
      r = build(nil)
      assert_equal [1, 1], [r.min_replicas, r.max_replicas]
    end

    it 'defaults max_replicas to min_replicas' do
      r = build('min_replicas' => 3)
      assert_equal [3, 3], [r.min_replicas, r.max_replicas]
    end

    it 'defaults min_replicas to 1' do
      r = build('max_replicas' => 4)
      assert_equal [1, 4], [r.min_replicas, r.max_replicas]
    end

    it 'rejects replicas lower than 1' do
      invalid({ 'min_replicas' => 0 }, 'min_replicas must be bigger or equal than 1')
      invalid({ 'max_replicas' => 0 }, 'max_replicas must be bigger or equal than 1')
    end

    it 'rejects min_replicas bigger than max_replicas' do
      invalid({ 'min_replicas' => 3, 'max_replicas' => 2 }, 'max_replicas must be bigger or equal than min_replicas')
    end
  end

  describe 'limits' do
    it 'reads cpu, memory and memory_swap' do
      r = build('limits' => { 'cpu' => '250m', 'memory' => '512m', 'memory_swap' => '1024m' })
      assert_equal %w[250m 512m 1024m], [r.cpu_limits, r.memory_limits, r.memory_swap_limits]
    end

    it 'has no limits by default' do
      r = build('min_replicas' => 1)
      assert_nil r.cpu_limits
      assert_nil r.memory_limits
      assert_nil r.memory_swap_limits
    end

    %w[cpu memory memory_swap].each do |name|
      ['250', '250M', 'm', 'abc5m', '5mb', '2.5m', '-5m', ' 5m', "5m\nx"].each do |value|
        it "rejects #{name}: #{value.inspect}" do
          invalid({ 'limits' => { name => value } }, "#{name} limits must match")
        end
      end

      it "rejects a numeric #{name}" do
        invalid({ 'limits' => { name => 500 } }, "#{name} limits must match")
      end
    end

    it 'accepts a single limit' do
      r = build('limits' => { 'memory' => '64m' })
      assert_equal '64m', r.memory_limits
      assert_nil r.cpu_limits
    end
  end
end
