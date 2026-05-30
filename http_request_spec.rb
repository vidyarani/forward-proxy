require_relative 'lib/http_request'

RSpec.describe HttpRequest do
  describe 'parsing a plain HTTP GET request line' do
    let(:request) { HttpRequest.parse('GET http://example.com/path/to/resource HTTP/1.1') }

    it 'extracts the method' do
      expect(request.method).to eq('GET')
    end

    it 'extracts the host' do
      expect(request.host).to eq('example.com')
    end

    it 'extracts the path' do
      expect(request.path).to eq('/path/to/resource')
    end

    it 'extracts the HTTP version' do
      expect(request.version).to eq('HTTP/1.1')
    end
  end

  describe 'default port handling for plain HTTP URIs' do
    let(:request) { HttpRequest.parse('GET http://example.com/path HTTP/1.1') }

    it 'defaults the port to 80' do
      expect(request.port).to eq(80)
    end
  end

  describe 'parsing a CONNECT request line' do
    let(:request) { HttpRequest.parse('CONNECT example.com:443 HTTP/1.1') }

    it 'extracts method as CONNECT' do
      expect(request.method).to eq('CONNECT')
    end

    it 'extracts the host without the port' do
      expect(request.host).to eq('example.com')
    end

    it 'extracts the port as an integer' do
      expect(request.port).to eq(443)
      expect(request.port).to be_a(Integer)
    end
  end

  describe 'value object immutability' do
    let(:request) { HttpRequest.parse('GET http://example.com/path HTTP/1.1') }

    it 'is frozen after parsing' do
      expect(request).to be_frozen
    end

    it 'does not allow mutation of attributes' do
      expect { request.instance_variable_set(:@host, 'changed.com') }.to raise_error(FrozenError)
    end
  end

  describe 'parsing a POST request line' do
    let(:request) { HttpRequest.parse('POST http://example.com/form HTTP/1.1') }

    it 'extracts method as POST' do
      expect(request.method).to eq('POST')
    end

    it 'extracts the path for POST requests' do
      expect(request.path).to eq('/form')
    end
  end
end
