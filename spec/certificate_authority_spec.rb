require 'openssl'
require 'tmpdir'
require_relative '../lib/certificate_authority'

RSpec.describe CertificateAuthority do
  subject(:ca) { described_class.new(ca_dir: ca_dir) }

  let(:ca_dir) { Dir.mktmpdir('ca_spec') }

  after do
    FileUtils.remove_entry(ca_dir) if ca_dir && Dir.exist?(ca_dir)
  end

  describe 'initialization' do
    it 'creates a CA certificate' do
      expect(ca.ca_cert).to be_a(OpenSSL::X509::Certificate)
    end

    it 'creates a CA key' do
      expect(ca.ca_key).to be_a(OpenSSL::PKey::EC)
    end

    it 'writes the CA certificate to disk' do
      ca
      expect(File).to exist(File.join(ca_dir, 'ca.crt'))
    end

    it 'writes the CA key to disk' do
      ca
      expect(File).to exist(File.join(ca_dir, 'ca.key'))
    end

    it 'is a CA certificate (basicConstraints CA:TRUE)' do
      cert = ca.ca_cert
      ext = cert.extensions.find { |e| e.oid == 'basicConstraints' }
      expect(ext).not_to be_nil
      expect(ext.value).to include('CA:TRUE')
    end

    it 'has subject equal to issuer (self-signed)' do
      expect(ca.ca_cert.subject.to_s).to eq(ca.ca_cert.issuer.to_s)
    end

    it 'loads existing CA from disk on second initialization' do
      first = described_class.new(ca_dir: ca_dir)
      original_serial = first.ca_cert.serial
      second = described_class.new(ca_dir: ca_dir)
      expect(second.ca_cert.serial).to eq(original_serial)
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
      expect do
        cert.verify(ca.ca_cert.public_key)
      end.not_to raise_error
    end

    it 'sets the CN to the hostname' do
      cert, _key = ca.certificate_for(hostname)
      subject = cert.subject.to_a
      cn = subject.find { |entry| entry[0] == 'CN' }
      expect(cn[1]).to eq(hostname)
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

    it 'writes the certificate and key to disk' do
      ca.certificate_for(hostname)
      expect(File).to exist(File.join(ca_dir, "#{hostname}.crt"))
      expect(File).to exist(File.join(ca_dir, "#{hostname}.key"))
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
  end
end
