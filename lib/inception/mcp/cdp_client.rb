# frozen_string_literal: true

require 'websocket-client-simple'
require 'json'
require 'net/http'
require 'uri'

module Inception
  module MCP
    class CDPClient
      attr_reader :connected, :tabs

      def initialize(cdp_port = 9222)
        @cdp_port = cdp_port
        @cdp_base_url = "http://127.0.0.1:#{@cdp_port}"
        @connected = false
        @tabs = []
        @ws = nil
        @callbacks = {}
        @request_id = 0
      end

      def connect
        discover_tabs
        return false if @tabs.empty?
        
        # Connect to the first available tab
        tab = @tabs.first
        connect_to_tab(tab['webSocketDebuggerUrl'])
      end

      def disconnect
        @ws&.close
        @connected = false
      end

      def send_command(method, params = {})
        return nil unless @connected

        @request_id += 1
        command = {
          id: @request_id,
          method: method,
          params: params
        }

        @ws.send(command.to_json)
        @request_id
      end

      def navigate(url)
        send_command('Page.navigate', { url: url })
      end

      def take_screenshot(format: 'png', quality: 80)
        send_command('Page.captureScreenshot', {
          format: format,
          quality: quality,
          captureBeyondViewport: true
        })
      end

      def get_page_content
        send_command('Runtime.evaluate', {
          expression: 'document.documentElement.outerHTML'
        })
      end

      def click_element(x, y)
        # First dispatch mousePressed
        send_command('Input.dispatchMouseEvent', {
          type: 'mousePressed',
          x: x,
          y: y,
          button: 'left',
          clickCount: 1
        })
        
        # Then dispatch mouseReleased
        send_command('Input.dispatchMouseEvent', {
          type: 'mouseReleased', 
          x: x,
          y: y,
          button: 'left',
          clickCount: 1
        })
      end

      def type_text(text)
        text.each_char do |char|
          send_command('Input.dispatchKeyEvent', {
            type: 'char',
            text: char
          })
        end
      end

      def press_key(key)
        # Map common keys to their codes
        key_codes = {
          'Enter' => 13,
          'Backspace' => 8,
          'Tab' => 9,
          'Escape' => 27,
          'ArrowUp' => 38,
          'ArrowDown' => 40,
          'ArrowLeft' => 37,
          'ArrowRight' => 39
        }

        code = key_codes[key] || key.ord
        
        send_command('Input.dispatchKeyEvent', {
          type: 'keyDown',
          keyCode: code
        })
        
        send_command('Input.dispatchKeyEvent', {
          type: 'keyUp', 
          keyCode: code
        })
      end

      def get_tabs_info
        response = http_get('/json/list')
        return [] unless response

        JSON.parse(response).map do |tab|
          {
            id: tab['id'],
            title: tab['title'],
            url: tab['url'],
            type: tab['type']
          }
        end
      rescue JSON::ParserError
        []
      end

      def get_page_info
        return nil unless @connected

        # Get current URL
        send_command('Target.getTargetInfo')
      end

      private

      def discover_tabs
        response = http_get('/json/list')
        return unless response

        @tabs = JSON.parse(response).select { |tab| tab['type'] == 'page' }
      rescue JSON::ParserError => e
        puts "Error parsing tabs response: #{e.message}"
        @tabs = []
      end

      def connect_to_tab(ws_url)
        return false unless ws_url

        @ws = WebSocket::Client::Simple.connect(ws_url)
        cdp_client = self

        @ws.on :open do
          puts "WebSocket opened"
          cdp_client.instance_variable_set(:@connected, true)
          puts "Connected to CDP WebSocket"
          
          # Enable necessary domains
          cdp_client.send_command('Page.enable')
          cdp_client.send_command('Runtime.enable')
          cdp_client.send_command('Input.enable')
        end

        @ws.on :message do |msg|
          begin
            data = JSON.parse(msg.data)
            cdp_client.send(:handle_message, data)
          rescue JSON::ParserError => e
            puts "Error parsing WebSocket message: #{e.message}"
          end
        end

        @ws.on :close do
          cdp_client.instance_variable_set(:@connected, false)
          puts "CDP WebSocket connection closed"
        end

        @ws.on :error do |e|
          puts "CDP WebSocket error: #{e.message}"
          cdp_client.instance_variable_set(:@connected, false)
        end

        # Wait for connection to establish
        timeout = 5.0  # 5 seconds timeout
        start_time = Time.now
        
        while !@connected && (Time.now - start_time) < timeout
          sleep(0.1)
        end
        
        puts "Connection status after wait: #{@connected}"
        @connected
      end

      def handle_message(data)
        # Handle CDP protocol messages
        if data['id']
          # Response to our command
          request_id = data['id']
          if @callbacks[request_id]
            @callbacks[request_id].call(data)
            @callbacks.delete(request_id)
          end
        else
          # Event from browser
          handle_event(data)
        end
      end

      def handle_event(data)
        # Handle CDP events like page navigation, console logs, etc.
        method = data['method']
        params = data['params']

        case method
        when 'Page.loadEventFired'
          puts "Page loaded"
        when 'Runtime.consoleAPICalled'
          puts "Console: #{params['args'].map { |arg| arg['value'] }.join(' ')}"
        end
      end

      def http_get(path)
        uri = URI("#{@cdp_base_url}#{path}")
        response = Net::HTTP.get_response(uri)
        response.code == '200' ? response.body : nil
      rescue => e
        puts "HTTP request failed: #{e.message}"
        nil
      end
    end
  end
end