require 'thread' 
require "socket"

class ClientProxy
  def initialize(size, ip, port, fileserver)
    @port = port
    @ip = ip
    @proxyserver = TCPServer.new(@ip, @port)
    @fileserver = fileserver
    @request = nil
    @response = nil

    @size = size
    @jobs = Queue.new

    # Threadpooled Multithreaded Server to handle Client requests
    # Each thread store its’ index in a thread-local variable
    @pool = Array.new(@size) do |i|
      Thread.new do
        Thread.current[:id] = i

        # Shutdown of threads
        catch(:exit) do
          loop do
            job, args = @jobs.pop
            job.call(*args)
          end
        end
      end
    end
    run
  end

  def schedule(*args, &block)
    @jobs << [block, args]
  end

  def run
    loop do
      schedule(@proxyserver.accept) do |client|
      client.puts "Ready to go...\n"
	loop do
	  client.puts "Your request please:\n"
	  request = nil
	  response = nil
	  listen_client(client, request)
	  listen_server(client, response)
	  request.join
	  response.join
	end
      end
    end
  end

  def listen_client(client, request)
    request = Thread.new do
      loop {
        msg = client.gets.chomp
	@fileserver.puts(msg)
      }
    end
  end

  def listen_server(client, response)
    response = Thread.new do
      loop {
        msg = @fileserver.gets.chomp
        client.puts(msg)
      }
    end
  end
end

# Open File Server Connection
fs_port = 2632
fs_ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
fs = TCPSocket.open(fs_ip, fs_port)

# Initialise the Proxy Server
port = 2631
ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
ClientProxy.new(10, ip, port, fs)


