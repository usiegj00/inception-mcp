# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Inception
  module MCP
    class StreamingServer < Server
      def initialize(cdp_port: nil, streaming_endpoint: nil)
        super(cdp_port: cdp_port)
        @streaming_endpoint = streaming_endpoint
        @http_client = setup_http_client if @streaming_endpoint
      end

      private

      def setup_http_client
        uri = URI(@streaming_endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = 30
        http.open_timeout = 10
        http
      end

      def handle_request(request)
        method = request['method']
        params = request['params'] || {}
        id = request['id']

        case method
        when 'streaming/http'
          handle_streaming_http(id, params)
        else
          super(request)
        end
      end

      def handle_streaming_http(id, params)
        url = params['url']
        http_method = params['method'] || 'GET'
        headers = params['headers'] || {}
        body = params['body']

        unless url
          send_error_response(id, -32602, "Missing required parameter: url")
          return
        end

        begin
          uri = URI(url)
          response = perform_http_request(uri, http_method, headers, body)
          
          send_response({
            jsonrpc: "2.0",
            id: id,
            result: {
              status: response.code.to_i,
              headers: response.to_hash,
              body: response.body
            }
          })
        rescue => e
          send_error_response(id, -32603, "HTTP request failed: #{e.message}")
        end
      end

      def perform_http_request(uri, method, headers, body)
        if @streaming_endpoint
          # Route through fast-mcp streaming endpoint
          proxy_request(uri, method, headers, body)
        else
          # Direct HTTP request
          direct_request(uri, method, headers, body)
        end
      end

      def proxy_request(uri, method, headers, body)
        proxy_uri = URI(@streaming_endpoint)
        
        request_class = case method.upcase
                       when 'GET' then Net::HTTP::Get
                       when 'POST' then Net::HTTP::Post
                       when 'PUT' then Net::HTTP::Put
                       when 'DELETE' then Net::HTTP::Delete
                       when 'PATCH' then Net::HTTP::Patch
                       else Net::HTTP::Get
                       end

        request = request_class.new(proxy_uri.path)
        
        # Add target URL and original headers to proxy request
        request['X-Target-URL'] = uri.to_s
        request['X-Original-Method'] = method
        request['Content-Type'] = 'application/json'
        
        proxy_body = {
          url: uri.to_s,
          method: method,
          headers: headers,
          body: body
        }.to_json
        
        request.body = proxy_body if ['POST', 'PUT', 'PATCH'].include?(method.upcase)
        
        headers.each { |key, value| request[key] = value }
        
        @http_client.request(request)
      end

      def direct_request(uri, method, headers, body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        
        request_class = case method.upcase
                       when 'GET' then Net::HTTP::Get
                       when 'POST' then Net::HTTP::Post
                       when 'PUT' then Net::HTTP::Put
                       when 'DELETE' then Net::HTTP::Delete
                       when 'PATCH' then Net::HTTP::Patch
                       else Net::HTTP::Get
                       end

        request = request_class.new(uri.request_uri)
        headers.each { |key, value| request[key] = value }
        request.body = body if body && ['POST', 'PUT', 'PATCH'].include?(method.upcase)
        
        http.request(request)
      end

      def tool_definitions_with_streaming
        base_tools = @tools&.tool_definitions || []
        
        streaming_tools = [
          {
            name: "streaming_http_request",
            description: "Make HTTP requests through fast-mcp streaming endpoint",
            inputSchema: {
              type: "object",
              properties: {
                url: {
                  type: "string",
                  description: "The URL to request"
                },
                method: {
                  type: "string",
                  enum: ["GET", "POST", "PUT", "DELETE", "PATCH"],
                  description: "HTTP method",
                  default: "GET"
                },
                headers: {
                  type: "object",
                  description: "HTTP headers as key-value pairs"
                },
                body: {
                  type: "string",
                  description: "Request body for POST/PUT/PATCH requests"
                }
              },
              required: ["url"]
            }
          }
        ]
        
        base_tools + streaming_tools
      end

      def handle_tools_list(id)
        send_response({
          jsonrpc: "2.0",
          id: id,
          result: {
            tools: tool_definitions_with_streaming
          }
        })
      end

      def handle_tools_call(id, params)
        tool_name = params['name']
        arguments = params['arguments'] || {}

        if tool_name == 'streaming_http_request'
          handle_streaming_http(id, arguments)
        else
          super
        end
      end

      # Override methods to use streaming-enhanced versions
      def handle_request(request)
        method = request['method']
        params = request['params'] || {}
        id = request['id']

        case method
        when 'tools/list'
          handle_tools_list(id)
        when 'tools/call'
          handle_tools_call(id, params)
        else
          super(request)
        end
      end
    end
  end
end