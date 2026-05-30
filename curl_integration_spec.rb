require 'open3'
require 'webrick'
require 'webmock/rspec'
require_relative 'lib/forward_proxy'

RSpec.describe 'ForwardProxy curl integration' do
  around do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  it 'forwards a real curl request through the proxy to an upstream server' do
    upstream = WEBrick::HTTPServer.new(
      Port: 0,
      Logger: WEBrick::Log.new('/dev/null'),
      AccessLog: []
    )
    upstream_port = upstream.config[:Port]
    upstream.mount_proc '/hello' do |req, res|
      res.status = 200
      res.body = 'upstream-ok'
    end

    upstream_thread = Thread.new { upstream.start }
    proxy_port = 10001
    ForwardProxy.start(port: proxy_port)

    stdout, stderr, status = Open3.capture3(
      'curl',
      '-s',
      '-x', "http://127.0.0.1:#{proxy_port}",
      "http://127.0.0.1:#{upstream_port}/hello"
    )

    expect(status.exitstatus).to eq(0)
    expect(stdout.strip).to eq('upstream-ok')
  ensure
    ForwardProxy.stop
    upstream.shutdown if upstream
    upstream_thread.join if upstream_thread
  end
end
