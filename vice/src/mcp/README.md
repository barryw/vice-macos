# VICE MCP Server

This directory contains the embedded Model Context Protocol (MCP) server for VICE, enabling AI assistants to control and inspect Commodore 8-bit emulations.

## Architecture

The MCP server is organized into three main components:

### 1. MCP Server Core (`mcp_server.c/h`)
- Initialization and lifecycle management
- VICE resource integration (MCPServerEnabled, MCPServerPort, MCPServerHost)
- Command-line options (-mcpserver, -mcpserverport, etc.)
- Configuration API

### 2. Transport Layer (`mcp_transport.c/h`)
- Streamable HTTP transport (`POST /mcp`)
- JSON-RPC 2.0 message handling
- Reserved Server-Sent Events endpoint (`GET /events`) that returns `501 Not Implemented`
- Default port: 6510 (chosen for 6510 CPU reference)

### 3. Tool Dispatch (`mcp_tools.c/h`)
- MCP tool registry and dispatch
- Tool implementations (execution control, memory, registers, etc.)
- Direct access to VICE internal state (zero-copy architecture)
- Tool responses for live emulator state

## Current Status

**Phase 1 - HTTP Transport Layer (COMPLETE)**
- ✅ Basic file structure created
- ✅ HTTP server integration (libmicrohttpd 1.0+)
- ✅ JSON library integration (cJSON bundled)
- ✅ VICE internal API integration
- ✅ JSON-RPC 2.0 endpoint (POST /mcp)
- ✅ Reserved Server-Sent Events endpoint (`GET /events`) returning `501 Not Implemented`
- ✅ Thread safety (pthread mutex)
- ✅ Security hardening (request limits, timeouts, CORS)
- ✅ Comprehensive test coverage

## Building

```bash
# Configure with MCP server support
./configure --enable-mcp-server

# Build VICE
make

# Run with MCP server enabled on 127.0.0.1:6510
x64sc -mcpserver
```

## Configuration

The MCP server can be configured via resources or command-line options:

**Resources:**
- `MCPServerEnabled` (0/1) - Enable/disable MCP server
- `MCPServerPort` (1024-65535) - Port to listen on (default: 6510)
- `MCPServerHost` (string) - Host to bind to (default: 127.0.0.1)
- `MCPServerToken` (string) - Optional bearer token. Required for CORS; strongly recommended for non-loopback binds.
- `MCPServerCORSOrigin` (string) - Optional exact CORS origin. Wildcards are rejected.

**Command-line:**
```bash
x64sc -mcpserver                  # Enable MCP server
x64sc +mcpserver                  # Disable MCP server
x64sc -mcpserverport 6510         # Set port
x64sc -mcpservertoken secret      # Require Authorization: Bearer secret
x64sc -mcpserverhost 0.0.0.0
x64sc -mcpserverhost 0.0.0.0 -mcpservertoken secret
x64sc -mcpservercorsorigin http://localhost:3000 -mcpservertoken secret
```

`MCPServerHost` is the address VICE binds to:

- `127.0.0.1` means same-machine clients only. This is the default.
- `0.0.0.0` means listen on every network interface.
- Clients do not connect to `0.0.0.0`. Same-machine clients use
  `http://127.0.0.1:6510/mcp`; remote clients use the host's real LAN IP, for
  example `http://192.168.1.42:6510/mcp`.

Token behavior:

- No token configured: requests do not need an `Authorization` header.
- Token configured: every request must include `Authorization: Bearer <token>`.
- CORS configured: a token is required.
- `0.0.0.0` without a token is allowed for backwards compatibility, but the
  transport logs a warning because remote clients can control the emulator.

Common setups:

| Use case | Start VICE with | Client URL | Auth header |
|---|---|---|---|
| Same machine | `x64sc -mcpserver` | `http://127.0.0.1:6510/mcp` | None |
| Same machine, custom port | `x64sc -mcpserver -mcpserverport 7000` | `http://127.0.0.1:7000/mcp` | None |
| LAN access | `x64sc -mcpserver -mcpserverhost 0.0.0.0` | `http://<host-ip>:6510/mcp` | None |
| LAN access with token | `x64sc -mcpserver -mcpserverhost 0.0.0.0 -mcpservertoken secret` | `http://<host-ip>:6510/mcp` | `Authorization: Bearer secret` |
| Browser client | `x64sc -mcpserver -mcpservercorsorigin http://localhost:3000 -mcpservertoken secret` | `http://127.0.0.1:6510/mcp` | `Authorization: Bearer secret` |

## HTTP Transport Layer

The MCP server exposes two HTTP endpoints:

### POST /mcp - JSON-RPC 2.0 Endpoint

Accepts JSON-RPC 2.0 requests and returns responses.

Every request must use `Content-Type: application/json`. Clients should also send
`Accept: application/json`.

VICE accepts direct JSON-RPC method calls:

```bash
curl -sS http://127.0.0.1:6510/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data '{
    "jsonrpc": "2.0",
    "method": "vice.ping",
    "id": 1
  }'
```

Standard MCP clients usually call tools through `tools/call`. The public tool
names returned by `tools/list` use underscores so clients that dislike dotted
names can call them safely:

```bash
curl -sS http://127.0.0.1:6510/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "vice_ping",
      "arguments": {}
    },
    "id": 2
  }'
```

If `MCPServerToken` is configured, add the bearer header to every request:

```bash
curl -sS http://127.0.0.1:6510/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer secret" \
  --data '{"jsonrpc":"2.0","method":"vice.ping","id":3}'
```

**Example Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "ok",
    "version": "3.10",
    "machine": "C64"
  },
  "id": 1
}
```

**Error Response:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32601,
    "message": "Method not found"
  },
  "id": 1
}
```

### GET /events - Server-Sent Events (SSE)

SSE is not implemented in this transport. The endpoint returns `501 Not Implemented`
until it can stream real events instead of pretending to work.

### Transport Configuration

- **Maximum request size:** 10MB
- **Connection limit:** 100 concurrent connections
- **Connection timeout:** 30 seconds
- **CORS:** Disabled by default. Enable only with `MCPServerCORSOrigin` and `MCPServerToken`.

## Security

- **Default binding:** localhost-only (127.0.0.1)
- **Remote access:** Requires explicit configuration with `-mcpserverhost`. Use `MCPServerToken` unless the network is already trusted.
- **Authentication:** Optional on loopback, recommended for non-loopback binds, required for CORS
- **CORS:** Disabled by default; only one exact origin can be allowed
- **Port range:** Restricted to 1024-65535 (no privileged ports)
- **DoS protection:** Request size limits, connection limits, timeouts
- **Input validation:** Content-Type validation, JSON parsing errors
- **Memory safety:** Integer overflow protection, null checks
- **Thread safety:** Mutex-protected shared state

**Security Warnings:**
- No HTTPS support - terminate TLS at reverse proxy level for remote access
- Command-line tokens may be visible to local process-list tools. Prefer resource files or a wrapper when that matters.
- Binding to `0.0.0.0` exposes emulator control to the network. This is useful
  for remote agents and CI machines, but it is not a browser sandbox or a public
  API boundary.

**Recommended Production Setup:**
```nginx
# nginx reverse proxy with authentication
location /mcp {
    proxy_pass http://127.0.0.1:6510;
    auth_basic "VICE MCP Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

## Available MCP Tools

### Phase 1 (Basic Control)
- `vice.ping` - Check if VICE is responding
- `vice.execution.run` - Resume execution
- `vice.execution.pause` - Pause execution
- `vice.execution.step` - Step instructions
- `vice.registers.get` - Get CPU registers
- `vice.registers.set` - Set register values
- `vice.memory.read` - Read memory
- `vice.memory.write` - Write memory

### Future Phases
See `/docs/plans/2026-02-02-vice-mcp-server-design.md` for complete roadmap.

## Testing

### Unit Tests

Run automated unit tests:
```bash
cd vice/src/mcp/tests
make test
```

Tests include:
- **test_mcp_tools.c**: Tool dispatch, validation, transport regressions, and
  bind/auth policy coverage

The transport regression tests cover both sides of the bind/auth policy:

- `0.0.0.0` without a token starts successfully.
- CORS without a token is rejected.

### Integration Tests

Test HTTP transport with running VICE:
```bash
# Terminal 1: Start VICE with MCP server
x64sc -mcpserver -mcpserverhost 0.0.0.0

# Terminal 2: Hit the live MCP endpoint
curl -sS http://127.0.0.1:6510/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"vice_ping","arguments":{}},"id":1}'
```

See `tests/README.md` for detailed testing documentation.

## Design Documentation

Full design documentation is available at:
`/docs/plans/2026-02-02-vice-mcp-server-design.md`

## Contributing

This implementation follows VICE coding guidelines. See:
- `vice/doc/coding-guidelines.txt`
- `vice/doc/Documentation-Howto.txt`

## License

This code is part of VICE and follows the same GPL v2+ license.
