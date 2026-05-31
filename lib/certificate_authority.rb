require 'openssl'
require 'fileutils'

class CertificateAuthority
  attr_reader :ca_cert, :ca_key

  def initialize(ca_dir: '/tmp/forward_proxy_ca')
    @ca_dir = ca_dir
    @cert_cache = {}
    load_or_create_ca
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

  def load_or_create_ca
    FileUtils.mkdir_p(@ca_dir)

    ca_cert_file = File.join(@ca_dir, 'ca.crt')
    ca_key_file = File.join(@ca_dir, 'ca.key')

    if File.exist?(ca_cert_file) && File.exist?(ca_key_file)
      @ca_cert = OpenSSL::X509::Certificate.new(File.read(ca_cert_file))
      @ca_key = OpenSSL::PKey.read(File.read(ca_key_file))
    else
      @ca_key = OpenSSL::PKey::EC.generate('prime256v1')
      @ca_cert = create_ca_certificate(@ca_key)
      File.write(ca_cert_file, @ca_cert.to_pem)
      File.write(ca_key_file, @ca_key.to_pem)
    end
  end

  def create_ca_certificate(key)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse('/C=US/O=ForwardProxy/CN=ForwardProxy-CA')
    cert.issuer = cert.subject
    cert.public_key = key
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 3600

    extension_factory = OpenSSL::X509::ExtensionFactory.new
    extension_factory.subject_certificate = cert
    extension_factory.issuer_certificate = cert
    [
      extension_factory.create_extension('basicConstraints', 'CA:TRUE', true),
      extension_factory.create_extension('keyUsage', 'keyCertSign,cRLSign', true)
    ].each { |ext| cert.add_extension(ext) }

    cert.sign(key, OpenSSL::Digest::SHA256.new)
    cert
  end

  def generate_certificate_for(hostname)
    key = OpenSSL::PKey::EC.generate('prime256v1')
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = OpenSSL::BN.rand(64)
    cert.subject = OpenSSL::X509::Name.parse("/C=US/O=ForwardProxy/CN=#{hostname}")
    cert.issuer = @ca_cert.subject
    cert.public_key = key
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 3600

    extension_factory = OpenSSL::X509::ExtensionFactory.new
    extension_factory.subject_certificate = cert
    extension_factory.issuer_certificate = @ca_cert
    [
      extension_factory.create_extension('subjectAltName', "DNS:#{hostname}", false),
      extension_factory.create_extension('keyUsage', 'digitalSignature', true),
      extension_factory.create_extension('extendedKeyUsage', 'serverAuth', false)
    ].each { |ext| cert.add_extension(ext) }

    cert.sign(@ca_key, OpenSSL::Digest::SHA256.new)
    [cert, key]
  end
end

