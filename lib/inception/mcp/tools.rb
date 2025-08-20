# frozen_string_literal: true

module Inception
  module MCP
    class Tools
      def initialize(cdp_client)
        @cdp = cdp_client
      end

      def tool_definitions
        [
          {
            name: "navigate_browser",
            title: "Navigate Browser",
            description: "Navigate the Inception-controlled browser to a specific URL. Allows AI to direct web browsing to any website for research, testing, or interaction.",
            inputSchema: {
              type: "object",
              properties: {
                url: {
                  type: "string",
                  description: "The target URL to navigate to (must include protocol, e.g., https://example.com)",
                  examples: ["https://google.com", "https://github.com", "file:///local/path.html"]
                }
              },
              required: ["url"]
            }
          },
          {
            name: "take_screenshot", 
            title: "Capture Screenshot",
            description: "Capture a screenshot of the current viewport in the browser window. Useful for visual verification, documentation, or debugging web applications.",
            inputSchema: {
              type: "object",
              properties: {
                format: {
                  type: "string",
                  enum: ["png", "jpeg"],
                  description: "Image format for the screenshot",
                  default: "png"
                },
                quality: {
                  type: "number",
                  minimum: 0,
                  maximum: 100,
                  description: "Image quality (0-100, only applies to JPEG format)",
                  default: 80
                }
              },
              additionalProperties: false
            }
          },
          {
            name: "click_element",
            title: "Click Element",
            description: "Perform a mouse click either at specific pixel coordinates or using a CSS selector. CSS selectors are more reliable for automation. Use after taking screenshots or getting interactive elements.",
            inputSchema: {
              type: "object", 
              properties: {
                x: {
                  type: "number",
                  minimum: 0,
                  description: "X coordinate in pixels from the left edge of the viewport"
                },
                y: {
                  type: "number",
                  minimum: 0,
                  description: "Y coordinate in pixels from the top edge of the viewport"
                },
                selector: {
                  type: "string",
                  description: "CSS selector to find and click the element (e.g., '#button-id', '.class-name', 'button[type=\"submit\"]')"
                }
              },
              additionalProperties: false
            }
          },
          {
            name: "type_text",
            title: "Type Text Input",
            description: "Type text into the currently focused input field, textarea, or editable element. Simulates keyboard text entry for form filling, search queries, or content editing.",
            inputSchema: {
              type: "object",
              properties: {
                text: {
                  type: "string",
                  description: "The text string to type into the focused element",
                  minLength: 1
                }
              },
              required: ["text"],
              additionalProperties: false
            }
          },
          {
            name: "press_key",
            title: "Press Keyboard Key",
            description: "Send a specific keyboard key press event to the browser. Useful for navigation, form submission, and keyboard shortcuts.",
            inputSchema: {
              type: "object",
              properties: {
                key: {
                  type: "string", 
                  description: "The key to press. Supports special keys and regular characters.",
                  enum: ["Enter", "Backspace", "Tab", "Escape", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Delete", "Home", "End", "PageUp", "PageDown", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"],
                  examples: ["Enter", "Tab", "Escape", "ArrowDown"]
                }
              },
              required: ["key"],
              additionalProperties: false
            }
          },
          {
            name: "press_key_combination",
            title: "Press Key Combination",
            description: "Send keyboard shortcut combinations like Ctrl+C, Ctrl+Shift+T, etc. Supports modifier keys and complex shortcuts.",
            inputSchema: {
              type: "object",
              properties: {
                keys: {
                  type: "string",
                  description: "Key combination like 'Ctrl+C', 'Ctrl+Shift+T', 'Alt+F4', 'Cmd+R' (use + to separate keys)",
                  examples: ["Ctrl+C", "Ctrl+V", "Ctrl+Shift+T", "Alt+F4", "Cmd+R"]
                }
              },
              required: ["keys"],
              additionalProperties: false
            }
          },
          {
            name: "send_text_with_shortcuts",
            title: "Send Text with Shortcuts",
            description: "Send text that may contain embedded keyboard shortcuts in curly braces. Example: 'Hello {Ctrl+A} World {Enter}'",
            inputSchema: {
              type: "object",
              properties: {
                text: {
                  type: "string",
                  description: "Text with optional shortcuts in curly braces like 'Hello {Ctrl+A} World {Enter}'"
                }
              },
              required: ["text"],
              additionalProperties: false
            }
          },
          {
            name: "get_page_content",
            title: "Extract Page Content",
            description: "Extract the complete HTML source code of the currently loaded page. Useful for content analysis, scraping, debugging, or understanding page structure.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "get_page_info",
            title: "Get Page Information",
            description: "Retrieve metadata about the current page including title, URL, and other properties. Helpful for understanding the current browser state and page context.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "get_page_text",
            title: "Get Page Text Content",
            description: "Extract clean text content from the page, removing scripts, styles, and hidden elements. Returns text with word/character counts.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "get_structured_content",
            title: "Get Structured Page Content",
            description: "Extract structured content including headings, links, images, forms, lists, and tables. Useful for content analysis and understanding page structure.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "get_page_metadata",
            title: "Get Page Metadata",
            description: "Extract page metadata including title, description, keywords, Open Graph data, Twitter Cards, and other meta information.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "get_interactive_elements",
            title: "Get Interactive Elements",
            description: "Find all interactive elements on the current page with their positions, selectors, and metadata. Useful for identifying clickable elements, forms, and buttons for automation.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "fill_form_field",
            title: "Fill Form Field",
            description: "Fill a form input field, textarea, or other editable element with text. Automatically focuses the element and clears existing content before typing.",
            inputSchema: {
              type: "object",
              properties: {
                selector: {
                  type: "string",
                  description: "CSS selector for the form field to fill (e.g., '#email-input', 'input[name=\"username\"]')"
                },
                value: {
                  type: "string", 
                  description: "The text value to enter into the field"
                }
              },
              required: ["selector", "value"],
              additionalProperties: false
            }
          },
          {
            name: "select_option",
            title: "Select Dropdown Option",
            description: "Select an option from a dropdown/select element. Can select by option value or visible text.",
            inputSchema: {
              type: "object",
              properties: {
                selector: {
                  type: "string",
                  description: "CSS selector for the select element (e.g., '#country-select', 'select[name=\"category\"]')"
                },
                value: {
                  type: "string",
                  description: "The option value or visible text to select"
                }
              },
              required: ["selector", "value"],
              additionalProperties: false
            }
          },
          {
            name: "check_checkbox",
            title: "Check/Uncheck Checkbox",
            description: "Check or uncheck a checkbox or radio button element.",
            inputSchema: {
              type: "object", 
              properties: {
                selector: {
                  type: "string",
                  description: "CSS selector for the checkbox or radio button (e.g., '#agree-terms', 'input[name=\"newsletter\"]')"
                },
                checked: {
                  type: "boolean",
                  description: "Whether to check (true) or uncheck (false) the element",
                  default: true
                }
              },
              required: ["selector"],
              additionalProperties: false
            }
          },
          {
            name: "get_windows_and_tabs",
            title: "Get Browser Windows and Tabs",
            description: "List all browser windows and their tabs with metadata including titles, URLs, and active status.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "create_new_tab",
            title: "Create New Tab",
            description: "Create a new browser tab, optionally with a specific URL.",
            inputSchema: {
              type: "object",
              properties: {
                url: {
                  type: "string",
                  description: "URL to open in the new tab (optional, defaults to blank page)",
                  default: "about:blank"
                }
              },
              additionalProperties: false
            }
          },
          {
            name: "close_tab",
            title: "Close Tab",
            description: "Close a specific browser tab by its ID.",
            inputSchema: {
              type: "object",
              properties: {
                tab_id: {
                  type: "string",
                  description: "The ID of the tab to close"
                }
              },
              required: ["tab_id"],
              additionalProperties: false
            }
          },
          {
            name: "switch_to_tab",
            title: "Switch to Tab",
            description: "Switch the active browser context to a different tab.",
            inputSchema: {
              type: "object",
              properties: {
                tab_id: {
                  type: "string",
                  description: "The ID of the tab to switch to"
                }
              },
              required: ["tab_id"],
              additionalProperties: false
            }
          },
          {
            name: "navigate_back",
            title: "Navigate Back",
            description: "Navigate back in the browser history.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "navigate_forward",
            title: "Navigate Forward",
            description: "Navigate forward in the browser history.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "reload_page",
            title: "Reload Page",
            description: "Reload the current page, optionally bypassing cache.",
            inputSchema: {
              type: "object",
              properties: {
                ignore_cache: {
                  type: "boolean",
                  description: "Whether to bypass the cache when reloading",
                  default: false
                }
              },
              additionalProperties: false
            }
          },
          {
            name: "inject_script",
            title: "Inject Script",
            description: "Inject JavaScript code into the page that will run on current and future page loads. Useful for adding custom functionality or monitoring.",
            inputSchema: {
              type: "object",
              properties: {
                script: {
                  type: "string",
                  description: "JavaScript code to inject into the page"
                },
                world_name: {
                  type: "string",
                  description: "Optional isolated world name for script execution (for security)"
                }
              },
              required: ["script"],
              additionalProperties: false
            }
          },
          {
            name: "execute_script", 
            title: "Execute Script",
            description: "Execute JavaScript code in the current page context and optionally return the result. Useful for dynamic page manipulation and data extraction.",
            inputSchema: {
              type: "object",
              properties: {
                script: {
                  type: "string",
                  description: "JavaScript code to execute"
                },
                return_value: {
                  type: "boolean",
                  description: "Whether to return the script's result value",
                  default: true
                }
              },
              required: ["script"],
              additionalProperties: false
            }
          },
          {
            name: "create_script_bridge",
            title: "Create Script Bridge",
            description: "Create a JavaScript bridge object with utility functions for advanced page interaction, element waiting, and change monitoring.",
            inputSchema: {
              type: "object",
              properties: {
                bridge_name: {
                  type: "string",
                  description: "Name for the bridge object (default: InceptionBridge)",
                  default: "InceptionBridge"
                }
              },
              additionalProperties: false
            }
          },
          {
            name: "capture_console",
            title: "Capture Console Output",
            description: "Enable or disable capturing of browser console logs and JavaScript exceptions for debugging and monitoring.",
            inputSchema: {
              type: "object",
              properties: {
                enable: {
                  type: "boolean",
                  description: "Whether to enable or disable console capture",
                  default: true
                }
              },
              additionalProperties: false
            }
          },
          {
            name: "get_console_logs",
            title: "Get Console Logs",
            description: "Retrieve captured console logs and exceptions. Useful for debugging JavaScript issues and monitoring page behavior.",
            inputSchema: {
              type: "object",
              properties: {
                clear_after: {
                  type: "boolean", 
                  description: "Whether to clear the log buffer after retrieval",
                  default: false
                }
              },
              additionalProperties: false
            }
          },
          {
            name: "scroll_page",
            title: "Scroll Page",
            description: "Scroll the page in a specified direction by a given amount, or scroll to top/bottom.",
            inputSchema: {
              type: "object",
              properties: {
                direction: {
                  type: "string",
                  enum: ["up", "down", "left", "right", "top", "bottom"],
                  description: "Direction to scroll"
                },
                amount: {
                  type: "number",
                  description: "Pixels to scroll (optional, defaults to 300 for directional scrolls)",
                  minimum: 1
                }
              },
              required: ["direction"],
              additionalProperties: false
            }
          },
          {
            name: "scroll_to_element",
            title: "Scroll to Element", 
            description: "Scroll to bring a specific element into view, centered in the viewport.",
            inputSchema: {
              type: "object",
              properties: {
                selector: {
                  type: "string",
                  description: "CSS selector for the element to scroll to"
                }
              },
              required: ["selector"],
              additionalProperties: false
            }
          },
          {
            name: "scroll_to_coordinates",
            title: "Scroll to Coordinates",
            description: "Scroll to specific x,y coordinates on the page.",
            inputSchema: {
              type: "object", 
              properties: {
                x: {
                  type: "number",
                  description: "X coordinate to scroll to",
                  minimum: 0
                },
                y: {
                  type: "number", 
                  description: "Y coordinate to scroll to",
                  minimum: 0
                }
              },
              required: ["x", "y"],
              additionalProperties: false
            }
          },
          {
            name: "get_scroll_position",
            title: "Get Scroll Position",
            description: "Get the current scroll position and page dimensions. Useful for understanding viewport context.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "smooth_scroll",
            title: "Smooth Scroll",
            description: "Perform a smooth animated scroll in the specified direction with custom duration.",
            inputSchema: {
              type: "object",
              properties: {
                direction: {
                  type: "string",
                  enum: ["up", "down", "left", "right"],
                  description: "Direction to scroll smoothly"
                },
                distance: {
                  type: "number",
                  description: "Distance in pixels to scroll",
                  minimum: 1
                },
                duration: {
                  type: "number",
                  description: "Animation duration in milliseconds (default: 500)",
                  minimum: 100,
                  maximum: 3000,
                  default: 500
                }
              },
              required: ["direction", "distance"],
              additionalProperties: false
            }
          },
          {
            name: "resize_window",
            title: "Resize Browser Window",
            description: "Resize the browser window to specific width and height dimensions. Maintains current window position.",
            inputSchema: {
              type: "object",
              properties: {
                width: {
                  type: "number",
                  minimum: 100,
                  description: "New window width in pixels"
                },
                height: {
                  type: "number",
                  minimum: 100,
                  description: "New window height in pixels"
                }
              },
              required: ["width", "height"],
              additionalProperties: false
            }
          },
          {
            name: "maximize_window",
            title: "Maximize Browser Window",
            description: "Maximize the browser window to full screen size.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "minimize_window",
            title: "Minimize Browser Window",
            description: "Minimize the browser window.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "restore_window",
            title: "Restore Browser Window",
            description: "Restore the browser window from maximized or minimized state to normal size.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "get_window_bounds",
            title: "Get Window Bounds",
            description: "Get the current browser window position, size, and state information.",
            inputSchema: {
              type: "object",
              properties: {},
              additionalProperties: false
            }
          },
          {
            name: "set_window_position",
            title: "Set Window Position",
            description: "Move the browser window to specific screen coordinates.",
            inputSchema: {
              type: "object",
              properties: {
                x: {
                  type: "number",
                  minimum: 0,
                  description: "X position in pixels from left edge of screen"
                },
                y: {
                  type: "number",
                  minimum: 0,
                  description: "Y position in pixels from top edge of screen"
                }
              },
              required: ["x", "y"],
              additionalProperties: false
            }
          }
        ]
      end

      def execute_tool(name, arguments)
        case name
        when "navigate_browser"
          url = arguments["url"]
          success = @cdp.navigate(url)
          
          if success
            {
              content: [
                {
                  type: "text",
                  text: "Successfully navigated to #{url} and page finished loading"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to navigate to #{url} - page may not have loaded properly"
                }
              ],
              isError: true
            }
          end

        when "take_screenshot"
          format = arguments["format"] || "png"
          quality = arguments["quality"] || 80
          
          image_data = @cdp.take_screenshot(format: format, quality: quality)
          
          if image_data
            {
              content: [
                {
                  type: "image",
                  data: image_data,
                  mimeType: format == "png" ? "image/png" : "image/jpeg"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to capture screenshot - browser may not be ready or page not loaded"
                }
              ],
              isError: true
            }
          end

        when "click_element"
          if arguments["selector"]
            selector = arguments["selector"]
            result = @cdp.click_element_by_selector(selector)
            
            if result["success"]
              {
                content: [
                  {
                    type: "text",
                    text: "Successfully clicked element '#{selector}' (#{result['tagName']}) at coordinates (#{result['x']}, #{result['y']})"
                  }
                ]
              }
            else
              {
                content: [
                  {
                    type: "text",
                    text: "Failed to click element '#{selector}': #{result['error']}"
                  }
                ],
                isError: true
              }
            end
          else
            x = arguments["x"]
            y = arguments["y"]
            
            if x && y
              @cdp.click_element(x, y)
              
              {
                content: [
                  {
                    type: "text",
                    text: "Click sent to coordinates (#{x}, #{y})"
                  }
                ]
              }
            else
              {
                content: [
                  {
                    type: "text", 
                    text: "Either provide coordinates (x, y) or a CSS selector for clicking"
                  }
                ],
                isError: true
              }
            end
          end

        when "type_text"
          text = arguments["text"]
          @cdp.type_text(text)
          
          {
            content: [
              {
                type: "text",
                text: "Typed: #{text}"
              }
            ]
          }

        when "press_key" 
          key = arguments["key"]
          @cdp.press_key(key)
          
          {
            content: [
              {
                type: "text",
                text: "Pressed key: #{key}"
              }
            ]
          }

        when "press_key_combination"
          keys = arguments["keys"]
          result = @cdp.press_key_combination(keys)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully pressed key combination: #{result['combination']}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to press key combination '#{keys}': #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "send_text_with_shortcuts"
          text = arguments["text"]
          result = @cdp.send_text_with_shortcuts(text)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully sent text with shortcuts: #{result['text']}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to send text with shortcuts: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "get_page_content"
          html_content = @cdp.get_page_content
          
          if html_content
            {
              content: [
                {
                  type: "text",
                  text: "HTML Content:\n#{html_content}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to retrieve page content"
                }
              ],
              isError: true
            }
          end

        when "get_page_info"
          tabs = @cdp.get_tabs_info
          current_tab = tabs.first # Simplified - would need to track active tab
          
          if current_tab
            {
              content: [
                {
                  type: "text",
                  text: "Page Info:\nTitle: #{current_tab[:title]}\nURL: #{current_tab[:url]}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "No page information available"
                }
              ]
            }
          end

        when "get_page_text"
          text_data = @cdp.get_page_text_content
          
          if text_data
            {
              content: [
                {
                  type: "text",
                  text: "Page Text Content:\nTitle: #{text_data['title']}\nURL: #{text_data['url']}\nWord Count: #{text_data['wordCount']}\nCharacter Count: #{text_data['characterCount']}\n\nContent:\n#{text_data['textContent']}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to extract page text content"
                }
              ],
              isError: true
            }
          end

        when "get_structured_content"
          content_data = @cdp.get_structured_content
          
          if content_data
            output_text = "Structured Content Analysis:\n\n"
            output_text += "Title: #{content_data['title']}\n"
            output_text += "URL: #{content_data['url']}\n\n"
            
            if content_data['headings'].any?
              output_text += "Headings (#{content_data['headings'].length}):\n"
              content_data['headings'].each do |heading|
                output_text += "  H#{heading['level']}: #{heading['text']}\n"
              end
              output_text += "\n"
            end
            
            if content_data['links'].any?
              output_text += "Links (#{content_data['links'].length}):\n"
              content_data['links'].first(10).each do |link|
                output_text += "  #{link['text']} -> #{link['href']}\n"
              end
              output_text += "  ... (showing first 10)\n\n" if content_data['links'].length > 10
            end
            
            if content_data['images'].any?
              output_text += "Images (#{content_data['images'].length}):\n"
              content_data['images'].first(5).each do |img|
                output_text += "  #{img['alt']} (#{img['src']})\n"
              end
              output_text += "  ... (showing first 5)\n\n" if content_data['images'].length > 5
            end
            
            if content_data['forms'].any?
              output_text += "Forms (#{content_data['forms'].length}):\n"
              content_data['forms'].each do |form|
                output_text += "  Action: #{form['action'] || 'N/A'} (#{form['method']})\n"
                output_text += "  Fields: #{form['fields'].length}\n"
              end
              output_text += "\n"
            end
            
            if content_data['lists'].any?
              output_text += "Lists (#{content_data['lists'].length}): #{content_data['lists'].map{|l| l['type']}.join(', ')}\n\n"
            end
            
            if content_data['tables'].any?
              output_text += "Tables (#{content_data['tables'].length}):\n"
              content_data['tables'].each_with_index do |table, i|
                output_text += "  Table #{i+1}: #{table['headers'].length} columns, #{table['rows'].length} rows\n"
              end
            end

            {
              content: [
                {
                  type: "text",
                  text: output_text
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to extract structured content"
                }
              ],
              isError: true
            }
          end

        when "get_page_metadata"
          metadata = @cdp.get_page_metadata
          
          if metadata
            output_text = "Page Metadata:\n\n"
            output_text += "Title: #{metadata['title']}\n"
            output_text += "URL: #{metadata['url']}\n"
            output_text += "Description: #{metadata['description']}\n" unless metadata['description'].empty?
            output_text += "Keywords: #{metadata['keywords']}\n" unless metadata['keywords'].empty?
            output_text += "Author: #{metadata['author']}\n" unless metadata['author'].empty?
            output_text += "Language: #{metadata['lang']}\n" unless metadata['lang'].empty?
            output_text += "Viewport: #{metadata['viewport']}\n" unless metadata['viewport'].empty?
            output_text += "Charset: #{metadata['charset']}\n" unless metadata['charset'].empty?
            
            if metadata['openGraph'] && metadata['openGraph'].any?
              output_text += "\nOpen Graph Data:\n"
              metadata['openGraph'].each do |key, value|
                output_text += "  og:#{key}: #{value}\n"
              end
            end
            
            if metadata['twitter'] && metadata['twitter'].any?
              output_text += "\nTwitter Card Data:\n"
              metadata['twitter'].each do |key, value|
                output_text += "  twitter:#{key}: #{value}\n"
              end
            end

            {
              content: [
                {
                  type: "text",
                  text: output_text
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to extract page metadata"
                }
              ],
              isError: true
            }
          end

        when "get_interactive_elements"
          elements = @cdp.get_interactive_elements
          
          if elements && elements.any?
            elements_text = elements.map.with_index do |element, index|
              "#{index + 1}. #{element['tagName'].upcase}"
              extra_info = []
              extra_info << "ID: #{element['selector']}" if element['selector'].start_with?('#')
              extra_info << "Text: #{element['text']}" unless element['text'].nil? || element['text'].empty?
              extra_info << "Type: #{element['type']}" unless element['type'].nil? || element['type'].empty?
              extra_info << "Position: (#{element['x']}, #{element['y']})"
              extra_info << "Size: #{element['width']}x#{element['height']}"
              
              base_text = "#{index + 1}. #{element['tagName'].upcase}"
              base_text += " - #{extra_info.join(', ')}" unless extra_info.empty?
              base_text
            end.join("\n")

            {
              content: [
                {
                  type: "text",
                  text: "Interactive Elements Found:\n#{elements_text}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "No interactive elements found on the current page"
                }
              ]
            }
          end

        when "fill_form_field"
          selector = arguments["selector"]
          value = arguments["value"]
          result = @cdp.fill_form_field(selector, value)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully filled form field '#{selector}' with: #{result['value']}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to fill form field '#{selector}': #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "select_option"
          selector = arguments["selector"]
          value = arguments["value"]
          result = @cdp.select_option(selector, value)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully selected '#{result['selectedText']}' (value: #{result['selectedValue']}) in '#{selector}'"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to select option in '#{selector}': #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "check_checkbox"
          selector = arguments["selector"]
          checked = arguments.fetch("checked", true)
          result = @cdp.check_checkbox(selector, checked)
          
          if result["success"]
            action = result["checked"] ? "checked" : "unchecked"
            {
              content: [
                {
                  type: "text",
                  text: "Successfully #{action} #{result['type']} '#{selector}'"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to modify #{selector}: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "get_windows_and_tabs"
          windows_data = @cdp.get_all_windows_and_tabs
          
          if windows_data && windows_data.any?
            output_text = "Browser Windows and Tabs:\n"
            
            windows_data.each_with_index do |window, win_idx|
              output_text += "\nWindow #{win_idx + 1} (ID: #{window[:window_id]}):\n"
              
              window[:tabs].each_with_index do |tab, tab_idx|
                status = tab[:active] ? " [ACTIVE]" : ""
                output_text += "  #{tab_idx + 1}. #{tab[:title]}#{status}\n"
                output_text += "     URL: #{tab[:url]}\n"
                output_text += "     Tab ID: #{tab[:tab_id]}\n"
              end
            end

            {
              content: [
                {
                  type: "text",
                  text: output_text
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "No browser windows or tabs found"
                }
              ]
            }
          end

        when "create_new_tab"
          url = arguments.fetch("url", "about:blank")
          result = @cdp.create_new_tab(url)
          
          if result && result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully created new tab (ID: #{result['tab_id']}) with URL: #{result['url']}"
                }
              ]
            }
          else
            error_msg = result && result["error"] ? result["error"] : "Unknown error"
            {
              content: [
                {
                  type: "text",
                  text: "Failed to create new tab: #{error_msg}"
                }
              ],
              isError: true
            }
          end

        when "close_tab"
          tab_id = arguments["tab_id"]
          result = @cdp.close_tab(tab_id)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully closed tab (ID: #{result['tab_id']})"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to close tab (ID: #{tab_id}): #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "switch_to_tab"
          tab_id = arguments["tab_id"]
          result = @cdp.switch_to_tab(tab_id)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully switched to tab: #{result['title']} (#{result['url']})"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to switch to tab (ID: #{tab_id}): #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "navigate_back"
          result = @cdp.navigate_back
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully navigated back in history"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to navigate back: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "navigate_forward"
          result = @cdp.navigate_forward
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully navigated forward in history"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to navigate forward: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "reload_page"
          ignore_cache = arguments.fetch("ignore_cache", false)
          result = @cdp.reload_page(ignore_cache)
          
          if result["success"]
            cache_text = ignore_cache ? " (bypassing cache)" : ""
            {
              content: [
                {
                  type: "text",
                  text: "Successfully reloaded page#{cache_text}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to reload page: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "inject_script"
          script = arguments["script"]
          world_name = arguments["world_name"]
          result = @cdp.inject_script(script, world_name)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully injected script (ID: #{result['script_id']}). Script will run on current and future page loads."
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to inject script: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "execute_script"
          script = arguments["script"]
          return_value = arguments.fetch("return_value", true)
          result = @cdp.execute_script(script, return_value)
          
          if result["success"]
            output_text = "Script executed successfully"
            if return_value && result["value"]
              output_text += "\nReturned value: #{result['value'].inspect}"
            elsif return_value
              output_text += "\nNo return value"
            end
            
            {
              content: [
                {
                  type: "text",
                  text: output_text
                }
              ]
            }
          else
            error_text = "Script execution failed: #{result['error']}"
            if result["exception"]
              error_text += "\nException: #{result['exception']}"
              if result["line"] && result["column"]
                error_text += " (line #{result['line']}, column #{result['column']})"
              end
            end
            
            {
              content: [
                {
                  type: "text",
                  text: error_text
                }
              ],
              isError: true
            }
          end

        when "create_script_bridge"
          bridge_name = arguments.fetch("bridge_name", "InceptionBridge")
          result = @cdp.create_script_bridge(bridge_name)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully created script bridge '#{result['bridge_name']}'. Available methods: on(), emit(), execute(), getElementInfo(), waitForElement(), onPageChange()"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to create script bridge: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "capture_console"
          enable = arguments.fetch("enable", true)
          result = @cdp.capture_console_logs(enable)
          
          if result["success"]
            status = result["enabled"] ? "enabled" : "disabled"
            {
              content: [
                {
                  type: "text",
                  text: "Console logging #{status} successfully"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to configure console logging: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "get_console_logs"
          clear_after = arguments.fetch("clear_after", false)
          result = @cdp.get_console_logs(clear_after)
          
          if result["success"]
            if result["logs"].any?
              log_text = "Console Logs (#{result['count']} entries):\n\n"
              result["logs"].each_with_index do |log, i|
                timestamp = Time.at(log[:timestamp] / 1000.0).strftime("%H:%M:%S.%L")
                log_text += "#{i+1}. [#{timestamp}] #{log[:level].upcase}: #{log[:text]}\n"
              end
              
              {
                content: [
                  {
                    type: "text",
                    text: log_text
                  }
                ]
              }
            else
              {
                content: [
                  {
                    type: "text",
                    text: "No console logs captured. Enable console capture first with capture_console tool."
                  }
                ]
              }
            end
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to retrieve console logs"
                }
              ],
              isError: true
            }
          end

        when "scroll_page"
          direction = arguments["direction"]
          amount = arguments["amount"]
          result = @cdp.scroll_page(direction, amount)
          
          if result["success"]
            amount_text = amount ? " (#{amount} pixels)" : ""
            {
              content: [
                {
                  type: "text",
                  text: "Successfully scrolled #{result['direction']}#{amount_text}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to scroll: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "scroll_to_element"
          selector = arguments["selector"]
          result = @cdp.scroll_to_element(selector)
          
          if result["success"]
            visible_status = result["visible"] ? "visible" : "not fully visible"
            {
              content: [
                {
                  type: "text",
                  text: "Successfully scrolled to element '#{result['selector']}' at (#{result['x']}, #{result['y']}). Element is #{visible_status}."
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to scroll to element '#{selector}': #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "scroll_to_coordinates"
          x = arguments["x"]
          y = arguments["y"]
          result = @cdp.scroll_to_coordinates(x, y)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully scrolled to coordinates (#{result['x']}, #{result['y']})"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to scroll to coordinates (#{x}, #{y}): #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "get_scroll_position"
          result = @cdp.get_scroll_position
          
          if result["success"]
            output_text = "Current Scroll Position:\n"
            output_text += "Position: (#{result['x']}, #{result['y']})\n"
            output_text += "Max Scroll: (#{result['maxX']}, #{result['maxY']})\n"
            output_text += "Viewport: #{result['viewportWidth']}x#{result['viewportHeight']}\n"
            output_text += "Page Size: #{result['pageWidth']}x#{result['pageHeight']}"
            
            {
              content: [
                {
                  type: "text",
                  text: output_text
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to get scroll position: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "smooth_scroll"
          direction = arguments["direction"]
          distance = arguments["distance"]
          duration = arguments.fetch("duration", 500)
          result = @cdp.smooth_scroll(direction, distance, duration)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully started smooth scroll #{result['direction']} by #{result['distance']} pixels over #{result['duration']}ms"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to smooth scroll: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "resize_window"
          width = arguments["width"]
          height = arguments["height"]
          result = @cdp.resize_window(width, height)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully resized window to #{result['width']}x#{result['height']}"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to resize window: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "maximize_window"
          result = @cdp.maximize_window
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully maximized window"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to maximize window: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "minimize_window"
          result = @cdp.minimize_window
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully minimized window"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to minimize window: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "restore_window"
          result = @cdp.restore_window
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully restored window to normal state"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to restore window: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "get_window_bounds"
          result = @cdp.get_window_bounds
          
          if result["success"]
            output_text = "Window Bounds:\n"
            output_text += "Position: (#{result['left']}, #{result['top']})\n"
            output_text += "Size: #{result['width']}x#{result['height']}\n"
            output_text += "State: #{result['windowState']}"
            
            {
              content: [
                {
                  type: "text",
                  text: output_text
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to get window bounds: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        when "set_window_position"
          x = arguments["x"]
          y = arguments["y"]
          result = @cdp.set_window_position(x, y)
          
          if result["success"]
            {
              content: [
                {
                  type: "text",
                  text: "Successfully moved window to position (#{result['x']}, #{result['y']})"
                }
              ]
            }
          else
            {
              content: [
                {
                  type: "text",
                  text: "Failed to set window position: #{result['error']}"
                }
              ],
              isError: true
            }
          end

        else
          {
            content: [
              {
                type: "text",
                text: "Unknown tool: #{name}"
              }
            ],
            isError: true
          }
        end
      end
    end
  end
end