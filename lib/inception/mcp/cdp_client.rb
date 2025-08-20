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
        @event_waiters = {}
        @response_cache = {}
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

      def send_command_and_wait(method, params = {}, timeout = 10)
        return nil unless @connected

        request_id = send_command(method, params)
        return nil unless request_id

        # Wait for response
        start_time = Time.now
        while Time.now - start_time < timeout
          if @response_cache[request_id]
            response = @response_cache.delete(request_id)
            return response
          end
          sleep(0.01)
        end

        # Cleanup on timeout
        @callbacks.delete(request_id)
        nil
      end

      def wait_for_event(event_name, timeout = 10)
        return nil unless @connected

        # Store the waiter
        waiter_id = "#{event_name}_#{Time.now.to_f}"
        @event_waiters[waiter_id] = { event: event_name, result: nil }

        # Wait for event
        start_time = Time.now
        while Time.now - start_time < timeout
          if @event_waiters[waiter_id][:result]
            result = @event_waiters[waiter_id][:result]
            @event_waiters.delete(waiter_id)
            return result
          end
          sleep(0.01)
        end

        # Cleanup on timeout
        @event_waiters.delete(waiter_id)
        nil
      end

      def navigate(url)
        # Send navigation command
        result = send_command_and_wait('Page.navigate', { url: url }, 5)
        return false unless result && !result['error']
        
        # Wait for page to load
        load_event = wait_for_event('Page.loadEventFired', 15)
        !!load_event
      end

      def take_screenshot(format: 'png', quality: 80)
        response = send_command_and_wait('Page.captureScreenshot', {
          format: format,
          quality: quality,
          captureBeyondViewport: false
        }, 10)
        
        if response && response['result'] && response['result']['data']
          response['result']['data']
        else
          nil
        end
      end

      def get_page_content
        response = send_command_and_wait('Runtime.evaluate', {
          expression: 'document.documentElement.outerHTML'
        }, 10)
        
        if response && response['result'] && response['result']['result']
          response['result']['result']['value']
        else
          nil
        end
      end

      def get_interactive_elements
        # JavaScript to find all interactive elements with their positions and metadata
        js_expression = <<~JS
          (() => {
            const interactiveSelectors = [
              'a[href]', 'button', 'input', 'select', 'textarea',
              '[onclick]', '[role="button"]', '[role="link"]', 
              '[tabindex]', 'details', 'summary'
            ];
            
            const elements = [];
            interactiveSelectors.forEach(selector => {
              document.querySelectorAll(selector).forEach(el => {
                const rect = el.getBoundingClientRect();
                const style = window.getComputedStyle(el);
                
                // Only include visible elements within viewport
                if (rect.width > 0 && rect.height > 0 && 
                    style.visibility !== 'hidden' && 
                    style.display !== 'none' &&
                    rect.top < window.innerHeight && 
                    rect.bottom > 0 &&
                    rect.left < window.innerWidth && 
                    rect.right > 0) {
                  
                  elements.push({
                    tagName: el.tagName.toLowerCase(),
                    selector: el.id ? `#${el.id}` : 
                             el.className ? `.${el.className.split(' ').join('.')}` :
                             el.tagName.toLowerCase(),
                    text: (el.textContent || el.value || el.placeholder || '').trim().substring(0, 100),
                    type: el.type || '',
                    href: el.href || '',
                    x: Math.round(rect.left + rect.width / 2),
                    y: Math.round(rect.top + rect.height / 2),
                    width: Math.round(rect.width),
                    height: Math.round(rect.height),
                    isClickable: true
                  });
                }
              });
            });
            
            return elements;
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
        }, 10)
        
        if response && response['result'] && response['result']['result']
          response['result']['result']['value'] || []
        else
          []
        end
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

      def click_element_by_selector(selector)
        # JavaScript to find element and get its center coordinates
        js_expression = <<~JS
          (() => {
            const element = document.querySelector('#{selector.gsub("'", "\\'")}');
            if (!element) {
              return { error: 'Element not found', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            const rect = element.getBoundingClientRect();
            if (rect.width === 0 || rect.height === 0) {
              return { error: 'Element not visible', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            return {
              success: true,
              x: Math.round(rect.left + rect.width / 2),
              y: Math.round(rect.top + rect.height / 2),
              tagName: element.tagName.toLowerCase(),
              text: (element.textContent || element.value || '').trim().substring(0, 50)
            };
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
        }, 10)
        
        if response && response['result'] && response['result']['result']
          result = response['result']['result']['value']
          
          if result['success']
            # Click at the calculated coordinates
            click_element(result['x'], result['y'])
            result
          else
            result
          end
        else
          { error: 'Failed to evaluate selector', selector: selector }
        end
      end

      def type_text(text)
        text.each_char do |char|
          send_command('Input.dispatchKeyEvent', {
            type: 'char',
            text: char
          })
        end
      end

      def fill_form_field(selector, value)
        # First focus on the element
        focus_result = focus_element(selector)
        return focus_result unless focus_result['success']
        
        # Clear existing content
        clear_result = clear_element(selector)
        return clear_result unless clear_result['success']
        
        # Type the new value
        type_text(value.to_s)
        
        { success: true, selector: selector, value: value.to_s }
      end

      def select_option(selector, value)
        js_expression = <<~JS
          (() => {
            const select = document.querySelector('#{selector.gsub("'", "\\'")}');
            if (!select) {
              return { error: 'Select element not found', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            if (select.tagName.toLowerCase() !== 'select') {
              return { error: 'Element is not a select', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            const value = '#{value.to_s.gsub("'", "\\'")}';
            let optionFound = false;
            
            // Try to find option by value first
            for (let option of select.options) {
              if (option.value === value) {
                select.selectedIndex = option.index;
                optionFound = true;
                break;
              }
            }
            
            // If not found by value, try by text content
            if (!optionFound) {
              for (let option of select.options) {
                if (option.textContent.trim() === value) {
                  select.selectedIndex = option.index;
                  optionFound = true;
                  break;
                }
              }
            }
            
            if (!optionFound) {
              return { error: 'Option not found', selector: '#{selector.gsub("'", "\\'")}', value: value };
            }
            
            // Trigger change event
            select.dispatchEvent(new Event('change', { bubbles: true }));
            
            return { 
              success: true, 
              selector: '#{selector.gsub("'", "\\'")}', 
              selectedValue: select.value,
              selectedText: select.options[select.selectedIndex].textContent.trim()
            };
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
        }, 10)
        
        if response && response['result'] && response['result']['result']
          response['result']['result']['value']
        else
          { error: 'Failed to evaluate select operation', selector: selector }
        end
      end

      def check_checkbox(selector, checked = true)
        js_expression = <<~JS
          (() => {
            const element = document.querySelector('#{selector.gsub("'", "\\'")}');
            if (!element) {
              return { error: 'Checkbox element not found', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            const inputType = element.type ? element.type.toLowerCase() : '';
            if (inputType !== 'checkbox' && inputType !== 'radio') {
              return { error: 'Element is not a checkbox or radio button', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            const shouldBeChecked = #{checked};
            if (element.checked !== shouldBeChecked) {
              element.checked = shouldBeChecked;
              element.dispatchEvent(new Event('change', { bubbles: true }));
            }
            
            return { 
              success: true, 
              selector: '#{selector.gsub("'", "\\'")}', 
              checked: element.checked,
              type: inputType
            };
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
        }, 10)
        
        if response && response['result'] && response['result']['result']
          response['result']['result']['value']
        else
          { error: 'Failed to evaluate checkbox operation', selector: selector }
        end
      end

      private

      def focus_element(selector)
        js_expression = <<~JS
          (() => {
            const element = document.querySelector('#{selector.gsub("'", "\\'")}');
            if (!element) {
              return { error: 'Element not found', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            element.focus();
            return { success: true, selector: '#{selector.gsub("'", "\\'")}' };
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
        }, 10)
        
        if response && response['result'] && response['result']['result']
          response['result']['result']['value']
        else
          { error: 'Failed to focus element', selector: selector }
        end
      end

      def clear_element(selector)
        js_expression = <<~JS
          (() => {
            const element = document.querySelector('#{selector.gsub("'", "\\'")}');
            if (!element) {
              return { error: 'Element not found', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            if (element.tagName.toLowerCase() === 'input' || element.tagName.toLowerCase() === 'textarea') {
              element.value = '';
              element.dispatchEvent(new Event('input', { bubbles: true }));
              return { success: true, selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            return { error: 'Element is not a text input', selector: '#{selector.gsub("'", "\\'")}' };
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
        }, 10)
        
        if response && response['result'] && response['result']['result']
          response['result']['result']['value']
        else
          { error: 'Failed to clear element', selector: selector }
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

      def get_all_windows_and_tabs
        # Get all tabs/windows from the browser
        response = http_get('/json/list')
        return [] unless response

        begin
          tabs_data = JSON.parse(response)
          
          # Group tabs by window and format the data
          result = []
          current_window = nil
          
          tabs_data.each do |tab_info|
            next unless tab_info['type'] == 'page'
            
            # Create window grouping (simplified - Chrome CDP doesn't directly provide window info)
            window_id = tab_info['id'].split('-').first || 'window-1'
            
            # Find or create window entry
            window = result.find { |w| w[:window_id] == window_id }
            unless window
              window = {
                window_id: window_id,
                tabs: []
              }
              result << window
            end
            
            # Add tab info
            window[:tabs] << {
              tab_id: tab_info['id'],
              title: tab_info['title'] || '',
              url: tab_info['url'] || '',
              favicon: tab_info['faviconUrl'] || '',
              active: tab_info['id'] == @tabs&.first&.dig('id')
            }
          end
          
          result
        rescue JSON::ParserError => e
          STDERR.puts "Error parsing windows/tabs response: #{e.message}"
          []
        end
      end

      def create_new_tab(url = 'about:blank')
        # Create a new tab
        response = http_get("/json/new?#{url}")
        return nil unless response

        begin
          tab_info = JSON.parse(response)
          {
            success: true,
            tab_id: tab_info['id'],
            title: tab_info['title'] || '',
            url: tab_info['url'] || url
          }
        rescue JSON::ParserError => e
          STDERR.puts "Error creating new tab: #{e.message}"
          { error: 'Failed to create new tab', details: e.message }
        end
      end

      def close_tab(tab_id)
        # Close a specific tab
        response = http_get("/json/close/#{tab_id}")
        
        if response == 'Target is closing'
          { success: true, tab_id: tab_id }
        else
          { error: 'Failed to close tab', tab_id: tab_id }
        end
      end

      def switch_to_tab(tab_id)
        # Switch to a different tab by connecting to it
        tabs_list = get_tabs_info
        target_tab = tabs_list.find { |tab| tab[:id] == tab_id }
        
        return { error: 'Tab not found', tab_id: tab_id } unless target_tab
        
        # Close current connection
        disconnect if @connected
        
        # Get the WebSocket URL for the target tab
        response = http_get('/json/list')
        return { error: 'Failed to get tab list' } unless response
        
        begin
          tabs_data = JSON.parse(response)
          target_tab_data = tabs_data.find { |tab| tab['id'] == tab_id }
          
          return { error: 'Target tab not found in list' } unless target_tab_data
          
          # Connect to the new tab
          if connect_to_tab(target_tab_data['webSocketDebuggerUrl'])
            { success: true, tab_id: tab_id, title: target_tab_data['title'], url: target_tab_data['url'] }
          else
            { error: 'Failed to connect to tab', tab_id: tab_id }
          end
        rescue JSON::ParserError => e
          { error: 'Failed to parse tab data', details: e.message }
        end
      end

      def navigate_back
        return { error: 'Not connected' } unless @connected
        
        result = send_command_and_wait('Page.navigateToHistoryEntry', { entryId: -1 }, 5)
        if result && !result['error']
          { success: true }
        else
          { error: 'Navigation back failed' }
        end
      end

      def navigate_forward
        return { error: 'Not connected' } unless @connected
        
        result = send_command_and_wait('Page.navigateToHistoryEntry', { entryId: 1 }, 5)
        if result && !result['error']
          { success: true }
        else
          { error: 'Navigation forward failed' }
        end
      end

      def reload_page(ignore_cache = false)
        return { error: 'Not connected' } unless @connected
        
        result = send_command_and_wait('Page.reload', { ignoreCache: ignore_cache }, 10)
        if result && !result['error']
          { success: true }
        else
          { error: 'Page reload failed' }
        end
      end

      private

      def discover_tabs
        response = http_get('/json/list')
        return unless response

        @tabs = JSON.parse(response).select { |tab| tab['type'] == 'page' }
      rescue JSON::ParserError => e
        STDERR.puts "Error parsing tabs response: #{e.message}"
        @tabs = []
      end

      def connect_to_tab(ws_url)
        return false unless ws_url

        @ws = WebSocket::Client::Simple.connect(ws_url)
        cdp_client = self

        @ws.on :open do
          STDERR.puts "WebSocket opened"
          cdp_client.instance_variable_set(:@connected, true)
          STDERR.puts "Connected to CDP WebSocket"
          
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
            STDERR.puts "Error parsing WebSocket message: #{e.message}"
          end
        end

        @ws.on :close do
          cdp_client.instance_variable_set(:@connected, false)
          STDERR.puts "CDP WebSocket connection closed"
        end

        @ws.on :error do |e|
          STDERR.puts "CDP WebSocket error: #{e.message}"
          cdp_client.instance_variable_set(:@connected, false)
        end

        # Wait for connection to establish
        timeout = 5.0  # 5 seconds timeout
        start_time = Time.now
        
        while !@connected && (Time.now - start_time) < timeout
          sleep(0.1)
        end
        
        STDERR.puts "Connection status after wait: #{@connected}"
        @connected
      end

      def handle_message(data)
        # Handle CDP protocol messages
        if data['id']
          # Response to our command
          request_id = data['id']
          @response_cache[request_id] = data
          
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

        # Notify any waiters for this event
        @event_waiters.each do |waiter_id, waiter|
          if waiter[:event] == method
            waiter[:result] = data
          end
        end

        case method
        when 'Page.loadEventFired'
          STDERR.puts "Page loaded"
        when 'Runtime.consoleAPICalled'
          STDERR.puts "Console: #{params['args'].map { |arg| arg['value'] }.join(' ')}"
        end
      end

      def http_get(path)
        uri = URI("#{@cdp_base_url}#{path}")
        response = Net::HTTP.get_response(uri)
        response.code == '200' ? response.body : nil
      rescue => e
        STDERR.puts "HTTP request failed: #{e.message}"
        nil
      end
    end
  end
end