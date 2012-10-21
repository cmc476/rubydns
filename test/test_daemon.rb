
require 'helper'
require 'pathname'

require 'rubydns'
require 'rubydns/resolver'

require 'rexec'
require 'rexec/daemon'

class BasicTestServer < RExec::Daemon::Base
	SERVER_PORTS = [[:udp, '127.0.0.1', 5350], [:tcp, '127.0.0.1', 5350]]

	@@base_directory = File.dirname(__FILE__)

	def self.run
		# Start the RubyDNS server
		RubyDNS::run_server(:listen => SERVER_PORTS) do
			match("test.local", IN::A) do |transaction|
				transaction.respond!("192.168.1.1")
			end

			match(/foo.*/, IN::A) do |match, transaction|
				transaction.respond!("192.168.1.2")
			end

			# Default DNS handler
			otherwise do |transaction|
				transaction.failure!(:NXDomain)
			end
		end
	end
end

class DaemonTest < Test::Unit::TestCase
	def setup
		$stderr.puts "Starting test server..."
		BasicTestServer.start
	end
	
	def teardown
		$stderr.puts "Stoping test server..."
		BasicTestServer.stop
	end
	
	def test_basic_dns
		assert_equal :running, RExec::Daemon::ProcessFile.status(BasicTestServer)
		
		EventMachine.run do
			resolver = resolver = RubyDNS::Resolver.new(BasicTestServer::SERVER_PORTS)
		
			resolver.query("test.local") do |response|
				answer = response.answer.first
				
				assert_equal "test.local", answer[0].to_s
				assert_equal "192.168.1.1", answer[2].address.to_s
				
				EventMachine.stop
			end
		end
	end
	
	def test_pattern_matching
		assert_equal :running, RExec::Daemon::ProcessFile.status(BasicTestServer)

		EventMachine.run do
			resolver = resolver = RubyDNS::Resolver.new(BasicTestServer::SERVER_PORTS)

			resolver.query("foobar") do |response|
				answer = response.answer.first
				
				assert_equal "foobar", answer[0].to_s
				assert_equal "192.168.1.2", answer[2].address.to_s
				
				EventMachine.stop
			end
		end
	end
end
