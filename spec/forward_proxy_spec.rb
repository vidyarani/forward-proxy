require 'socket'
require_relative '../lib/forward_proxy'

RSpec.describe 'ForwardProxy (TCP listen)' do
  after { ForwardProxy.stop }

  it 'uses the default port 10000 when started without arguments' do
    ForwardProxy.start
    expect(ForwardProxy.port).to eq(10_000)
  end

  it 'allows a TCPSocket client to connect' do
    ForwardProxy.start
    socket = TCPSocket.new('127.0.0.1', ForwardProxy.port)
    expect(socket).to be_a(TCPSocket)
    socket.close
  end

  it 'keeps the connected socket open until the client closes it' do
    ForwardProxy.start
    socket = TCPSocket.new('127.0.0.1', ForwardProxy.port)
    expect(socket.closed?).to be false
    socket.close
  end

  it 'accepts multiple sequential connections' do
    ForwardProxy.start

    socket1 = TCPSocket.new('127.0.0.1', ForwardProxy.port)
    expect(socket1.closed?).to be false
    socket1.close

    socket2 = TCPSocket.new('127.0.0.1', ForwardProxy.port)
    expect(socket2.closed?).to be false
    socket2.close
  end

  it 'closes the port after stop' do
    ForwardProxy.start
    port = ForwardProxy.port
    ForwardProxy.stop

    expect do
      TCPSocket.new('127.0.0.1', port)
    end.to raise_error(Errno::ECONNREFUSED)
  end

  it 'does not raise when stop is called twice' do
    ForwardProxy.start
    ForwardProxy.stop

    expect { ForwardProxy.stop }.not_to raise_error
  end

  it 'stays running after repeated start attempts' do
    ForwardProxy.start
    ForwardProxy.start

    socket = TCPSocket.new('127.0.0.1', ForwardProxy.port)
    expect(socket.closed?).to be false
    socket.close
  end
end
