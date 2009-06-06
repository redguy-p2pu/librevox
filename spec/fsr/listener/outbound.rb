require "lib/fsr"
require FSR::ROOT/".."/:spec/:helper
require FSR::ROOT/:fsr/:listener/:outbound
gem "tmm1-em-spec"
require "em/spec"

# Bare class to use for testing
class MyListener < FSR::Listener::Outbound
  attr_accessor :recvd_reply

  def initialize(*args)
    super(*args)
    @recvd_reply = []
  end

  def session_initiated
  end

  def send_data(data)
    sent_data << data
  end

  def sent_data
    @sent_data ||= ''
  end

  def receive_reply(reply)
    @recvd_reply << reply
  end

end


EM.describe MyListener do

  before do
    @listener = MyListener.new(nil)
  end

  should "send connect to freeswitch upon a new connection" do
    @listener.receive_data("Content-Length: 0\nCaller-Caller-ID-Number: 8675309\n\n")
    @listener.sent_data.should.equal "connect\n\n"
    done
  end

  should "be able to receive a connection and establish a session " do
    @listener.receive_data("Content-Length: 0\nTest: Testing\n\n")
    @listener.session.class.should.equal FSR::Listener::HeaderAndContentResponse
    done
  end

  should "be able to read FreeSWITCH channel variables through session" do
    @listener.receive_data("Content-Length: 0\nCaller-Caller-ID-Number: 8675309\n\n")
    @listener.session.headers[:caller_caller_id_number].should.equal "8675309"
    done
  end

  should "be able to receive and process a response if not sent in one transmission" do
    @listener.receive_data("Content-Length: ")
    @listener.receive_data("0\nCaller-Caller-")
    @listener.receive_data("ID-Number: 8675309\n\n")
    @listener.session.headers[:caller_caller_id_number].should.equal "8675309"
    done
  end

  should "be able to dispatch our receive_reply callback method after a session is already established" do
    # This should establish the session
    @listener.receive_data("Content-Length: 0\nTest-Data: foo\n\n")

    # This should be a response, not a session
    @listener.receive_data("Content-Length: 0\nTest-Reply: bar\n\n")

    @listener.session.headers[:test_data].should.equal 'foo'
    @listener.recvd_reply.first.headers[:test_reply].should.equal 'bar'
    done
  end

end
