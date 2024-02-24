require 'openssl'

module MKIt
  class EasySSL
    def self.create_self_certificate(cert_dir)
      unless File.exist?("#{cert_dir}/#{MKIt::Utils::MKIT_CRT}")
        key = OpenSSL::PKey::RSA.new 4096
        name = OpenSSL::X509::Name.parse '/CN=MKIt/DC=server'
        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.serial = 0
        cert.not_before = Time.now
        cert.not_after = Time.now + 20 * 365 * 24 * 60 * 60
        cert.public_key = key.public_key
        cert.subject = name
        cert.issuer = name
        cert.sign key, OpenSSL::Digest.new('SHA256')
        # my cert and key files
        open "#{cert_dir}/#{MKIt::Utils::MKIT_CRT}", 'w' do |io| io.write cert.to_pem end
        open "#{cert_dir}/#{MKIt::Utils::MKIT_KEY}", 'w' do |io| io.write key.to_pem end
        # haproxy default ssl cert
        open "#{cert_dir}/#{MKIt::Utils::MKIT_PEM}", 'w' do |io| io.write cert.to_pem end
        open "#{cert_dir}/#{MKIt::Utils::MKIT_PEM}", 'a' do |io| io.write key.to_pem end
      end
    end
  end
end

