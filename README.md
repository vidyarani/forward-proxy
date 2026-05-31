# Forward Proxy

A forward proxy server written in Ruby. Supports HTTP forwarding, CONNECT tunnelling, and MITM TLS interception.

## Requirements

- Ruby 3.x (see `.ruby-version`)
- Bundler

## Quick Start

```bash
git clone <repo>
cd forward-proxy

# Install dependencies and create state directories
bin/setup

# Start the proxy in the foreground (default port 10000)
bin/forward-proxy

# Or start as a daemon in the background
bin/forward-proxy start

# Check status
bin/forward-proxy status

# Stop the daemon
bin/forward-proxy stop
```

## CLI Reference

```
Usage: forward-proxy [subcommand] [options]

Subcommands:
  run                  Run in foreground (default)
  start                Start as a daemon (background)
  stop                 Stop the daemon
  status               Check if daemon is running
  restart              Restart the daemon

Options:
  -p, --port PORT      Port to listen on (default: 10000)
  -b, --bind ADDR      Address to bind to (default: 127.0.0.1)
  -m, --mitm           Enable MITM TLS interception
  --verify-origin      Verify origin TLS certificates in MITM mode
  -h, --help           Show help
```

Environment variable `PORT` is also respected as a default port value.

## Usage

### curl

```bash
# Standard HTTP
curl -x http://127.0.0.1:10000 http://example.com

# HTTPS via CONNECT tunnel
curl -x http://127.0.0.1:10000 https://example.com
```

### Browser

Configure your browser's proxy settings to `127.0.0.1:10000` with HTTP protocol.

## MITM Mode

MITM (Man-In-The-Middle) mode decrypts HTTPS traffic for inspection:

```bash
bin/forward-proxy --mitm
```

The proxy generates a self-signed Certificate Authority on first run (cached in `/tmp/forward_proxy_ca/`). To avoid certificate warnings:

1. Trust the CA certificate at `/tmp/forward_proxy_ca/ca.crt` in your system/browser
2. The proxy generates per-host certificates signed by this CA

An injected `X-Powered-By: Vidya Proxy` header is added to every forwarded upstream request for observability.

## Daemon Management

The daemon PID is stored at `~/.local/state/forward-proxy/forward-proxy.pid` (XDG Base Directory compliant).

```bash
bin/forward-proxy start -p 8080
bin/forward-proxy status
bin/forward-proxy stop
bin/forward-proxy restart
```

## Rake Tasks

```bash
rake setup              # Install deps, create state/cert directories
rake spec               # Run all tests
rake spec:unit          # Run unit tests only
rake spec:integration   # Run integration tests (requires curl)
rake server             # Start proxy in foreground
rake start              # Start proxy as daemon
rake stop               # Stop daemon
rake status             # Check daemon status
rake restart            # Restart daemon
rake console            # Open IRB with library loaded
rake lint               # Run RuboCop (if installed)
```

## Running Tests

```bash
# All tests
bundle exec rake spec

# Or directly
bundle exec rspec

# Single spec file
bundle exec rspec spec/http_request_spec.rb
```

## Architecture

```
bin/forward-proxy          CLI entrypoint with subcommands
lib/
├── forward_proxy.rb       Core server (TCPServer, accept loop)
├── request_router.rb      Reads HTTP request line + headers, dispatches
├── http_request.rb        HTTP request value object (parsing)
├── http_forwarder.rb      Forwards GET/POST/etc. via Net::HTTP
├── tunnel_handler.rb      Standard CONNECT tunnel (TCP pipe)
├── mitm_tunnel_handler.rb MITM CONNECT tunnel (TLS interception)
├── certificate_authority.rb Dynamic CA + per-host cert generation
└── pid_manager.rb         PID file management for daemon mode
```

## Virtual Environment

The project uses Bundler for gem isolation. The recommended setup:

- **rbenv** (or chruby) for Ruby version management (`.ruby-version` is provided)
- `bundle exec` for running commands with the locked gem set
- `bin/setup` for first-time setup

Optionally use **direnv** to automatically load environment variables.
