# MCP Test Suite

This directory contains automated tests for the VICE MCP (Model Context Protocol) implementation.

## Overview

The MCP test suite validates the core functionality of the MCP server integration with VICE:

- Tool dispatch and error handling
- Input validation
- JSON response formatting
- Error code compliance with JSON-RPC 2.0
- Transport bind/auth policy regressions

## Building and Running Tests

### Prerequisites

- C compiler (gcc or clang)
- Make
- Configured VICE build tree with MCP enabled (`configure --enable-mcp-server`)
- libmicrohttpd development files discoverable by `pkg-config`, or set
  `LIBMICROHTTPD_CFLAGS` and `LIBMICROHTTPD_LIBS`

### Build Tests

```bash
cd /path/to/vice/src/mcp/tests
make
```

### Run Tests

```bash
make test
```

Expected output:
```
=== MCP Tools Test Suite ===

Running test: ping_tool_returns_valid_response ... PASS
...

=== Test Results ===
Tests run:    N
Tests passed: N
Tests failed: 0

SUCCESS: All tests passed
```

### Clean Build Artifacts

```bash
make clean
```

## Test Files

- **test_mcp_tools.c**: Unit tests for MCP tool dispatch and validation
- **vice_stubs.c**: Stub implementations of VICE dependencies for testing
- **Makefile**: Build configuration for test suite

## Adding New Tests

To add a new test:

1. Add a test function using the `TEST(name)` macro:
   ```c
   TEST(my_new_test)
   {
       /* Test code here */
       ASSERT_NOT_NULL(some_pointer);
       ASSERT_TRUE(some_condition);
   }
   ```

2. Register the test in `main()`:
   ```c
   RUN_TEST(my_new_test);
   ```

3. Rebuild and run:
   ```bash
   make clean
   make test
   ```

## Test Assertions

Available assertion macros:

- `ASSERT_NOT_NULL(ptr)` - Assert pointer is not NULL
- `ASSERT_TRUE(expr)` - Assert expression is true
- `ASSERT_STR_EQ(s1, s2)` - Assert strings are equal
- `ASSERT_INT_EQ(i1, i2)` - Assert integers are equal

## Limitations

These are unit tests that validate individual MCP components in isolation.
They do NOT test:

- Full VICE integration (requires running emulator)
- End-to-end HTTP request handling against a real emulator process
- Event streaming (`GET /events` currently returns `501 Not Implemented`)
- Actual CPU state manipulation
- Memory operations with real emulator

For integration testing, use manual testing with a running VICE instance:

```bash
# Terminal 1
x64sc -mcpserver -mcpserverhost 0.0.0.0

# Terminal 2
curl -sS http://127.0.0.1:6510/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"vice_ping","arguments":{}},"id":1}'
```

## Future Enhancements

Potential additions to the test suite:

1. **Memory operation tests**: Validate read/write with mock memory
2. **Register operation tests**: Test CPU register get/set with mocks
3. **Error response formatting**: Validate JSON-RPC error structures
4. **Integration tests**: Test against running VICE binary monitor
5. **Performance tests**: Measure tool dispatch overhead
6. **Fuzzing**: Test with malformed/malicious inputs

## Continuous Integration

To integrate with CI/CD:

```bash
# In your CI script
cd src/mcp/tests
make test
if [ $? -ne 0 ]; then
    echo "MCP tests failed"
    exit 1
fi
```

## License

See VICE README for license information.
