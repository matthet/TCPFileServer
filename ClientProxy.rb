require 'thread' 
require "socket"

class ClientProxy
  def initialize(size, ip, port, dserver)
    @proxyserver = TCPServer.new(ip, port)
    #@fileserver = fserver
    @directoryserver = dserver

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
	  client_request = nil
          dir_response = nil
	  listen_client(client, client_request)
	  listen_dserver(client, dir_response)
	  client_request.join
	  dir_response.join
	end
      end
    end
  end

  def listen_client(client, client_request)
    client_request = Thread.new do
      loop do
        msg = client.gets.chomp
        fn = msg
        # while line = client.gets.chomp
        #  msg << line
        #end
        if msg[0..4] == "OPEN:" || msg[0..4] == "READ"
          @directoryserver.puts("FILENAME:#{fn[5..fn.length-1]}")
        elsif msg[0..4] == "CLOSE:" || msg[0..4] == "WRITE"
          @directoryserver.puts("FILENAME:#{fn[6..fn.length-1]}")
        else
	  client.puts "ERROR -1:Only OPEN, CLOSE, READ, WRITE operations allowed"
	end
      end
    end
  end

  def listen_dserver(client, dir_response)
    dir_response = Thread.new do
      loop do
        msg = @directoryserver.gets.chomp
        puts(msg)
      end
    end
  end
end

# Open File Server Connection
#fs_port = 2632
#fs_ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
#fs = TCPSocket.open(fs_ip, fs_port)

# Open Directory Server Connection
ds_port = 2633
ds_ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
ds = TCPSocket.open(ds_ip, ds_port)

# Initialise the Proxy Server
port = 2631
ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
ClientProxy.new(10, ip, port, ds)

