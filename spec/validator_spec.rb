# frozen_string_literal: true

require_relative 'spec_helper'

describe MKIt::Validators::ServiceSchema do
  describe 'validate' do
    it 'passes valid service' do
      yaml = {
        'service' => {
          'name' => 'test',
          'image' => 'nginx:latest'
        }
      }
      errors = MKIt::Validators::ServiceSchema.validate(yaml)
      assert_empty errors
    end

    it 'fails missing name' do
      yaml = { 'service' => { 'image' => 'nginx' } }
      errors = MKIt::Validators::ServiceSchema.validate(yaml)
      assert_match(/name/, errors.join)
    end

    it 'fails missing image' do
      yaml = { 'service' => { 'name' => 'test' } }
      errors = MKIt::Validators::ServiceSchema.validate(yaml)
      assert_match(/image/, errors.join)
    end

    it 'validates resources' do
      yaml = {
        'service' => {
          'name' => 'test',
          'image' => 'nginx',
          'resources' => {
            'min_replicas' => -1
          }
        }
      }
      errors = MKIt::Validators::ServiceSchema.validate(yaml)
      assert_match(/minimum/, errors.join)
    end

    it 'validates probe types' do
      yaml = {
        'service' => {
          'name' => 'test',
          'image' => 'nginx',
          'liveness_probe' => {
            'type' => 'invalid'
          }
        }
      }
      errors = MKIt::Validators::ServiceSchema.validate(yaml)
      assert_match(/enum/, errors.join)
    end
  end

  describe 'validate_vault_refs' do
    it 'passes when no environment' do
      yaml = { 'service' => { 'name' => 'test', 'image' => 'nginx' } }
      errors = MKIt::Validators::ServiceSchema.validate_vault_refs(yaml)
      assert_empty errors
    end

    it 'passes plain text values' do
      yaml = {
        'service' => {
          'name' => 'test',
          'image' => 'nginx',
          'environment' => { 'DEBUG' => 'true' }
        }
      }
      errors = MKIt::Validators::ServiceSchema.validate_vault_refs(yaml)
      assert_empty errors
    end

    it 'validates existing vault reference' do
      VaultSecret.create!(
        scope: 'services',
        path: 'test/db',
        key: 'PASSWORD',
        value: 'secret'
      )

      yaml = {
        'service' => {
          'name' => 'test',
          'image' => 'nginx',
          'environment' => {
            'DB_PASSWORD' => 'vault:/services/test/db#PASSWORD'
          }
        }
      }
      errors = MKIt::Validators::ServiceSchema.validate_vault_refs(yaml)
      assert_empty errors
    end

    it 'fails missing vault reference' do
      yaml = {
        'service' => {
          'name' => 'test',
          'image' => 'nginx',
          'environment' => {
            'DB_PASSWORD' => 'vault:/services/test/db#PASSWORD'
          }
        }
      }
      errors = MKIt::Validators::ServiceSchema.validate_vault_refs(yaml)
      assert_equal 1, errors.size
      assert_match(/not found/, errors.first)
    end
  end
end
