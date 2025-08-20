# frozen_string_literal: true

require 'json'

module Inception
  module MCP
    class Server
      def initialize(cdp_port: nil)
        @cdp_port = cdp_port || detect_inception_cdp_port
        @cdp_client = nil
        @tools = nil
      end

      def start
        return false unless @cdp_port

        @cdp_client = CDPClient.new(@cdp_port)
        connected = @cdp_client.connect
        
        if connected
          @tools = Tools.new(@cdp_client)
          STDERR.puts "MCP Server connected to Inception browser on port #{@cdp_port}"
          run_stdio_loop
          true
        else
          STDERR.puts "Failed to connect to browser on port #{@cdp_port}"
          false
        end
      end

      private

      def detect_inception_cdp_port
        # Try common ports where Inception might be running CDP
        [9222, 9223, 9224, 9225].each do |port|
          if port_available?(port)
            STDERR.puts "Found potential CDP endpoint on port #{port}"
            return port
          end
        end
        
        STDERR.puts "No CDP endpoint found. Make sure Inception browser is running."
        nil
      end

      def port_available?(port)
        require 'net/http'
        uri = URI("http://127.0.0.1:#{port}/json/list")
        response = Net::HTTP.get_response(uri)
        response.code == '200'
      rescue
        false
      end

      def run_stdio_loop
        STDOUT.sync = true

        STDIN.each_line do |line|
          begin
            request = JSON.parse(line.strip)
            handle_request(request)
          rescue JSON::ParserError => e
            send_error_response(nil, -32700, "Parse error: #{e.message}")
          rescue => e
            send_error_response(request&.dig('id'), -32603, "Internal error: #{e.message}")
          end
        end
      end

      def handle_request(request)
        method = request['method']
        params = request['params'] || {}
        id = request['id']

        case method
        when 'initialize'
          send_response({
            jsonrpc: "2.0",
            id: id,
            result: {
              protocolVersion: "2024-11-05",
              capabilities: {
                tools: {},
                resources: {},
                prompts: {}
              },
              serverInfo: {
                name: "inception-mcp",
                version: VERSION
              },
              instructions: "MCP server for controlling Inception browser. Provides tools for web automation including navigation, screenshots, clicking, typing, and content extraction. Connect to an Inception browser instance via Chrome DevTools Protocol (CDP) to enable AI-driven web browsing and testing."
            }
          })

        when 'tools/list'
          send_response({
            jsonrpc: "2.0",
            id: id,
            result: {
              tools: @tools.tool_definitions
            }
          })

        when 'tools/call'
          tool_name = params['name']
          arguments = params['arguments'] || {}
          result = @tools.execute_tool(tool_name, arguments)
          
          send_response({
            jsonrpc: "2.0",
            id: id,
            result: result
          })

        when 'initialized'
          # Client confirms initialization is complete - no response needed

        when 'ping'
          send_response({
            jsonrpc: "2.0", 
            id: id,
            result: {}
          })

        else
          send_error_response(id, -32601, "Method not found: #{method}")
        end
      end

      def send_response(response)
        puts response.to_json
      end

      def send_error_response(id, code, message)
        send_response({
          jsonrpc: "2.0",
          id: id,
          error: {
            code: code,
            message: message
          }
        })
      end
    end
  end
end