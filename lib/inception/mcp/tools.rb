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
            name: "get_interactive_elements",
            title: "Get Interactive Elements",
            description: "Find all interactive elements on the current page with their positions, selectors, and metadata. Useful for identifying clickable elements, forms, and buttons for automation.",
            inputSchema: {
              type: "object",
              properties: {},
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

        when "get_page_content"
          request_id = @cdp.get_page_content
          
          {
            content: [
              {
                type: "text",
                text: "Page content request sent (request ID: #{request_id}). In a full implementation, this would return the HTML content."
              }
            ]
          }

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