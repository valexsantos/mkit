require 'mkit/ctypes'
require 'mkit/app/model/vault_secret'

class ServiceConfig < ActiveRecord::Base
  belongs_to :service

  def self.create(service:, key:, value:, ctype: MKIt::CType::ENVIRONMENT)
    ServiceConfig.new(
      service: service,
      key: key,
      value: value,
      version: service.version,
      ctype: ctype
    )
  end

  def resolved_value
    VaultSecret.resolve(value)
  end
end
