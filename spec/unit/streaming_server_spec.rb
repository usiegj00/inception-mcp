# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Inception::MCP::StreamingServer do
  let(:cdp_port) { 9222 }
  let(:streaming_endpoint) { 'https://api.example.com/streaming' }
  let(:server) { described_class.new(cdp_port: cdp_port, streaming_endpoint: streaming_endpoint) }

  describe '#initialize' do
    it 'sets up streaming endpoint and HTTP client' do
      expect(server.instance_variable_get(:@streaming_endpoint)).to eq(streaming_endpoint)
      expect(server.instance_variable_get(:@http_client)).not_to be_nil
    end

    it 'works without streaming endpoint' do
      basic_server = described_class.new(cdp_port: cdp_port)
      expect(basic_server.instance_variable_get(:@streaming_endpoint)).to be_nil
      expect(basic_server.instance_variable_get(:@http_client)).to be_nil
    end
  end

  describe 'tool definitions with streaming' do
    let(:mock_tools) { double('Tools') }
    let(:base_tools) do
      [
        {
          name: "navigate_browser",
          description: "Navigate browser",
          inputSchema: { type: "object" }
        }
      ]
    end

    before do
      allow(mock_tools).to receive(:tool_definitions).and_return(base_tools)
      server.instance_variable_set(:@tools, mock_tools)
    end

    it 'includes streaming HTTP tool in definitions' do
      tools = server.send(:tool_definitions_with_streaming)
      
      expect(tools).to be_an(Array)
      expect(tools.length).to eq(2)
      
      streaming_tool = tools.find { |tool| tool[:name] == 'streaming_http_request' }
      expect(streaming_tool).not_to be_nil
      expect(streaming_tool[:description]).to include('fast-mcp streaming')
      expect(streaming_tool[:inputSchema][:properties]).to have_key(:url)
      expect(streaming_tool[:inputSchema][:properties]).to have_key(:method)
      expect(streaming_tool[:inputSchema][:required]).to eq(['url'])
    end
  end

  describe 'HTTP request handling' do
    let(:mock_http_client) { double('HTTP Client') }
    let(:mock_response) { double('HTTP Response', code: '200', to_hash: {}, body: 'success') }

    before do
      server.instance_variable_set(:@http_client, mock_http_client)
    end

    describe '#perform_http_request' do
      it 'uses proxy request when streaming endpoint is configured' do
        uri = URI('https://example.com/api')
        
        expect(server).to receive(:proxy_request).with(uri, 'GET', {}, nil).and_return(mock_response)
        
        result = server.send(:perform_http_request, uri, 'GET', {}, nil)
        expect(result).to eq(mock_response)
      end

      it 'uses direct request when no streaming endpoint' do
        server.instance_variable_set(:@streaming_endpoint, nil)
        uri = URI('https://example.com/api')
        
        expect(server).to receive(:direct_request).with(uri, 'GET', {}, nil).and_return(mock_response)
        
        result = server.send(:perform_http_request, uri, 'GET', {}, nil)
        expect(result).to eq(mock_response)
      end
    end

    describe '#proxy_request' do
      it 'formats request correctly for streaming endpoint' do
        uri = URI('https://example.com/api')
        headers = { 'User-Agent' => 'test' }
        body = 'request body'
        
        expect(mock_http_client).to receive(:request) do |request|
          expect(request['X-Target-URL']).to eq('https://example.com/api')
          expect(request['X-Original-Method']).to eq('POST')
          expect(request['Content-Type']).to eq('application/json')
          expect(request['User-Agent']).to eq('test')
          
          parsed_body = JSON.parse(request.body)
          expect(parsed_body['url']).to eq('https://example.com/api')
          expect(parsed_body['method']).to eq('POST')
          expect(parsed_body['headers']).to eq(headers)
          expect(parsed_body['body']).to eq(body)
          
          mock_response
        end
        
        result = server.send(:proxy_request, uri, 'POST', headers, body)
        expect(result).to eq(mock_response)
      end
    end

    describe '#direct_request' do
      it 'makes direct HTTP request without proxy' do
        uri = URI('https://example.com/api')
        
        expect(Net::HTTP).to receive(:new).with('example.com', 443).and_return(mock_http_client)
        expect(mock_http_client).to receive(:use_ssl=).with(true)
        expect(mock_http_client).to receive(:request).and_return(mock_response)
        
        result = server.send(:direct_request, uri, 'GET', {}, nil)
        expect(result).to eq(mock_response)
      end
    end
  end

  describe 'request handling' do
    before do
      # Mock stdio methods to avoid actual I/O
      allow(server).to receive(:send_response)
      allow(server).to receive(:send_error_response)
    end

    describe '#handle_streaming_http' do
      it 'validates required parameters' do
        expect(server).to receive(:send_error_response).with(1, -32602, "Missing required parameter: url")
        
        server.send(:handle_streaming_http, 1, {})
      end

      it 'makes HTTP request and returns response' do
        params = {
          'url' => 'https://example.com/api',
          'method' => 'GET',
          'headers' => { 'Accept' => 'application/json' }
        }
        
        mock_response = double('Response', code: '200', to_hash: { 'content-type' => ['application/json'] }, body: '{"success": true}')
        
        expect(server).to receive(:perform_http_request).and_return(mock_response)
        expect(server).to receive(:send_response) do |response|
          expect(response[:jsonrpc]).to eq("2.0")
          expect(response[:id]).to eq(1)
          expect(response[:result][:status]).to eq(200)
          expect(response[:result][:body]).to eq('{"success": true}')
        end
        
        server.send(:handle_streaming_http, 1, params)
      end

      it 'handles HTTP request errors' do
        params = { 'url' => 'invalid-url' }
        
        expect(server).to receive(:perform_http_request).and_raise(StandardError.new("Connection failed"))
        expect(server).to receive(:send_error_response).with(1, -32603, "HTTP request failed: Connection failed")
        
        server.send(:handle_streaming_http, 1, params)
      end
    end
  end
end