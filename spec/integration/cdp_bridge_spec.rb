# frozen_string_literal: true

require 'spec_helper'
require 'webrick'
require 'open3'
require 'json'
require 'net/http'
require 'uri'
require 'websocket-client-simple'

RSpec.describe 'CDP Bridge Integration' do
  let(:chrome_port) { 9222 }
  let(:webserver_port) { 8080 }
  let(:chrome_pid) { nil }
  let(:webserver_pid) { nil }
  let(:received_requests) { [] }

  before(:all) do
    @received_requests = []
    @webserver_thread = start_test_webserver
    @chrome_pid = start_headless_chrome
    sleep 2 # Allow services to start
  end

  after(:all) do
    stop_headless_chrome(@chrome_pid) if @chrome_pid
    @webserver_thread&.kill
  end

  describe 'Direct CDP Control' do
    it 'can connect to headless Chrome and control browser' do
      # Get available tabs
      tabs_response = Net::HTTP.get_response(URI("http://127.0.0.1:#{chrome_port}/json/list"))
      expect(tabs_response.code).to eq('200')
      
      tabs = JSON.parse(tabs_response.body)
      expect(tabs).not_to be_empty
      
      tab = tabs.first
      ws_url = tab['webSocketDebuggerUrl']
      expect(ws_url).not_to be_nil

      # Connect via WebSocket
      ws = WebSocket::Client::Simple.connect(ws_url)
      connected = false
      responses = []

      ws.on :open do
        connected = true
      end

      ws.on :message do |msg|
        responses << JSON.parse(msg.data)
      end

      # Wait for connection
      timeout = 5
      start_time = Time.now
      while !connected && (Time.now - start_time) < timeout
        sleep(0.1)
      end
      
      expect(connected).to be true

      # Enable Page domain
      ws.send({
        id: 1,
        method: 'Page.enable'
      }.to_json)

      # Navigate to test server
      ws.send({
        id: 2,
        method: 'Page.navigate',
        params: { url: "http://127.0.0.1:#{webserver_port}/test" }
      }.to_json)

      # Wait for responses
      sleep(2)
      
      # Verify navigation response
      nav_response = responses.find { |r| r['id'] == 2 }
      expect(nav_response).not_to be_nil
      expect(nav_response['result']).to have_key('frameId')

      # Verify webserver received the request
      expect(@received_requests.any? { |req| req[:path] == '/test' }).to be true

      ws.close
    end

    it 'can take screenshots via CDP' do
      tabs_response = Net::HTTP.get_response(URI("http://127.0.0.1:#{chrome_port}/json/list"))
      tabs = JSON.parse(tabs_response.body)
      tab = tabs.first
      ws_url = tab['webSocketDebuggerUrl']

      ws = WebSocket::Client::Simple.connect(ws_url)
      connected = false
      responses = []

      ws.on :open do
        connected = true
      end

      ws.on :message do |msg|
        responses << JSON.parse(msg.data)
      end

      # Wait for connection
      timeout = 5
      start_time = Time.now
      while !connected && (Time.now - start_time) < timeout
        sleep(0.1)
      end

      # Take screenshot
      ws.send({
        id: 3,
        method: 'Page.captureScreenshot',
        params: {
          format: 'png',
          captureBeyondViewport: true
        }
      }.to_json)

      sleep(2)

      screenshot_response = responses.find { |r| r['id'] == 3 }
      expect(screenshot_response).not_to be_nil
      expect(screenshot_response['result']).to have_key('data')
      expect(screenshot_response['result']['data']).to match(/^[A-Za-z0-9+\/=]+$/) # Base64

      ws.close
    end
  end

  describe 'MCP Bridge Control' do
    let(:mcp_server) { Inception::MCP::Server.new(cdp_port: chrome_port) }

    before do
      # Clear previous requests
      @received_requests.clear
    end

    it 'can connect MCP server to Chrome' do
      expect(mcp_server).to respond_to(:start)
      
      # Mock the stdio loop for testing
      allow(mcp_server).to receive(:run_stdio_loop).and_return(true)
      
      result = mcp_server.start
      expect(result).not_to be false
    end

    it 'can navigate browser through MCP tools' do
      # Simulate MCP tool call
      cdp_client = Inception::MCP::CDPClient.new(chrome_port)
      expect(cdp_client.connect).to be true

      tools = Inception::MCP::Tools.new(cdp_client)
      
      # Clear requests
      @received_requests.clear
      
      # Execute navigate tool
      result = tools.execute_tool('navigate_browser', { 'url' => "http://127.0.0.1:#{webserver_port}/mcp-test" })
      
      expect(result).to have_key(:content)
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first[:text]).to include('Navigation command sent')

      # Wait for navigation
      sleep(2)

      # Verify webserver received the request
      expect(@received_requests.any? { |req| req[:path] == '/mcp-test' }).to be true

      cdp_client.disconnect
    end

    it 'can take screenshots through MCP tools' do
      cdp_client = Inception::MCP::CDPClient.new(chrome_port)
      expect(cdp_client.connect).to be true

      tools = Inception::MCP::Tools.new(cdp_client)
      
      result = tools.execute_tool('take_screenshot', { 'format' => 'png' })
      
      expect(result).to have_key(:content)
      expect(result[:content].first[:text]).to include('Screenshot command sent')

      cdp_client.disconnect
    end

    it 'can simulate clicks through MCP tools' do
      cdp_client = Inception::MCP::CDPClient.new(chrome_port)
      expect(cdp_client.connect).to be true

      tools = Inception::MCP::Tools.new(cdp_client)
      
      result = tools.execute_tool('click_element', { 'x' => 100, 'y' => 200 })
      
      expect(result).to have_key(:content)
      expect(result[:content].first[:text]).to include('Click sent to coordinates (100, 200)')

      cdp_client.disconnect
    end

    it 'preserves request flow consistency between direct CDP and MCP' do
      # Clear requests
      @received_requests.clear

      # Test direct CDP navigation
      tabs_response = Net::HTTP.get_response(URI("http://127.0.0.1:#{chrome_port}/json/list"))
      tabs = JSON.parse(tabs_response.body)
      ws_url = tabs.first['webSocketDebuggerUrl']

      ws = WebSocket::Client::Simple.connect(ws_url)
      connected = false

      ws.on :open do
        connected = true
      end

      # Wait for connection
      timeout = 5
      start_time = Time.now
      while !connected && (Time.now - start_time) < timeout
        sleep(0.1)
      end

      # Direct CDP navigation
      ws.send({
        id: 4,
        method: 'Page.navigate',
        params: { url: "http://127.0.0.1:#{webserver_port}/direct-cdp" }
      }.to_json)

      sleep(1)
      ws.close

      direct_requests = @received_requests.select { |req| req[:path] == '/direct-cdp' }
      expect(direct_requests).not_to be_empty

      # Clear and test MCP navigation
      @received_requests.clear

      cdp_client = Inception::MCP::CDPClient.new(chrome_port)
      cdp_client.connect
      tools = Inception::MCP::Tools.new(cdp_client)
      
      tools.execute_tool('navigate_browser', { 'url' => "http://127.0.0.1:#{webserver_port}/mcp-bridge" })
      sleep(1)

      mcp_requests = @received_requests.select { |req| req[:path] == '/mcp-bridge' }
      expect(mcp_requests).not_to be_empty

      # Both should generate same type of HTTP requests to our server
      expect(direct_requests.first[:method]).to eq(mcp_requests.first[:method])
      expect(direct_requests.first[:headers]).to include(mcp_requests.first[:headers])

      cdp_client.disconnect
    end
  end

  private

  def start_test_webserver
    Thread.new do
      server = WEBrick::HTTPServer.new(
        Port: webserver_port,
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: []
      )

      server.mount_proc '/' do |req, res|
        @received_requests << {
          method: req.request_method,
          path: req.path,
          headers: req.header.to_h,
          timestamp: Time.now
        }

        res.content_type = 'text/html'
        res.body = %{
          <!DOCTYPE html>
          <html>
          <head><title>Test Page</title></head>
          <body>
            <h1>Test Server</h1>
            <p>Path: #{req.path}</p>
            <button id="test-button">Click me</button>
          </body>
          </html>
        }
      end

      trap('INT') { server.shutdown }
      server.start
    end
  end

  def start_headless_chrome
    chrome_cmd = [
      'google-chrome',
      '--headless=new',
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--disable-extensions',
      '--disable-gpu',
      '--remote-debugging-port=' + chrome_port.to_s,
      '--remote-debugging-address=127.0.0.1',
      'about:blank'
    ]

    # Try different Chrome executable names
    chrome_executables = ['google-chrome', 'chromium', 'chromium-browser', 'chrome']
    
    chrome_executables.each do |executable|
      begin
        pid = Process.spawn(executable, *chrome_cmd[1..-1])
        Process.detach(pid)
        return pid
      rescue Errno::ENOENT
        next
      end
    end

    raise 'Could not find Chrome/Chromium executable'
  end

  def stop_headless_chrome(pid)
    return unless pid
    
    begin
      Process.kill('TERM', pid)
      sleep(1)
      Process.kill('KILL', pid) if process_exists?(pid)
    rescue Errno::ESRCH
      # Process already stopped
    end
  end

  def process_exists?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
end