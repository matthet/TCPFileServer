
require 'thread' 
require "socket"

class ClientProxy
  def initialize(size, ip, port)
    @proxyserver = TCPServer.new(ip, port)

    # Open File Server Connection(s)
    @fs_port = 2632
    @fs_ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
    @fileserver0 = TCPSocket.open(@fs_ip, @fs_port)

    # Open Directory Server Connection
    @ds_port = 2633
    @ds_ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
    @directoryserver = TCPSocket.open(@ds_ip, @ds_port)

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
	  c_request = nil
	  listen_client(client, c_request)
	  c_request.join
	end
      end
    end
  end

  def listen_client(client, c_request)
    c_request = Thread.new do
      loop do
        msg = client.gets.chomp
        if msg[0..4] == "OPEN:"
	  @directoryserver.puts("FILENAME:#{msg[5..msg.length-1]}")
	  msg = msg[0..4] << " " << client.gets.chomp
        elsif msg[0..4] == "READ:"
	  @directoryserver.puts("FILENAME:#{msg[5..msg.length-1]}")
          msg = msg[0..4] << " " << client.gets.chomp << " " << client.gets.chomp
        elsif @client_msg[0..4] == "CLOSE:"
	  #@directoryserver.puts("FILENAME:#{fn[6..fn.length-1]}")
	elsif @client_msg[0..4] == "WRITE:"
          #@directoryserver.puts("FILENAME:#{fn[6..fn.length-1]}")
        else
	  client.puts "ERROR -1:Only OPEN, CLOSE, READ, WRITE operations allowed"
	end
	ds_response = nil
        listen_dserver(msg, client, ds_response)
        ds_response.join
      end
    end
  end

  def listen_dserver(client_msg, client, ds_response)
    ds_response = Thread.new do
      loop do
        msg = @directoryserver.gets.chomp.split(" ")
        ip = msg[0][7..msg[0].length-1]
	port = msg[1][5..msg[1].length-1]
	fn = msg[2][9..msg[2].length-1]
	if ip == @fs_ip.to_s && port == @fs_port.to_s
          if client_msg[0..4] == "OPEN:"
	    client_msg.insert(5,"#{fn}")
	    @fileserver0.puts(client_msg)
	  end
	  fs_response = nil
	  listen_fserver(client, fs_response)
          fs_response.join
	end
      end
    end
  end

  def listen_fserver(client, fs_response)
    fs_response = Thread.new do
      loop do
	msg = @fileserver0.gets.chomp
	client.puts(msg)
      end
    end
  end
end

# Initialise the Proxy Server
port = 2631
ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
ClientProxy.new(10, ip, port)

