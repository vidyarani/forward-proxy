require 'webmock/rspec'
require_relative 'lib/http_forwarder'
require_relative 'lib/http_request'

class FakeClientSocket
  attr_reader :written

  def initialize
    @written = ''
    @closed = false
  end

  def write(data)
    @written << data
    data.length
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end
end

RSpec.describe HttpForwarder do
  let(:client_socket) { FakeClientSocket.new }
  let(:forwarder) { HttpForwarder.new }

  it 'forwards GET requests through Net::HTTP and writes the upstream response' do
    stub_request(:get, 'http://example.com/path')
      .with(headers: { 'X-Test' => 'value' })
      .to_return(status: 200, body: 'upstream-ok', headers: { 'Content-Type' => 'text/plain' })

    request = HttpRequest.parse('GET http://example.com/path HTTP/1.1')
    forwarder.handle(request, { 'Host' => 'example.com', 'X-Test' => 'value' }, client_socket)

    expect(client_socket.written).to include('HTTP/1.1 200 OK')
    expect(client_socket.written).to include('upstream-ok')
  end

  it 'forwards POST requests with body and preserves headers' do
    stub_request(:post, 'http://example.com/form')
      .with(body: 'payload', headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
      .to_return(status: 201, body: 'created')

    request = HttpRequest.parse('POST http://example.com/form HTTP/1.1')
    forwarder.handle(
      request,
      { 'Host' => 'example.com', 'Content-Type' => 'application/x-www-form-urlencoded' },
      client_socket,
      'payload'
    )

    expect(client_socket.written).to include('HTTP/1.1 201 Created')
    expect(client_socket.written).to include('created')
  end

  it 'appends the new header before sending the request to the upstream server' do
    stub_request(:get, 'http://example.com/path')
      .with(headers: { 'X-Test' => 'value', 'Test-Header' => 'test-value' })
      .to_return(status: 200, body: 'upstream-ok', headers: { 'Content-Type' => 'text/plain' })

    request = HttpRequest.parse('GET http://example.com/path HTTP/1.1')
    forwarder.handle(request, { 'Host' => 'example.com', 'X-Test' => 'value' }, client_socket)

    expect(client_socket.written).to include('HTTP/1.1 200 OK')
    expect(client_socket.written).to include('upstream-ok')
  end

  it 'does not forward proxy-specific or hop-by-hop headers to the upstream server' do
    stub_request(:get, 'http://example.com/path')
      .to_return(status: 200, body: 'upstream-ok', headers: { 'Content-Type' => 'text/plain' })

    request = HttpRequest.parse('GET http://example.com/path HTTP/1.1')
    forwarder.handle(
      request,
      {
        'Host' => 'example.com',
        'X-Test' => 'value',
        'Proxy-Connection' => 'Keep-Alive',
        'Connection' => 'Keep-Alive'
      },
      client_socket
    )

    expect(client_socket.written).to include('HTTP/1.1 200 OK')
    expect(client_socket.written).to include('upstream-ok')
    expect(
      a_request(:get, 'http://example.com/path')
        .with do |req|
          header_value = req.headers['Test-Header'] || req.headers['test-header']
          header_value == 'test-value' &&
            !req.headers.key?('proxy-connection') &&
            !req.headers.key?('connection')
        end
    ).to have_been_made.once
  end

  it 'removes transfer-encoding header when the body is already decoded' do
    stub_request(:get, 'http://example.com/path')
      .with(headers: { 'X-Test' => 'value', 'Test-Header' => 'test-value' })
      .to_return(status: 200, headers: { 'Content-Type' => 'text/plain', 'Transfer-Encoding' => 'chunked' }, body: 'upstream-ok')

    request = HttpRequest.parse('GET http://example.com/path HTTP/1.1')
    forwarder.handle(request, { 'Host' => 'example.com', 'X-Test' => 'value' }, client_socket)

    expect(client_socket.written).to include('HTTP/1.1 200 OK')
    expect(client_socket.written).to include('Content-Length: 11')
    expect(client_socket.written).not_to include('Transfer-Encoding: chunked')
  end
end
