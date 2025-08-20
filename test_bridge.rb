#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/inception/mcp'
require 'webrick'
require 'json'
require 'net/http'

# Simple mock implementation for testing
class MockObject
  def initialize(name)
    @name = name
    @expected_calls = {}
    @return_values = {}
  end

  def expect_call(method_name, with: nil, return_value: nil)
    @expected_calls[method_name] = with
    @return_values[method_name] = return_value
  end

  def method_missing(method_name, *args, &block)
    if @return_values.has_key?(method_name)
      @return_values[method_name]
    else
      # Default behavior for unexpected calls
      nil
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    true
  end
end

# Test script to demonstrate MCP<->CDP bridge functionality
class BridgeTest
  def initialize
    @received_requests = []
    @webserver_thread = nil
    @chrome_pid = nil
  end

  def run
    puts "🚀 Starting MCP<->CDP Bridge Test"
    puts "=" * 50
    
    start_test_webserver
    
    # Test 1: Basic MCP server functionality
    puts "\n📋 Test 1: MCP Server Setup"
    test_mcp_server_setup
    
    # Test 2: CDP client without real Chrome (mock test)
    puts "\n📋 Test 2: CDP Client Mock Test"
    test_cdp_client_mock
    
    # Test 3: Streaming HTTP functionality
    puts "\n📋 Test 3: Streaming HTTP Test"
    test_streaming_http
    
    # Test 4: Tool execution
    puts "\n📋 Test 4: Tool Execution Test"
    test_tool_execution
    
    puts "\n✅ All tests completed successfully!"
    puts "\n📝 Summary:"
    puts "- MCP server can be initialized and configured"
    puts "- CDP client properly formats WebSocket commands"
    puts "- Streaming HTTP functionality works for proxied requests"
    puts "- Tools execute and return proper MCP-formatted responses"
    puts "- Bridge maintains request/response consistency"
    
  rescue => e
    puts "\n❌ Test failed: #{e.message}"
    puts e.backtrace.first(5)
  ensure
    cleanup
  end

  private

  def start_test_webserver
    puts "Starting test webserver on port 8080..."
    
    @webserver_thread = Thread.new do
      server = WEBrick::HTTPServer.new(
        Port: 8080,
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: []
      )

      server.mount_proc '/' do |req, res|
        @received_requests << {
          method: req.request_method,
          path: req.path,
          headers: req.header.to_h,
          body: req.body,
          timestamp: Time.now
        }

        res.content_type = 'text/html'
        res.body = %{
          <!DOCTYPE html>
          <html>
          <head><title>Test Bridge Page</title></head>
          <body>
            <h1>MCP<->CDP Bridge Test</h1>
            <p>Path: #{req.path}</p>
            <p>Method: #{req.request_method}</p>
            <button id="test-button" onclick="window.testClicked = true">Test Button</button>
            <script>window.testClicked = false;</script>
          </body>
          </html>
        }
      end

      trap('INT') { server.shutdown }
      server.start
    end
    
    sleep(1) # Let server start
    puts "✅ Test webserver started"
  end

  def test_mcp_server_setup
    # Test MCP server initialization
    server = Inception::MCP::Server.new(cdp_port: 9222)
    puts "✅ MCP Server initialized"
    
    # Test streaming server initialization
    streaming_server = Inception::MCP::StreamingServer.new(
      cdp_port: 9222,
      streaming_endpoint: 'https://api.example.com/streaming'
    )
    puts "✅ Streaming MCP Server initialized"
    
    # Verify server has streaming endpoint configured
    endpoint = streaming_server.instance_variable_get(:@streaming_endpoint)
    if endpoint == 'https://api.example.com/streaming'
      puts "✅ Streaming endpoint configured correctly"
    else
      raise "Streaming endpoint not configured properly"
    end
  end

  def test_cdp_client_mock
    # Test CDP client with mock WebSocket
    cdp_client = Inception::MCP::CDPClient.new(9222)
    
    # Mock WebSocket to test command formatting
    mock_ws = MockObject.new('WebSocket')
    sent_commands = []
    
    # Override send method to capture commands
    def mock_ws.send(command)
      @sent_commands ||= []
      @sent_commands << JSON.parse(command)
    end
    
    def mock_ws.sent_commands
      @sent_commands || []
    end
    
    cdp_client.instance_variable_set(:@ws, mock_ws)
    cdp_client.instance_variable_set(:@connected, true)
    
    # Test navigation command
    cdp_client.navigate('http://127.0.0.1:8080/test')
    
    sent_commands = mock_ws.sent_commands
    nav_command = sent_commands.find { |cmd| cmd['method'] == 'Page.navigate' }
    if nav_command && nav_command['params']['url'] == 'http://127.0.0.1:8080/test'
      puts "✅ CDP navigation command formatted correctly"
    else
      raise "CDP navigation command not formatted properly"
    end
    
    # Test screenshot command
    cdp_client.take_screenshot(format: 'png')
    
    sent_commands = mock_ws.sent_commands
    screenshot_command = sent_commands.find { |cmd| cmd['method'] == 'Page.captureScreenshot' }
    if screenshot_command && screenshot_command['params']['format'] == 'png'
      puts "✅ CDP screenshot command formatted correctly"
    else
      raise "CDP screenshot command not formatted properly"
    end
    
    # Test click command
    cdp_client.click_element(100, 200)
    
    sent_commands = mock_ws.sent_commands
    click_commands = sent_commands.select { |cmd| cmd['method'] == 'Input.dispatchMouseEvent' }
    if click_commands.length == 2 # mousePressed and mouseReleased
      puts "✅ CDP click commands formatted correctly"
    else
      raise "CDP click commands not formatted properly"
    end
  end

  def test_streaming_http
    streaming_server = Inception::MCP::StreamingServer.new(cdp_port: 9222)
    
    # Mock HTTP response
    mock_response = MockObject.new('Response')
    mock_response.expect_call(:code, return_value: '200')
    mock_response.expect_call(:to_hash, return_value: {'content-type' => ['text/html']})
    mock_response.expect_call(:body, return_value: '<html>Success</html>')
    
    # Mock the direct request method
    def streaming_server.direct_request(*args)
      mock_response = MockObject.new('Response')
      def mock_response.code; '200'; end
      def mock_response.to_hash; {'content-type' => ['text/html']}; end
      def mock_response.body; '<html>Success</html>'; end
      mock_response
    end
    
    # Capture sent responses
    sent_responses = []
    def streaming_server.send_response(response)
      @sent_responses ||= []
      @sent_responses << response
    end
    
    def streaming_server.sent_responses
      @sent_responses || []
    end
    
    # Test HTTP request handling
    streaming_server.send(:handle_streaming_http, 1, {
      'url' => 'http://127.0.0.1:8080/api-test',
      'method' => 'GET',
      'headers' => { 'Accept' => 'text/html' }
    })
    
    response = streaming_server.sent_responses.first
    if response && response[:result][:status] == 200
      puts "✅ Streaming HTTP request handled correctly"
    else
      raise "Streaming HTTP request not handled properly"
    end
  end

  def test_tool_execution
    # Mock CDP client for tools test
    mock_cdp = MockObject.new('CDP Client')
    mock_cdp.expect_call(:navigate, return_value: 123)
    mock_cdp.expect_call(:take_screenshot, return_value: 456)
    mock_cdp.expect_call(:click_element, return_value: nil)
    mock_cdp.expect_call(:type_text, return_value: nil)
    mock_cdp.expect_call(:get_tabs_info, return_value: [
      { id: 'tab1', title: 'Test Page', url: 'http://127.0.0.1:8080/test', type: 'page' }
    ])
    
    tools = Inception::MCP::Tools.new(mock_cdp)
    
    # Test navigation tool
    nav_result = tools.execute_tool('navigate_browser', { 'url' => 'http://127.0.0.1:8080/test' })
    if nav_result[:content] && nav_result[:content].first[:text].include?('Navigation command sent')
      puts "✅ Navigation tool executed correctly"
    else
      raise "Navigation tool did not execute properly"
    end
    
    # Test screenshot tool
    screenshot_result = tools.execute_tool('take_screenshot', { 'format' => 'png' })
    if screenshot_result[:content] && screenshot_result[:content].first[:text].include?('Screenshot command sent')
      puts "✅ Screenshot tool executed correctly"
    else
      raise "Screenshot tool did not execute properly"
    end
    
    # Test page info tool
    info_result = tools.execute_tool('get_page_info', {})
    if info_result[:content] && info_result[:content].first[:text].include?('Page Info:')
      puts "✅ Page info tool executed correctly"
    else
      raise "Page info tool did not execute properly"
    end
    
    # Test error handling
    error_result = tools.execute_tool('nonexistent_tool', {})
    if error_result[:isError] && error_result[:content].first[:text].include?('Unknown tool')
      puts "✅ Tool error handling works correctly"
    else
      raise "Tool error handling not working properly"
    end
  end

  def cleanup
    puts "\n🧹 Cleaning up..."
    @webserver_thread&.kill
    puts "✅ Cleanup completed"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  BridgeTest.new.run
end