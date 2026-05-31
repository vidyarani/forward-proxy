require 'openssl'
require 'tmpdir'
require_relative '../lib/certificate_authority'

RSpec.describe CertificateAuthority do
  subject(:ca) { described_class.new(ca_dir: ca_dir) }

  let(:ca_dir) { Dir.mktmpdir('ca_spec') }

  before do
    pre_seed_ca(ca_dir)
  end

  after do
    FileUtils.remove_entry(ca_dir) if ca_dir && Dir.exist?(ca_dir)
  end

  def pre_seed_ca(dir)
    key = OpenSSL::PKey::EC.generate('prime256v1')
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    subject = OpenSSL::X509::Name.parse('/CN=vidya proxy server')
    cert.subject = subject
    cert.issuer = subject
    cert.public_key = key
    cert.not_before = Time.utc(2026, 1, 1)
    cert.not_after = Time.utc(2046, 1, 1)

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    [
      ef.create_extension('basicConstraints', 'CA:TRUE', true),
      ef.create_extension('keyUsage', 'keyCertSign,cRLSign', true)
    ].each { |ext| cert.add_extension(ext) }

    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    File.write(File.join(dir, 'ca.key'), key.to_pem)
    File.write(File.join(dir, 'ca.crt'), cert.to_pem)
  end

  describe 'initialization' do
    it 'loads the CA certificate' do
      expect(ca.ca_cert).to be_a(OpenSSL::X509::Certificate)
    end

    it 'loads the CA key' do
      expect(ca.ca_key).to be_a(OpenSSL::PKey::EC)
    end

    it 'is a CA certificate (basicConstraints CA:TRUE)' do
      ext = ca.ca_cert.extensions.find { |e| e.oid == 'basicConstraints' }
      expect(ext).not_to be_nil
      expect(ext.value).to include('CA:TRUE')
    end

    it 'has subject equal to issuer (self-signed)' do
      expect(ca.ca_cert.subject.to_s).to eq(ca.ca_cert.issuer.to_s)
    end

    it 'raises an error when CA files are missing' do
      empty_dir = Dir.mktmpdir('empty_ca')
      expect do
        described_class.new(ca_dir: empty_dir)
      end.to raise_error(CertificateAuthority::Error, %r{Run `bin/setup`})
    ensure
      FileUtils.remove_entry(empty_dir) if empty_dir && Dir.exist?(empty_dir)
    end
  end

  describe '#certificate_for' do
    let(:hostname) { 'example.com' }

    it 'returns a certificate and key pair' do
      cert, key = ca.certificate_for(hostname)
      expect(cert).to be_a(OpenSSL::X509::Certificate)
      expect(key).to be_a(OpenSSL::PKey::EC)
    end

    it 'generates a certificate signed by the CA' do
      cert, _key = ca.certificate_for(hostname)
      expect(cert.verify(ca.ca_cert.public_key)).to be true
    end

    it 'sets the CN to the hostname' do
      cert, _key = ca.certificate_for(hostname)
      subject = cert.subject.to_a
      cn = subject.find { |entry| entry[0] == 'CN' }
      expect(cn[1]).to eq(hostname)
    end

    it 'sets the issuer to the CA subject' do
      cert, _key = ca.certificate_for(hostname)
      expect(cert.issuer.to_s).to eq(ca.ca_cert.subject.to_s)
    end

    it 'includes a SAN entry for the hostname' do
      cert, _key = ca.certificate_for(hostname)
      ext = cert.extensions.find { |e| e.oid == 'subjectAltName' }
      expect(ext).not_to be_nil
      expect(ext.value).to include("DNS:#{hostname}")
    end

    it 'caches the result in memory' do
      first_result = ca.certificate_for(hostname)
      second_result = ca.certificate_for(hostname)
      expect(second_result).to equal(first_result)
    end

    it 'writes the certificate and key to disk by domain name' do
      ca.certificate_for(hostname)
      expect(File).to exist(File.join(ca_dir, 'example.com.crt'))
      expect(File).to exist(File.join(ca_dir, 'example.com.key'))
    end

    it 'loads from disk on subsequent calls after cache miss' do
      ca.certificate_for(hostname)
      ca2 = described_class.new(ca_dir: ca_dir)
      cert, key = ca2.certificate_for(hostname)
      expect(cert).to be_a(OpenSSL::X509::Certificate)
      expect(key).to be_a(OpenSSL::PKey::EC)
    end

    it 'generates a different certificate for a different hostname' do
      cert1, = ca.certificate_for('alpha.example.com')
      cert2, = ca.certificate_for('beta.example.com')
      expect(cert1.serial).not_to eq(cert2.serial)
    end

    it 'sets keyUsage to digitalSignature' do
      cert, _key = ca.certificate_for(hostname)
      ext = cert.extensions.find { |e| e.oid == 'keyUsage' }
      expect(ext).not_to be_nil
      expect(ext.value.downcase).to include('digital signature')
    end

    it 'sets extendedKeyUsage to serverAuth' do
      cert, _key = ca.certificate_for(hostname)
      ext = cert.extensions.find { |e| e.oid == 'extendedKeyUsage' }
      expect(ext).not_to be_nil
      expect(ext.value.downcase).to include('server auth')
    end

    it 'uses fixed not_before and not_after dates' do
      cert, _key = ca.certificate_for(hostname)
      expect(cert.not_before).to eq(Time.utc(2026, 1, 1))
      expect(cert.not_after).to eq(Time.utc(2046, 1, 1))
    end
  end
end
