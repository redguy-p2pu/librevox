require 'spec/helper'
require 'rr'
require 'mocksocket'
require 'fsr/command_socket'

class Bacon::Context
  include RR::Adapters::RRMethods
end

class SampleCmd < Librevoz::Cmd::Command
  def initialize(*args)
    @args = args
  end

  def arguments
    @args
  end

  def self.cmd_name
    "sample_cmd"
  end

  def response=(data)
    @response = "From command: #{data.content}"
  end
end

describe Librevoz::CommandSocket do
  before do
    @socket, @server = MockSocket.pipe
    stub(TCPSocket).open(anything, anything).times(any_times) {@socket}

    @server.print "Content-Type: command/reply\nReply-Text: +OK\n\n"
  end

  # This should be tested with some mocks. How do we use rr + bacon?
  describe ":connect => false" do
    should "not connect" do
      @cmd = Librevoz::CommandSocket.new(:connect => false)
      @server.should.be.empty?
    end

    should "connect when asked" do
      @cmd.connect
      @server.gets.should == "auth ClueCon\n"
    end
  end

  describe "with auto-connect" do
    before do
      @cmd = Librevoz::CommandSocket.new
    end

    should "authenticate" do
      @server.gets.should == "auth ClueCon\n"
    end

    should "read header response" do
      @server.print "Content-Type: command/reply\nSome-Header: Some value\n\n"
      reply = @cmd.command "foo"

      reply.class.should == Librevoz::Response
      reply.headers[:some_header].should == "Some value"
    end

    should "read command/reply responses" do
      @server.print "Content-Type: api/log\nSome-Header: Old data\n\n"

      @server.print "Content-Type: command/reply\nSome-Header: New data\n\n"
      reply = @cmd.command "foo"

      reply.headers[:some_header].should == "New data"
    end

    should "read api/response responses" do
      @server.print "Content-Type: api/log\nSome-Header: Old data\n\n"

      @server.print "Content-Type: api/response\nSome-Header: New data\n\n"
      reply = @cmd.command "foo"

      reply.headers[:some_header].should == "New data"
    end

    should "read content if present" do
      @server.print "Content-Type: command/reply\nContent-Length: 3\n\n+OK\n\n"
      reply = @cmd.command "foo"

      reply.content.should == "+OK"
    end

    should "register command" do
      @cmd.should.not.respond_to? :sample_cmd
      Librevoz::CommandSocket.register_cmd SampleCmd
      @cmd.should.respond_to? :sample_cmd
    end

    describe "with commands" do
      before do
        Librevoz::CommandSocket.register_cmd SampleCmd
        2.times {@server.gets} # get rid of the auth message
      end

      should "send command" do
        @server.print "Content-Type: command/reply\nContent-Length: 3\n\n+OK\n\n"
        @cmd.sample_cmd
        @server.gets.should == "api sample_cmd\n"
      end

      should "return response from command" do
        @server.print "Content-Type: command/reply\nContent-Length: 3\n\n+OK\n\n"
        @cmd.sample_cmd.should == "From command: +OK"
      end

      should "pass arguments" do
        @server.print "Content-Type: command/reply\nContent-Length: 3\n\n+OK\n\n"
        @cmd.sample_cmd("foo", "bar")
        @server.gets.should == "api sample_cmd foo bar\n"
      end
    end

    describe "#run" do
      before do
        2.times {@server.gets} # get rid of the auth message
        @sample = SampleCmd.new
      end

      should "send command" do
        @server.print "Content-Type: command/reply\nContent-Length: 3\n\n+OK\n\n"
        @cmd.run @sample
        @server.gets.should == "api sample_cmd\n"
      end

      should "return response from command" do
        @server.print "Content-Type: command/reply\nContent-Length: 3\n\n+OK\n\n"
        @cmd.run(@sample).should == "From command: +OK"
      end
    end
  end
end