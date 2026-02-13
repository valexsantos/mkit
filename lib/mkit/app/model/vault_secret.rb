# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'digest'

class VaultSecret < ActiveRecord::Base
  validates :scope, presence: true
  validates :path, presence: true
  validates :key, presence: true
  validates :scope, inclusion: { in: %w[services mkit] }

  before_save :encrypt_value

  def self.encryption_key
    @encryption_key ||= ENV.fetch('MKIT_VAULT_KEY') { 'default-vault-key-change-in-prod' }
  end

  def self.resolve(value)
    return value unless value.to_s.start_with?('vault://')

    parse_vault_path(value)
  end

  def self.parse_vault_path(vault_path)
    path = vault_path.sub('vault://', '')
    parts = path.split('#')
    return nil if parts.length != 2

    full_path = parts[0]
    key = parts[1]

    scope, resource_path = if full_path.start_with?('services/')
                             ['services', full_path.sub('services/', '')]
                           elsif full_path.start_with?('mkit/')
                             ['mkit', full_path.sub('mkit/', '')]
                           else
                             return nil
                           end

    secret = VaultSecret.find_by(scope: scope, path: resource_path, key: key)
    return nil unless secret

    secret.decrypt_value
  end

  def self.validate_path(vault_path)
    return { valid: true, parsed: nil } unless vault_path.to_s.start_with?('vault://')

    path = vault_path.sub('vault://', '')
    parts = path.split('#')
    if parts.length != 2
      return { valid: false,
               error: "Invalid vault path format: #{vault_path}. Expected vault:/<scope>/<path>#<key>" }
    end

    full_path = parts[0]
    key = parts[1]

    unless full_path.start_with?('services/') || full_path.start_with?('mkit/')
      return { valid: false, error: "Invalid vault path: #{vault_path}. Must start with services/ or mkit/" }
    end

    scope = full_path.start_with?('services/') ? 'services' : 'mkit'
    resource_path = full_path.sub("#{scope}/", '')

    secret = VaultSecret.find_by(scope: scope, path: resource_path, key: key)
    return { valid: false, error: "Vault secret not found: #{vault_path}" } unless secret

    { valid: true, parsed: { scope: scope, path: resource_path, key: key } }
  end

  def decrypt_value
    return @decrypted_value if @decrypted_value

    return value unless encrypted?

    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.decrypt
    cipher.key = Digest::SHA256.digest(self.class.encryption_key)
    cipher.iv = Base64.decode64(encrypted_iv) if encrypted_iv

    decrypted = cipher.update(Base64.decode64(value)) + cipher.final
    @decrypted_value = decrypted.force_encoding('UTF-8')
  end

  private

  def encrypt_value
    return if value.nil? || value.empty?

    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = Digest::SHA256.digest(self.class.encryption_key)
    iv = cipher.random_iv
    cipher.iv = iv

    encrypted = cipher.update(value) + cipher.final
    self.value = Base64.encode64(encrypted).gsub("\n", '')
    self.encrypted_iv = Base64.encode64(iv).gsub("\n", '')
    self.ctype = 'encrypted'
  end

  def encrypted?
    ctype == 'encrypted'
  end
end
