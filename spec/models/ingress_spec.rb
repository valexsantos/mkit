# frozen_string_literal: true

require 'spec_helper'
require 'support/in_memory_db'
require 'mkit/app/model/ingress'

describe Ingress do
  def valid_yaml
    {
      'frontend' => [
        { 'name' => 'http-in', 'bind' => { 'port' => 80, 'mode' => 'http' }, 'default_backend' => 'web' },
        { 'name' => 'tcp-in', 'bind' => { 'port' => 5672, 'mode' => 'tcp' }, 'default_backend' => 'srv' }
      ],
      'backend' => [
        { 'name' => 'web', 'bind' => { 'port' => 8080, 'mode' => 'http' } },
        { 'name' => 'srv', 'balance' => 'least_conn', 'bind' => { 'port' => 5672, 'mode' => 'tcp' } }
      ]
    }
  end

  def invalid(yaml, message)
    err = assert_raises(MKIt::InvalidConfigurationException) { described_class.validate(yaml) }
    assert_match(/#{Regexp.escape(message)}/, err.message)
  end

  it 'accepts a valid configuration with integer ports' do
    assert described_class.validate(valid_yaml)
  end

  it 'accepts string ports' do
    y = valid_yaml
    y['frontend'][0]['bind']['port'] = '80'
    assert described_class.validate(y)
  end

  it 'requires the section, a frontend and a backend' do
    invalid(nil, 'Ingress section is mandatory')
    invalid(valid_yaml.reject { |k, _| k == 'frontend' }, 'At least one frontend is mandatory')
    invalid(valid_yaml.reject { |k, _| k == 'backend' }, 'At least one backend is mandatory')
  end

  it 'requires unique frontend names and ports' do
    y = valid_yaml
    y['frontend'][1]['name'] = 'http-in'
    invalid(y, "Frontend name 'http-in' must be unique")
    y = valid_yaml
    y['frontend'][1]['bind']['port'] = 80
    invalid(y, "Frontend port '80' must be unique")
  end

  it 'requires unique backend names' do
    y = valid_yaml
    y['backend'][1]['name'] = 'web'
    y['frontend'][1]['default_backend'] = 'web'
    invalid(y, "Backend name 'web' must be unique")
  end

  it 'requires bind and mode in the frontend' do
    y = valid_yaml
    y['frontend'][0].delete('bind')
    invalid(y, 'Frontend bind and mode are mandatory')
  end

  it 'requires default_backend to point to a backend' do
    y = valid_yaml
    y['frontend'][0]['default_backend'] = 'nope'
    invalid(y, "default_backend 'nope' must point to a valid backend name")
  end

  it 'requires every backend to be used by a frontend' do
    y = valid_yaml
    y['backend'] << { 'name' => 'unused', 'bind' => { 'port' => 1, 'mode' => 'tcp' } }
    invalid(y, "Backend 'unused' must be referenced by at least one frontend default_backend")
  end

  describe 'frontend port range' do
    it 'accepts a backend without port' do
      y = valid_yaml
      y['frontend'][0]['bind']['port'] = '8000-8080'
      y['backend'][0]['bind'].delete('port')
      assert described_class.validate(y)
    end

    it 'rejects a backend with port' do
      y = valid_yaml
      y['frontend'][0]['bind']['port'] = '8000-8080'
      invalid(y, "Frontend port range '8000-8080' must have an empty backend port")
    end
  end
end

describe Backend do
  it 'validates mode and balance' do
    assert_raises(MKIt::InvalidConfigurationException) do
      described_class.validate('name' => 'b', 'bind' => { 'mode' => 'udp' })
    end
    assert_raises(MKIt::InvalidConfigurationException) do
      described_class.validate('name' => 'b', 'balance' => 'random', 'bind' => { 'mode' => 'tcp' })
    end
    described_class.validate('name' => 'b', 'balance' => 'least_conn', 'bind' => { 'mode' => 'tcp' }) # does not raise
  end
end
