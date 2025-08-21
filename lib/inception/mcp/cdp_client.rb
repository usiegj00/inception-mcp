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

      def get_page_text_content
        js_expression = <<~JS
          (() => {
            // Remove scripts, styles, and hidden elements
            const elementsToRemove = document.querySelectorAll('script, style, noscript');
            const hiddenElements = document.querySelectorAll('[style*="display: none"], [style*="visibility: hidden"], .hidden');
            
            let cleanText = document.body.textContent || document.body.innerText || '';
            
            // Clean up whitespace
            cleanText = cleanText.replace(/\\s+/g, ' ').trim();
            
            return {
              title: document.title || '',
              url: window.location.href,
              textContent: cleanText,
              wordCount: cleanText.split(' ').length,
              characterCount: cleanText.length
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
          nil
        end
      end

      def get_structured_content
        js_expression = <<~JS
          (() => {
            const result = {
              title: document.title || '',
              url: window.location.href,
              headings: [],
              links: [],
              images: [],
              forms: [],
              lists: [],
              tables: []
            };

            // Extract headings
            document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(heading => {
              result.headings.push({
                level: parseInt(heading.tagName.charAt(1)),
                text: heading.textContent.trim(),
                id: heading.id || null
              });
            });

            // Extract links
            document.querySelectorAll('a[href]').forEach(link => {
              result.links.push({
                text: link.textContent.trim(),
                href: link.href,
                title: link.title || null
              });
            });

            // Extract images
            document.querySelectorAll('img').forEach(img => {
              result.images.push({
                src: img.src,
                alt: img.alt || '',
                title: img.title || null,
                width: img.width || null,
                height: img.height || null
              });
            });

            // Extract forms
            document.querySelectorAll('form').forEach(form => {
              const formData = {
                action: form.action || null,
                method: form.method || 'get',
                fields: []
              };
              
              form.querySelectorAll('input, select, textarea').forEach(field => {
                formData.fields.push({
                  type: field.type || field.tagName.toLowerCase(),
                  name: field.name || null,
                  id: field.id || null,
                  placeholder: field.placeholder || null,
                  required: field.required || false
                });
              });
              
              result.forms.push(formData);
            });

            // Extract lists
            document.querySelectorAll('ul, ol').forEach(list => {
              const items = Array.from(list.children).map(li => li.textContent.trim());
              result.lists.push({
                type: list.tagName.toLowerCase(),
                items: items
              });
            });

            // Extract tables
            document.querySelectorAll('table').forEach(table => {
              const headers = Array.from(table.querySelectorAll('th')).map(th => th.textContent.trim());
              const rows = Array.from(table.querySelectorAll('tr')).map(tr => {
                return Array.from(tr.querySelectorAll('td')).map(td => td.textContent.trim());
              }).filter(row => row.length > 0);
              
              result.tables.push({
                headers: headers,
                rows: rows
              });
            });

            return result;
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
        }, 15)
        
        if response && response['result'] && response['result']['result']
          response['result']['result']['value']
        else
          nil
        end
      end

      def get_page_metadata
        js_expression = <<~JS
          (() => {
            const meta = {
              title: document.title || '',
              url: window.location.href,
              description: '',
              keywords: '',
              author: '',
              viewport: '',
              charset: '',
              lang: document.documentElement.lang || '',
              openGraph: {},
              twitter: {}
            };

            // Extract meta tags
            document.querySelectorAll('meta').forEach(metaTag => {
              const name = metaTag.getAttribute('name');
              const property = metaTag.getAttribute('property');
              const content = metaTag.getAttribute('content') || '';

              if (name === 'description') meta.description = content;
              else if (name === 'keywords') meta.keywords = content;
              else if (name === 'author') meta.author = content;
              else if (name === 'viewport') meta.viewport = content;
              else if (metaTag.getAttribute('charset')) meta.charset = metaTag.getAttribute('charset');
              
              // Open Graph tags
              if (property && property.startsWith('og:')) {
                meta.openGraph[property.replace('og:', '')] = content;
              }
              
              // Twitter Card tags
              if (name && name.startsWith('twitter:')) {
                meta.twitter[name.replace('twitter:', '')] = content;
              }
            });

            return meta;
          })()
        JS

        response = send_command_and_wait('Runtime.evaluate', {
          expression: js_expression,
          returnByValue: true
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
            const selector = '#{selector.gsub("'", "\\'")}';
            let element;
            
            // Handle :contains() pseudo-selector (jQuery-style)
            if (selector.includes(':contains(')) {
              const match = selector.match(/(.+?):contains\\((['"]?)(.+?)\\2\\)/);
              if (match) {
                const baseSelector = match[1];
                const searchText = match[3];
                const elements = document.querySelectorAll(baseSelector);
                element = Array.from(elements).find(el => 
                  el.textContent && el.textContent.includes(searchText)
                );
              }
            } else {
              element = document.querySelector(selector);
            }
            
            if (!element) {
              return { error: 'Element not found', selector: selector };
            }
            
            const rect = element.getBoundingClientRect();
            if (rect.width === 0 || rect.height === 0) {
              return { error: 'Element not visible', selector: selector };
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
          
          # Handle case where result is nil or not a hash
          unless result.is_a?(Hash)
            return { error: 'JavaScript evaluation returned invalid result', selector: selector, result: result.inspect }
          end
          
          if result['success']
            # Click at the calculated coordinates
            click_element(result['x'], result['y'])
            result
          else
            result
          end
        else
          error_details = response&.dig('result', 'exceptionDetails')
          error_msg = error_details ? "JavaScript error: #{error_details['text']}" : 'Failed to evaluate selector'
          { error: error_msg, selector: selector }
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
          'ArrowRight' => 39,
          'Delete' => 46,
          'Home' => 36,
          'End' => 35,
          'PageUp' => 33,
          'PageDown' => 34,
          'F1' => 112, 'F2' => 113, 'F3' => 114, 'F4' => 115,
          'F5' => 116, 'F6' => 117, 'F7' => 118, 'F8' => 119,
          'F9' => 120, 'F10' => 121, 'F11' => 122, 'F12' => 123
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

      def press_key_combination(keys)
        # Support for key combinations like "Ctrl+C", "Ctrl+Shift+T", etc.
        key_parts = keys.split('+').map(&:strip)
        
        # Map modifier keys
        modifiers = {
          'Ctrl' => { key: 'Control', code: 17 },
          'Control' => { key: 'Control', code: 17 },
          'Shift' => { key: 'Shift', code: 16 },
          'Alt' => { key: 'Alt', code: 18 },
          'Meta' => { key: 'Meta', code: 91 },  # Cmd on Mac
          'Cmd' => { key: 'Meta', code: 91 }
        }
        
        # Separate modifiers from the main key
        modifier_keys = []
        main_key = key_parts.last
        
        key_parts[0..-2].each do |mod|
          if modifiers[mod]
            modifier_keys << modifiers[mod]
          end
        end
        
        # Press modifier keys down
        modifier_keys.each do |mod|
          send_command('Input.dispatchKeyEvent', {
            type: 'keyDown',
            key: mod[:key],
            code: mod[:key],
            keyCode: mod[:code]
          })
        end
        
        # Press main key
        main_code = get_key_code(main_key)
        send_command('Input.dispatchKeyEvent', {
          type: 'keyDown',
          key: main_key,
          keyCode: main_code
        })
        
        send_command('Input.dispatchKeyEvent', {
          type: 'keyUp',
          key: main_key,
          keyCode: main_code
        })
        
        # Release modifier keys
        modifier_keys.reverse.each do |mod|
          send_command('Input.dispatchKeyEvent', {
            type: 'keyUp',
            key: mod[:key],
            code: mod[:key],
            keyCode: mod[:code]
          })
        end
        
        { success: true, combination: keys }
      rescue => e
        { error: "Failed to press key combination: #{e.message}", combination: keys }
      end

      def send_text_with_shortcuts(text)
        # Send text that may contain shortcuts in curly braces like "Hello {Ctrl+A} world"
        parts = text.split(/(\{[^}]+\})/)
        
        parts.each do |part|
          if part.start_with?('{') && part.end_with?('}')
            # This is a shortcut
            shortcut = part[1..-2]  # Remove curly braces
            if shortcut.include?('+')
              press_key_combination(shortcut)
            else
              press_key(shortcut)
            end
          else
            # This is regular text
            type_text(part) unless part.empty?
          end
        end
        
        { success: true, text: text }
      end


      def scroll_page(direction, amount = nil)
        return { error: 'Not connected' } unless @connected
        
        scroll_script = case direction.downcase
        when 'up'
          amount ||= 300
          "window.scrollBy(0, -#{amount})"
        when 'down'
          amount ||= 300
          "window.scrollBy(0, #{amount})"
        when 'left'
          amount ||= 300
          "window.scrollBy(-#{amount}, 0)"
        when 'right'
          amount ||= 300
          "window.scrollBy(#{amount}, 0)"
        when 'top'
          "window.scrollTo(0, 0)"
        when 'bottom'
          "window.scrollTo(0, document.body.scrollHeight)"
        else
          return { error: "Invalid scroll direction: #{direction}. Use 'up', 'down', 'left', 'right', 'top', or 'bottom'" }
        end
        
        result = execute_script(scroll_script, false)
        
        if result['success']
          { success: true, direction: direction, amount: amount }
        else
          { error: 'Failed to scroll page', details: result['error'] }
        end
      end

      def scroll_to_element(selector)
        return { error: 'Not connected' } unless @connected
        
        scroll_script = <<~JS
          (() => {
            const element = document.querySelector('#{selector.gsub("'", "\\'")}');
            if (!element) {
              return { error: 'Element not found', selector: '#{selector.gsub("'", "\\'")}' };
            }
            
            element.scrollIntoView({ behavior: 'smooth', block: 'center' });
            
            // Wait a moment for smooth scrolling
            return new Promise(resolve => {
              setTimeout(() => {
                const rect = element.getBoundingClientRect();
                resolve({
                  success: true,
                  selector: '#{selector.gsub("'", "\\'")}',
                  x: Math.round(rect.left + rect.width / 2),
                  y: Math.round(rect.top + rect.height / 2),
                  visible: rect.top >= 0 && rect.top <= window.innerHeight
                });
              }, 500);
            });
          })()
        JS
        
        result = execute_script(scroll_script, true)
        
        if result['success'] && result['value']
          result['value']
        else
          { error: 'Failed to scroll to element', selector: selector }
        end
      end

      def scroll_to_coordinates(x, y)
        return { error: 'Not connected' } unless @connected
        
        scroll_script = "window.scrollTo(#{x}, #{y})"
        result = execute_script(scroll_script, false)
        
        if result['success']
          { success: true, x: x, y: y }
        else
          { error: 'Failed to scroll to coordinates', x: x, y: y }
        end
      end

      def get_scroll_position
        return { error: 'Not connected' } unless @connected
        
        scroll_script = <<~JS
          ({
            x: window.pageXOffset || document.documentElement.scrollLeft,
            y: window.pageYOffset || document.documentElement.scrollTop,
            maxX: document.documentElement.scrollWidth - document.documentElement.clientWidth,
            maxY: document.documentElement.scrollHeight - document.documentElement.clientHeight,
            viewportWidth: window.innerWidth,
            viewportHeight: window.innerHeight,
            pageWidth: document.documentElement.scrollWidth,
            pageHeight: document.documentElement.scrollHeight
          })
        JS
        
        result = execute_script(scroll_script, true)
        
        if result['success'] && result['value']
          { success: true }.merge(result['value'])
        else
          { error: 'Failed to get scroll position' }
        end
      end

      def smooth_scroll(direction, distance, duration = 500)
        return { error: 'Not connected' } unless @connected
        
        scroll_script = <<~JS
          (() => {
            const startX = window.pageXOffset;
            const startY = window.pageYOffset;
            
            let deltaX = 0, deltaY = 0;
            const distance = #{distance};
            
            switch('#{direction}'.toLowerCase()) {
              case 'up': deltaY = -distance; break;
              case 'down': deltaY = distance; break;
              case 'left': deltaX = -distance; break;
              case 'right': deltaX = distance; break;
              default: return { error: 'Invalid direction' };
            }
            
            const startTime = performance.now();
            const duration = #{duration};
            
            function animate(currentTime) {
              const elapsed = currentTime - startTime;
              const progress = Math.min(elapsed / duration, 1);
              
              // Easing function (ease-out)
              const easeOut = 1 - Math.pow(1 - progress, 3);
              
              window.scrollTo(
                startX + (deltaX * easeOut),
                startY + (deltaY * easeOut)
              );
              
              if (progress < 1) {
                requestAnimationFrame(animate);
              }
            }
            
            requestAnimationFrame(animate);
            
            return { 
              success: true, 
              direction: '#{direction}', 
              distance: distance,
              duration: duration 
            };
          })()
        JS
        
        result = execute_script(scroll_script, true)
        
        if result['success'] && result['value']
          result['value']
        else
          { error: 'Failed to perform smooth scroll', direction: direction }
        end
      end

      def resize_window(width, height)
        return { error: 'Not connected' } unless @connected
        
        # First get the current window bounds to maintain position
        current_bounds = get_window_bounds
        
        if current_bounds['success']
          # Set new window bounds with specified width and height
          new_bounds = {
            left: current_bounds['left'],
            top: current_bounds['top'],
            width: width,
            height: height,
            windowState: current_bounds['windowState']
          }
          
          result = send_command_and_wait('Browser.setWindowBounds', {
            windowId: get_window_id,
            bounds: new_bounds
          }, 5)
          
          if result && !result['error']
            {
              success: true,
              width: width,
              height: height,
              previous: {
                width: current_bounds['width'],
                height: current_bounds['height']
              }
            }
          else
            { error: 'Failed to resize window', details: result&.dig('error') }
          end
        else
          current_bounds
        end
      end

      def get_window_bounds
        return { error: 'Not connected' } unless @connected
        
        window_id = get_window_id
        result = send_command_and_wait('Browser.getWindowBounds', {
          windowId: window_id
        }, 5)
        
        if result && result['result'] && result['result']['bounds']
          bounds = result['result']['bounds']
          {
            success: true,
            left: bounds['left'],
            top: bounds['top'],
            width: bounds['width'],
            height: bounds['height'],
            windowState: bounds['windowState']
          }
        else
          { error: 'Failed to get window bounds' }
        end
      end

      def maximize_window
        return { error: 'Not connected' } unless @connected
        
        window_id = get_window_id
        result = send_command_and_wait('Browser.setWindowBounds', {
          windowId: window_id,
          bounds: { windowState: 'maximized' }
        }, 5)
        
        if result && !result['error']
          { success: true, state: 'maximized' }
        else
          { error: 'Failed to maximize window' }
        end
      end

      def minimize_window
        return { error: 'Not connected' } unless @connected
        
        window_id = get_window_id
        result = send_command_and_wait('Browser.setWindowBounds', {
          windowId: window_id,
          bounds: { windowState: 'minimized' }
        }, 5)
        
        if result && !result['error']
          { success: true, state: 'minimized' }
        else
          { error: 'Failed to minimize window' }
        end
      end

      def restore_window
        return { error: 'Not connected' } unless @connected
        
        window_id = get_window_id
        result = send_command_and_wait('Browser.setWindowBounds', {
          windowId: window_id,
          bounds: { windowState: 'normal' }
        }, 5)
        
        if result && !result['error']
          { success: true, state: 'normal' }
        else
          { error: 'Failed to restore window' }
        end
      end

      def set_window_position(x, y)
        return { error: 'Not connected' } unless @connected
        
        # Get current dimensions to preserve them
        current_bounds = get_window_bounds
        
        if current_bounds['success']
          new_bounds = {
            left: x,
            top: y,
            width: current_bounds['width'],
            height: current_bounds['height'],
            windowState: 'normal'
          }
          
          result = send_command_and_wait('Browser.setWindowBounds', {
            windowId: get_window_id,
            bounds: new_bounds
          }, 5)
          
          if result && !result['error']
            {
              success: true,
              x: x,
              y: y,
              previous: {
                x: current_bounds['left'],
                y: current_bounds['top']
              }
            }
          else
            { error: 'Failed to set window position' }
          end
        else
          current_bounds
        end
      end


      def get_window_id
        # Get the window ID for the current browser window
        # This is a simplified approach - in practice, you might need to track window IDs
        1 # Chrome typically uses window ID 1 for the main window
      end


      def get_key_code(key)
        key_codes = {
          'Enter' => 13, 'Backspace' => 8, 'Tab' => 9, 'Escape' => 27,
          'ArrowUp' => 38, 'ArrowDown' => 40, 'ArrowLeft' => 37, 'ArrowRight' => 39,
          'Delete' => 46, 'Home' => 36, 'End' => 35, 'PageUp' => 33, 'PageDown' => 34,
          'F1' => 112, 'F2' => 113, 'F3' => 114, 'F4' => 115,
          'F5' => 116, 'F6' => 117, 'F7' => 118, 'F8' => 119,
          'F9' => 120, 'F10' => 121, 'F11' => 122, 'F12' => 123,
          ' ' => 32, 'Space' => 32
        }
        
        # Handle single characters
        if key.length == 1
          return key.upcase.ord
        end
        
        key_codes[key] || key.ord
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

      def inject_script(script_content, world_name = nil)
        return { error: 'Not connected' } unless @connected
        
        params = {
          source: script_content,
          runImmediately: true
        }
        
        if world_name
          params[:worldName] = world_name
        end
        
        result = send_command_and_wait('Page.addScriptToEvaluateOnNewDocument', params, 10)
        
        if result && result['result']
          script_id = result['result']['identifier']
          # Also evaluate the script on the current page
          eval_result = send_command_and_wait('Runtime.evaluate', {
            expression: script_content,
            returnByValue: false,
            generatePreview: false
          }, 10)
          
          {
            success: true,
            script_id: script_id,
            injected: true,
            evaluated: eval_result && !eval_result['error']
          }
        else
          { error: 'Failed to inject script', details: result&.dig('error') }
        end
      end

      def remove_injected_script(script_id)
        return { error: 'Not connected' } unless @connected
        return { error: 'No script ID provided' } unless script_id
        
        result = send_command_and_wait('Page.removeScriptToEvaluateOnNewDocument', {
          identifier: script_id
        }, 5)
        
        if result && !result['error']
          { success: true, script_id: script_id }
        else
          { error: 'Failed to remove script', script_id: script_id }
        end
      end


      def execute_script(script_content, return_value = true)
        return { error: 'Not connected' } unless @connected
        
        result = send_command_and_wait('Runtime.evaluate', {
          expression: script_content,
          returnByValue: return_value,
          generatePreview: false,
          userGesture: true
        }, 15)
        
        if result && result['result']
          if result['result']['exceptionDetails']
            {
              error: 'Script execution error',
              exception: result['result']['exceptionDetails']['text'],
              line: result['result']['exceptionDetails']['lineNumber'],
              column: result['result']['exceptionDetails']['columnNumber']
            }
          else
            response_hash = {
              success: true,
              result: result['result']['result']
            }
            response_hash[:value] = result['result']['result']['value'] if return_value
            response_hash
          end
        else
          { error: 'Failed to execute script', details: result&.dig('error') }
        end
      end

      def capture_console_logs(enable = true)
        return { error: 'Not connected' } unless @connected
        
        if enable
          # Enable Runtime domain for console events
          result = send_command_and_wait('Runtime.enable', {}, 5)
          if result && !result['error']
            @console_logs = []
            { success: true, enabled: true }
          else
            { error: 'Failed to enable console logging' }
          end
        else
          @console_logs = nil
          { success: true, enabled: false }
        end
      end

      def get_console_logs(clear_after = false)
        logs = @console_logs || []
        @console_logs = [] if clear_after && @console_logs
        
        {
          success: true,
          logs: logs.map do |log|
            {
              level: log[:level],
              text: log[:text],
              timestamp: log[:timestamp],
              source: log[:source]
            }
          end,
          count: logs.length
        }
      end

      def create_script_bridge(bridge_name = 'InceptionBridge')
        bridge_script = <<~JS
          (function() {
            if (window.#{bridge_name}) return window.#{bridge_name};
            
            const bridge = {
              callbacks: {},
              nextId: 1,
              
              // Register a callback for communication from the injected script
              on: function(event, callback) {
                if (!this.callbacks[event]) this.callbacks[event] = [];
                this.callbacks[event].push(callback);
              },
              
              // Emit an event to all registered callbacks
              emit: function(event, data) {
                if (this.callbacks[event]) {
                  this.callbacks[event].forEach(callback => {
                    try {
                      callback(data);
                    } catch (e) {
                      console.error('Bridge callback error:', e);
                    }
                  });
                }
              },
              
              // Execute a function and return a promise
              execute: function(func, ...args) {
                return new Promise((resolve, reject) => {
                  try {
                    const result = func.apply(this, args);
                    resolve(result);
                  } catch (error) {
                    reject(error);
                  }
                });
              },
              
              // Get element information
              getElementInfo: function(selector) {
                const element = document.querySelector(selector);
                if (!element) return null;
                
                const rect = element.getBoundingClientRect();
                return {
                  tagName: element.tagName.toLowerCase(),
                  id: element.id,
                  className: element.className,
                  textContent: element.textContent.trim(),
                  value: element.value || '',
                  href: element.href || '',
                  src: element.src || '',
                  x: Math.round(rect.left + rect.width / 2),
                  y: Math.round(rect.top + rect.height / 2),
                  width: Math.round(rect.width),
                  height: Math.round(rect.height),
                  visible: rect.width > 0 && rect.height > 0
                };
              },
              
              // Wait for an element to appear
              waitForElement: function(selector, timeout = 5000) {
                return new Promise((resolve, reject) => {
                  const element = document.querySelector(selector);
                  if (element) {
                    resolve(this.getElementInfo(selector));
                    return;
                  }
                  
                  const observer = new MutationObserver((mutations) => {
                    const element = document.querySelector(selector);
                    if (element) {
                      observer.disconnect();
                      clearTimeout(timeoutId);
                      resolve(this.getElementInfo(selector));
                    }
                  });
                  
                  const timeoutId = setTimeout(() => {
                    observer.disconnect();
                    reject(new Error(`Element ${selector} not found within ${timeout}ms`));
                  }, timeout);
                  
                  observer.observe(document.body, {
                    childList: true,
                    subtree: true
                  });
                });
              },
              
              // Monitor page changes
              onPageChange: function(callback) {
                const observer = new MutationObserver((mutations) => {
                  callback({
                    type: 'mutation',
                    mutations: mutations.length,
                    url: window.location.href,
                    title: document.title
                  });
                });
                
                observer.observe(document.body, {
                  childList: true,
                  subtree: true,
                  attributes: true
                });
                
                // Also monitor URL changes
                let lastUrl = location.href;
                const urlObserver = setInterval(() => {
                  if (location.href !== lastUrl) {
                    lastUrl = location.href;
                    callback({
                      type: 'navigation',
                      url: location.href,
                      title: document.title
                    });
                  }
                }, 100);
                
                return () => {
                  observer.disconnect();
                  clearInterval(urlObserver);
                };
              }
            };
            
            window.#{bridge_name} = bridge;
            return bridge;
          })();
        JS

        result = execute_script(bridge_script, true)
        
        if result['success']
          { success: true, bridge_name: bridge_name, injected: true }
        else
          result
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
          console_text = params['args'].map { |arg| arg['value'] }.join(' ')
          STDERR.puts "Console: #{console_text}"
          
          # Store console log if capture is enabled
          if @console_logs
            @console_logs << {
              level: params['type'] || 'log',
              text: console_text,
              timestamp: params['timestamp'] || Time.now.to_f * 1000,
              source: 'console'
            }
          end
        when 'Runtime.exceptionThrown'
          exception_text = params.dig('exceptionDetails', 'text') || 'JavaScript error'
          STDERR.puts "JavaScript Exception: #{exception_text}"
          
          # Store exception if capture is enabled
          if @console_logs
            @console_logs << {
              level: 'error',
              text: "Exception: #{exception_text}",
              timestamp: params['timestamp'] || Time.now.to_f * 1000,
              source: 'exception'
            }
          end
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