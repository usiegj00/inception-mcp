# frozen_string_literal: true

require_relative "mcp/version"
require_relative "mcp/server"
require_relative "mcp/cdp_client"
require_relative "mcp/tools"

module Inception
  module MCP
    class Error < StandardError; end
  end
end