# Inception MCP

🔌 **CDP-MCP Gateway** - Connect AI assistants to Inception-controlled Chrome browsers

## Quick Start

```bash
# Terminal 1: Start incepti0n browser
incepti0n serve --show-cdp

# Terminal 2: Start MCP server  
inception-mcp --port 9222

# Add to Claude Desktop config:
{
  "mcpServers": {
    "inception-browser": {
      "command": "inception-mcp",
      "args": ["--port", "9222"]
    }
  }
}
```

## Help & Usage

Both executables include comprehensive help:

```bash
# Show detailed help
inception-mcp --help
inception-mcp-streaming --help

# Show version
inception-mcp --version

# Show basic usage options
inception-mcp --usage
```

## What It Does

Enables AI assistants (Claude, etc.) to control browsers managed by [incepti0n](https://github.com/usiegj00/inception) via Chrome DevTools Protocol.

**Available Tools:**
- `navigate_browser` - Go to URLs
- `take_screenshot` - Capture pages
- `click_element` - Click coordinates
- `type_text` - Enter text
- `press_key` - Keyboard input
- `get_page_content` - Extract HTML
- `get_page_info` - Page details

## Architecture

```
Claude Desktop ←→ inception-mcp ←→ Chrome Browser ←→ Web UI
   (MCP Protocol)     (CDP WebSocket)     (incepti0n)
```

**Key Benefits:**
- ✅ Shared control (AI + human monitoring)
- ✅ Real-time synchronization  
- ✅ Standards-based (MCP + CDP)
- ✅ Minimal setup

## Installation

```bash
gem install inception-mcp
```

## Testing

Run the test suite:

```bash
# Unit tests
bundle exec rspec spec/unit/

# Integration tests (requires Chrome/Chromium)
bundle exec rspec spec/integration/

# Run the bridge test demonstration
ruby test_bridge.rb
```

## Streaming HTTP Support

The bridge now includes support for fast-mcp streaming HTTP capabilities:

```bash
# Start with streaming endpoint
inception-mcp-streaming --port 9222 --streaming https://api.example.com/streaming

# Add to Claude Desktop config:
{
  "mcpServers": {
    "inception-browser": {
      "command": "inception-mcp-streaming",
      "args": ["--port", "9222", "--streaming", "https://api.example.com/streaming"]
    }
  }
}
```

**Additional Tools with Streaming:**
- `streaming_http_request` - Make HTTP requests through fast-mcp streaming endpoint

## License

MIT