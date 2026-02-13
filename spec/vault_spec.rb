# frozen_string_literal: true

require_relative 'spec_helper'

describe VaultSecret do
  let(:vault_secret) do
    VaultSecret.create!(
      scope: 'services',
      path: 'my-app/database',
      key: 'PASSWORD',
      value: 'secret123'
    )
  end

  it 'creates a vault secret' do
    assert vault_secret.persisted?
    assert_equal 'services', vault_secret.scope
    assert_equal 'my-app/database', vault_secret.path
    assert_equal 'PASSWORD', vault_secret.key
  end

  it 'encrypts value on save' do
    vault_secret.reload
    refute_equal 'secret123', vault_secret.value
    assert_equal 'encrypted', vault_secret.ctype
  end

  it 'decrypts value correctly' do
    assert_equal 'secret123', vault_secret.decrypt_value
  end

  it 'resolves vault path correctly' do
    resolved = VaultSecret.resolve('vault:/services/my-app/database#PASSWORD')
    assert_equal 'secret123', resolved
  end

  it 'returns plain value if not vault path' do
    resolved = VaultSecret.resolve('plaintext')
    assert_equal 'plaintext', resolved
  end

  it 'returns nil for non-existent vault path' do
    resolved = VaultSecret.resolve('vault:/services/non-existent/key#KEY')
    assert_nil resolved
  end

  it 'validates vault path exists' do
    validation = VaultSecret.validate_path('vault:/services/my-app/database#PASSWORD')
    assert validation[:valid]
  end

  it 'validates missing vault path' do
    validation = VaultSecret.validate_path('vault:/services/non-existent#KEY')
    refute validation[:valid]
    assert_match(/not found/, validation[:error])
  end

  it 'validates invalid path format' do
    validation = VaultSecret.validate_path('vault:/invalid')
    refute validation[:valid]
  end

  it 'validates invalid scope' do
    validation = VaultSecret.validate_path('vault:/invalid/path#KEY')
    refute validation[:valid]
  end

  describe 'cluster secrets' do
    let(:cluster_secret) do
      VaultSecret.create!(
        scope: 'mkit',
        path: 'registry',
        key: 'TOKEN',
        value: 'cluster-token'
      )
    end

    it 'resolves mkit path correctly' do
      resolved = VaultSecret.resolve('vault:/mkit/registry#TOKEN')
      assert_equal 'cluster-token', resolved
    end
  end
end
