#!/usr/bin/env ruby
require_relative 'lib/forward_proxy'

port = (ARGV[0] || ENV['PORT'] || ForwardProxy::DEFAULT_PORT).to_i
ForwardProxy.start(port: port)

trap('INT') do
  puts "\nShutting down forward proxy on port #{ForwardProxy.port}"
  ForwardProxy.stop
  exit
end

puts "Forward proxy listening on 127.0.0.1:#{ForwardProxy.port}"
sleep
