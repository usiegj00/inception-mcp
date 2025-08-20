# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Inception::MCP::Tools do
  let(:mock_cdp_client) { instance_double(Inception::MCP::CDPClient) }
  let(:tools) { described_class.new(mock_cdp_client) }

  describe '#tool_definitions' do
    it 'returns all available tools' do
      definitions = tools.tool_definitions
      
      expect(definitions).to be_an(Array)
      expect(definitions.length).to eq(39)
      
      tool_names = definitions.map { |tool| tool[:name] }
      expected_tools = [
        'navigate_browser',
        'take_screenshot', 
        'click_element',
        'type_text',
        'press_key',
        'press_key_combination',
        'send_text_with_shortcuts',
        'get_page_content',
        'get_page_info',
        'get_page_text',
        'get_structured_content',
        'get_page_metadata',
        'get_interactive_elements',
        'fill_form_field',
        'select_option',
        'check_checkbox',
        'get_windows_and_tabs',
        'create_new_tab',
        'close_tab',
        'switch_to_tab',
        'navigate_back',
        'navigate_forward',
        'reload_page',
        'inject_script',
        'execute_script',
        'create_script_bridge',
        'capture_console',
        'get_console_logs',
        'scroll_page',
        'scroll_to_element',
        'scroll_to_coordinates',
        'get_scroll_position',
        'smooth_scroll',
        'resize_window',
        'maximize_window',
        'minimize_window',
        'restore_window',
        'get_window_bounds',
        'set_window_position'
      ]
      
      expect(tool_names).to match_array(expected_tools)
    end

    it 'includes proper schema for each tool' do
      definitions = tools.tool_definitions
      
      definitions.each do |tool|
        expect(tool).to have_key(:name)
        expect(tool).to have_key(:description)
        expect(tool).to have_key(:inputSchema)
        expect(tool[:inputSchema]).to have_key(:type)
        expect(tool[:inputSchema][:type]).to eq('object')
      end
    end
  end

  describe '#execute_tool' do
    describe 'navigate_browser' do
      it 'calls CDP client navigate method' do
        expect(mock_cdp_client).to receive(:navigate).with('https://example.com').and_return(123)
        
        result = tools.execute_tool('navigate_browser', { 'url' => 'https://example.com' })
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Navigation command sent')
      end
    end

    describe 'take_screenshot' do
      it 'calls CDP client take_screenshot method with defaults' do
        expect(mock_cdp_client).to receive(:take_screenshot)
          .with(format: 'png', quality: 80)
          .and_return(456)
        
        result = tools.execute_tool('take_screenshot', {})
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Screenshot command sent')
        expect(result[:content].first[:text]).to include('request ID: 456')
      end

      it 'passes custom format and quality' do
        expect(mock_cdp_client).to receive(:take_screenshot)
          .with(format: 'jpeg', quality: 90)
          .and_return(789)
        
        result = tools.execute_tool('take_screenshot', { 'format' => 'jpeg', 'quality' => 90 })
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Screenshot command sent')
      end
    end

    describe 'click_element' do
      it 'calls CDP client click_element method' do
        expect(mock_cdp_client).to receive(:click_element).with(100, 200)
        
        result = tools.execute_tool('click_element', { 'x' => 100, 'y' => 200 })
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to eq('Click sent to coordinates (100, 200)')
      end
    end

    describe 'type_text' do
      it 'calls CDP client type_text method' do
        expect(mock_cdp_client).to receive(:type_text).with('Hello World')
        
        result = tools.execute_tool('type_text', { 'text' => 'Hello World' })
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to eq('Typed: Hello World')
      end
    end

    describe 'press_key' do
      it 'calls CDP client press_key method' do
        expect(mock_cdp_client).to receive(:press_key).with('Enter')
        
        result = tools.execute_tool('press_key', { 'key' => 'Enter' })
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to eq('Pressed key: Enter')
      end
    end

    describe 'get_page_content' do
      it 'calls CDP client get_page_content method' do
        expect(mock_cdp_client).to receive(:get_page_content).and_return(999)
        
        result = tools.execute_tool('get_page_content', {})
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Page content request sent')
        expect(result[:content].first[:text]).to include('request ID: 999')
      end
    end

    describe 'get_page_info' do
      it 'returns page info when tabs are available' do
        mock_tabs = [
          { id: 'tab1', title: 'Test Page', url: 'https://example.com', type: 'page' }
        ]
        expect(mock_cdp_client).to receive(:get_tabs_info).and_return(mock_tabs)
        
        result = tools.execute_tool('get_page_info', {})
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Page Info:')
        expect(result[:content].first[:text]).to include('Title: Test Page')
        expect(result[:content].first[:text]).to include('URL: https://example.com')
      end

      it 'returns no info message when no tabs available' do
        expect(mock_cdp_client).to receive(:get_tabs_info).and_return([])
        
        result = tools.execute_tool('get_page_info', {})
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to eq('No page information available')
      end
    end

    describe 'get_interactive_elements' do
      it 'returns interactive elements when found' do
        mock_elements = [
          { 'tagName' => 'button', 'selector' => '#submit-btn', 'text' => 'Submit', 'x' => 100, 'y' => 200, 'width' => 80, 'height' => 30 },
          { 'tagName' => 'a', 'selector' => '#nav-link', 'text' => 'Home', 'x' => 50, 'y' => 50, 'width' => 60, 'height' => 20 }
        ]
        
        expect(mock_cdp_client).to receive(:get_interactive_elements).and_return(mock_elements)
        
        result = tools.execute_tool('get_interactive_elements', {})
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Interactive Elements Found:')
        expect(result[:content].first[:text]).to include('BUTTON')
        expect(result[:content].first[:text]).to include('Submit')
      end

      it 'returns no elements message when none found' do
        expect(mock_cdp_client).to receive(:get_interactive_elements).and_return([])
        
        result = tools.execute_tool('get_interactive_elements', {})
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to eq('No interactive elements found on the current page')
      end
    end

    describe 'enhanced click_element' do
      it 'clicks element by CSS selector when provided' do
        mock_result = { 'success' => true, 'x' => 100, 'y' => 200, 'tagName' => 'button' }
        expect(mock_cdp_client).to receive(:click_element_by_selector).with('#submit-btn').and_return(mock_result)
        
        result = tools.execute_tool('click_element', { 'selector' => '#submit-btn' })
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Successfully clicked element')
        expect(result[:content].first[:text]).to include('#submit-btn')
      end

      it 'returns error when selector fails' do
        mock_result = { 'error' => 'Element not found', 'selector' => '#missing-btn' }
        expect(mock_cdp_client).to receive(:click_element_by_selector).with('#missing-btn').and_return(mock_result)
        
        result = tools.execute_tool('click_element', { 'selector' => '#missing-btn' })
        
        expect(result).to have_key(:content)
        expect(result[:content].first[:text]).to include('Failed to click element')
        expect(result).to have_key(:isError)
        expect(result[:isError]).to be true
      end
    end

    describe 'form filling tools' do
      describe 'fill_form_field' do
        it 'fills form field successfully' do
          mock_result = { 'success' => true, 'selector' => '#email', 'value' => 'test@example.com' }
          expect(mock_cdp_client).to receive(:fill_form_field).with('#email', 'test@example.com').and_return(mock_result)
          
          result = tools.execute_tool('fill_form_field', { 'selector' => '#email', 'value' => 'test@example.com' })
          
          expect(result).to have_key(:content)
          expect(result[:content].first[:text]).to include('Successfully filled form field')
          expect(result[:content].first[:text]).to include('#email')
        end

        it 'returns error when form field filling fails' do
          mock_result = { 'error' => 'Element not found', 'selector' => '#missing' }
          expect(mock_cdp_client).to receive(:fill_form_field).with('#missing', 'test').and_return(mock_result)
          
          result = tools.execute_tool('fill_form_field', { 'selector' => '#missing', 'value' => 'test' })
          
          expect(result).to have_key(:content)
          expect(result[:content].first[:text]).to include('Failed to fill form field')
          expect(result).to have_key(:isError)
          expect(result[:isError]).to be true
        end
      end

      describe 'select_option' do
        it 'selects option successfully' do
          mock_result = { 'success' => true, 'selector' => '#country', 'selectedValue' => 'us', 'selectedText' => 'United States' }
          expect(mock_cdp_client).to receive(:select_option).with('#country', 'us').and_return(mock_result)
          
          result = tools.execute_tool('select_option', { 'selector' => '#country', 'value' => 'us' })
          
          expect(result).to have_key(:content)
          expect(result[:content].first[:text]).to include('Successfully selected')
          expect(result[:content].first[:text]).to include('United States')
        end
      end

      describe 'check_checkbox' do
        it 'checks checkbox successfully' do
          mock_result = { 'success' => true, 'selector' => '#agree', 'checked' => true, 'type' => 'checkbox' }
          expect(mock_cdp_client).to receive(:check_checkbox).with('#agree', true).and_return(mock_result)
          
          result = tools.execute_tool('check_checkbox', { 'selector' => '#agree', 'checked' => true })
          
          expect(result).to have_key(:content)
          expect(result[:content].first[:text]).to include('Successfully checked checkbox')
        end

        it 'unchecks checkbox successfully' do
          mock_result = { 'success' => true, 'selector' => '#newsletter', 'checked' => false, 'type' => 'checkbox' }
          expect(mock_cdp_client).to receive(:check_checkbox).with('#newsletter', false).and_return(mock_result)
          
          result = tools.execute_tool('check_checkbox', { 'selector' => '#newsletter', 'checked' => false })
          
          expect(result).to have_key(:content)
          expect(result[:content].first[:text]).to include('Successfully unchecked checkbox')
        end
      end
    end

    describe 'unknown tool' do
      it 'returns error for unknown tool' do
        result = tools.execute_tool('unknown_tool', {})
        
        expect(result).to have_key(:content)
        expect(result).to have_key(:isError)
        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to include('Unknown tool: unknown_tool')
      end
    end
  end
end