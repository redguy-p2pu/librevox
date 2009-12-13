require 'eventmachine'
require 'em/protocols/header_and_content'

module Librevoz
  class Response
    attr_accessor :headers, :content

    def initialize(headers="", content="")
      self.headers = headers
      self.content = content
    end

    def headers=(headers)
      @headers = headers_2_hash(headers)
      @headers.each {|k,v| v.chomp! if v.is_a?(String)}
    end

    def content=(content)
      @content = content.match(/:/) ? headers_2_hash(content) : content
      @content.each {|k,v| v.chomp! if v.is_a?(String)}
    end

    def event?
      @content.is_a?(Hash) && @content.include?(:event_name)
    end

    def event
      @content[:event_name] if event?
    end

    def api_response?
      @headers[:content_type] == "api/response"
    end

    def command_reply?
      @headers[:content_type] == "command/reply"
    end

    private
    def headers_2_hash(*args)
      EM::Protocols::HeaderAndContentProtocol.headers_2_hash *args
    end
  end
end