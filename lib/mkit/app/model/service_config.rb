require 'mkit/ctypes'

class ServiceConfig < ActiveRecord::Base
  belongs_to :service

  def self.create(service:, key:, value:, ctype: MKIt::CType::ENVIRONMENT)
    ServiceConfig.new(
      service: service,
      key: key,
      value: !value.nil? && (value.is_a?(TrueClass) || value.is_a?(FalseClass)) ? String(value) : value,
      version: service.version,
      ctype: ctype
    )
  end
end

