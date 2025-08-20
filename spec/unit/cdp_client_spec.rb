# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Inception::MCP::CDPClient do
  let(:cdp_port) { 9222 }
  let(:cdp_client) { described_class.new(cdp_port) }

  describe '#initialize' do
    it 'sets up client with correct port and URL' do
      expect(cdp_client.instance_variable_get(:@cdp_port)).to eq(9222)
      expect(cdp_client.instance_variable_get(:@cdp_base_url)).to eq('http://127.0.0.1:9222')
      expect(cdp_client.connected).to be false
      expect(cdp_client.tabs).to eq([])
    end
  end

  describe '#send_command' do
    it 'returns nil when not connected' do
      expect(cdp_client.send_command('Page.navigate', { url: 'https://example.com' })).to be_nil
    end

    it 'increments request ID for each command' do
      # Mock websocket connection
      mock_ws = double('WebSocket')
      allow(mock_ws).to receive(:send)
      
      cdp_client.instance_variable_set(:@ws, mock_ws)
      cdp_client.instance_variable_set(:@connected, true)

      # Send two commands
      expect(mock_ws).to receive(:send).with(
        { id: 1, method: 'Page.navigate', params: { url: 'https://example.com' } }.to_json
      )
      expect(mock_ws).to receive(:send).with(
        { id: 2, method: 'Page.reload', params: {} }.to_json
      )

      first_id = cdp_client.send_command('Page.navigate', { url: 'https://example.com' })
      second_id = cdp_client.send_command('Page.reload')

      expect(first_id).to eq(1)
      expect(second_id).to eq(2)
    end
  end

  describe 'browser control methods' do
    let(:mock_ws) { double('WebSocket') }

    before do
      cdp_client.instance_variable_set(:@ws, mock_ws)
      cdp_client.instance_variable_set(:@connected, true)
      allow(mock_ws).to receive(:send)
    end

    describe '#navigate' do
      it 'sends Page.navigate command' do
        expect(mock_ws).to receive(:send).with(
          { id: 1, method: 'Page.navigate', params: { url: 'https://example.com' } }.to_json
        )
        
        cdp_client.navigate('https://example.com')
      end
    end

    describe '#take_screenshot' do
      it 'sends Page.captureScreenshot with default parameters' do
        expect(mock_ws).to receive(:send).with(
          { 
            id: 1, 
            method: 'Page.captureScreenshot', 
            params: { 
              format: 'png', 
              quality: 80, 
              captureBeyondViewport: false 
            } 
          }.to_json
        )
        
        cdp_client.take_screenshot
      end

      it 'sends Page.captureScreenshot with custom parameters' do
        expect(mock_ws).to receive(:send).with(
          { 
            id: 1, 
            method: 'Page.captureScreenshot', 
            params: { 
              format: 'jpeg', 
              quality: 90, 
              captureBeyondViewport: false 
            } 
          }.to_json
        )
        
        cdp_client.take_screenshot(format: 'jpeg', quality: 90)
      end
    end

    describe '#click_element' do
      it 'sends mouse pressed and released events' do
        expect(mock_ws).to receive(:send).with(
          { 
            id: 1, 
            method: 'Input.dispatchMouseEvent', 
            params: { 
              type: 'mousePressed', 
              x: 100, 
              y: 200, 
              button: 'left', 
              clickCount: 1 
            } 
          }.to_json
        )
        
        expect(mock_ws).to receive(:send).with(
          { 
            id: 2, 
            method: 'Input.dispatchMouseEvent', 
            params: { 
              type: 'mouseReleased', 
              x: 100, 
              y: 200, 
              button: 'left', 
              clickCount: 1 
            } 
          }.to_json
        )
        
        cdp_client.click_element(100, 200)
      end
    end

    describe '#type_text' do
      it 'sends char events for each character' do
        expect(mock_ws).to receive(:send).with(
          { id: 1, method: 'Input.dispatchKeyEvent', params: { type: 'char', text: 'H' } }.to_json
        )
        expect(mock_ws).to receive(:send).with(
          { id: 2, method: 'Input.dispatchKeyEvent', params: { type: 'char', text: 'i' } }.to_json
        )
        
        cdp_client.type_text('Hi')
      end
    end

    describe '#press_key' do
      it 'sends keyDown and keyUp events for Enter key' do
        expect(mock_ws).to receive(:send).with(
          { id: 1, method: 'Input.dispatchKeyEvent', params: { type: 'keyDown', keyCode: 13 } }.to_json
        )
        expect(mock_ws).to receive(:send).with(
          { id: 2, method: 'Input.dispatchKeyEvent', params: { type: 'keyUp', keyCode: 13 } }.to_json
        )
        
        cdp_client.press_key('Enter')
      end

      it 'sends keyDown and keyUp events for character key' do
        expect(mock_ws).to receive(:send).with(
          { id: 1, method: 'Input.dispatchKeyEvent', params: { type: 'keyDown', keyCode: 65 } }.to_json
        )
        expect(mock_ws).to receive(:send).with(
          { id: 2, method: 'Input.dispatchKeyEvent', params: { type: 'keyUp', keyCode: 65 } }.to_json
        )
        
        cdp_client.press_key('A')
      end
    end
  end

  describe '#get_tabs_info' do
    it 'parses tab information correctly' do
      mock_response = [
        {
          'id' => 'tab1',
          'title' => 'Test Page',
          'url' => 'https://example.com',
          'type' => 'page'
        }
      ].to_json

      allow(cdp_client).to receive(:http_get).with('/json/list').and_return(mock_response)
      
      tabs = cdp_client.get_tabs_info
      
      expect(tabs).to be_an(Array)
      expect(tabs.first).to eq({
        id: 'tab1',
        title: 'Test Page',
        url: 'https://example.com',
        type: 'page'
      })
    end

    it 'returns empty array on HTTP failure' do
      allow(cdp_client).to receive(:http_get).with('/json/list').and_return(nil)
      
      tabs = cdp_client.get_tabs_info
      
      expect(tabs).to eq([])
    end

    it 'returns empty array on JSON parse error' do
      allow(cdp_client).to receive(:http_get).with('/json/list').and_return('invalid json')
      
      tabs = cdp_client.get_tabs_info
      
      expect(tabs).to eq([])
    end
  end
end