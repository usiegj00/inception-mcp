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
            description: "Navigate the browser to a URL",
            inputSchema: {
              type: "object",
              properties: {
                url: {
                  type: "string",
                  description: "The URL to navigate to"
                }
              },
              required: ["url"]
            }
          },
          {
            name: "take_screenshot", 
            description: "Take a screenshot of the current page",
            inputSchema: {
              type: "object",
              properties: {
                format: {
                  type: "string",
                  enum: ["png", "jpeg"],
                  description: "Image format",
                  default: "png"
                },
                quality: {
                  type: "number",
                  description: "Image quality (0-100, only for jpeg)",
                  default: 80
                }
              }
            }
          },
          {
            name: "click_element",
            description: "Click at specific coordinates on the page",
            inputSchema: {
              type: "object", 
              properties: {
                x: {
                  type: "number",
                  description: "X coordinate"
                },
                y: {
                  type: "number", 
                  description: "Y coordinate"
                }
              },
              required: ["x", "y"]
            }
          },
          {
            name: "type_text",
            description: "Type text into the current focused element",
            inputSchema: {
              type: "object",
              properties: {
                text: {
                  type: "string",
                  description: "Text to type"
                }
              },
              required: ["text"]
            }
          },
          {
            name: "press_key",
            description: "Press a keyboard key",
            inputSchema: {
              type: "object",
              properties: {
                key: {
                  type: "string", 
                  description: "Key to press (Enter, Backspace, Tab, Escape, ArrowUp, ArrowDown, ArrowLeft, ArrowRight, etc.)"
                }
              },
              required: ["key"]
            }
          },
          {
            name: "get_page_content",
            description: "Get the HTML content of the current page",
            inputSchema: {
              type: "object",
              properties: {}
            }
          },
          {
            name: "get_page_info",
            description: "Get information about the current page (title, URL, etc.)",
            inputSchema: {
              type: "object",
              properties: {}
            }
          }
        ]
      end

      def execute_tool(name, arguments)
        case name
        when "navigate_browser"
          result = @cdp.navigate(arguments["url"])
          {
            content: [
              {
                type: "text",
                text: "Navigation command sent to browser"
              }
            ]
          }

        when "take_screenshot"
          format = arguments["format"] || "png"
          quality = arguments["quality"] || 80
          
          request_id = @cdp.take_screenshot(format: format, quality: quality)
          
          # For now, return a message. In a full implementation, 
          # you'd wait for the CDP response and return the actual image
          {
            content: [
              {
                type: "text", 
                text: "Screenshot command sent (request ID: #{request_id}). In a full implementation, this would return the base64 image data."
              }
            ]
          }

        when "click_element"
          x = arguments["x"]
          y = arguments["y"]
          @cdp.click_element(x, y)
          
          {
            content: [
              {
                type: "text",
                text: "Click sent to coordinates (#{x}, #{y})"
              }
            ]
          }

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