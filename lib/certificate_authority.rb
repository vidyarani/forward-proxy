require 'openssl'
require 'fileutils'

class CertificateAuthority
  class Error < StandardError; end

  attr_reader :ca_cert, :ca_key

  def initialize(ca_dir: nil)
    @ca_dir = ca_dir || File.expand_path('../certs', __dir__)
    @cert_cache = {}
    @serial_counter = 1
    load_ca
  end

  def certificate_for(hostname)
    return @cert_cache[hostname] if @cert_cache[hostname]

    cert_file = File.join(@ca_dir, "#{hostname}.crt")
    key_file = File.join(@ca_dir, "#{hostname}.key")

    if File.exist?(cert_file) && File.exist?(key_file)
      cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
      key = OpenSSL::PKey.read(File.read(key_file))
    else
      cert, key = generate_certificate_for(hostname)
      File.write(cert_file, cert.to_pem)
      File.write(key_file, key.to_pem)
    end

    @cert_cache[hostname] = [cert, key]
  end

  private

  def load_ca
    ca_cert_file = File.join(@ca_dir, 'ca.crt')
    ca_key_file = File.join(@ca_dir, 'ca.key')

    unless File.exist?(ca_cert_file) && File.exist?(ca_key_file)
      raise Error, "CA certificate not found in #{@ca_dir}. Run `bin/setup` first."
    end

    @ca_cert = OpenSSL::X509::Certificate.new(File.read(ca_cert_file))
    @ca_key = OpenSSL::PKey.read(File.read(ca_key_file))
  end

  def generate_certificate_for(hostname)
    key = OpenSSL::PKey::EC.generate('prime256v1')
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    @serial_counter += 1
    cert.serial = @serial_counter
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{hostname}")
    cert.issuer = @ca_cert.subject
    cert.public_key = key
    cert.not_before = Time.utc(2026, 1, 1)
    cert.not_after = Time.utc(2046, 1, 1)

    extension_factory = OpenSSL::X509::ExtensionFactory.new
    extension_factory.subject_certificate = cert
    extension_factory.issuer_certificate = @ca_cert
    [
      extension_factory.create_extension('subjectAltName', "DNS:#{hostname}", false),
      extension_factory.create_extension('keyUsage', 'digitalSignature', true),
      extension_factory.create_extension('extendedKeyUsage', 'serverAuth', false)
    ].each { |ext| cert.add_extension(ext) }

    cert.sign(@ca_key, OpenSSL::Digest.new('SHA256'))
    [cert, key]
  end
end
