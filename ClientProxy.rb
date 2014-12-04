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
	@client = client
	loop do
	  @client_msg = ""
	  @client_fn = ""
	  @server_fn = ""
	  @c_request = nil
    	  @ds_response = nil
    	  @fs_response = nil	  
	  listen_client
	  listen_dserver
	  listen_fserver
	  @c_request.join
          @ds_response.join
	  @fs_response.join
	end
      end
    end
  end

  def listen_client
    @c_request = Thread.new do
      loop do
        @client_msg = @client.gets.chomp
        if @client_msg[0..4] == "OPEN:"
	  @client_fn = @client_msg[5..@client_msg.length-1]
	  @client_msg = @client_msg[0..4] << " " << @client.gets.chomp
	  puts @client_msg
	  @directoryserver.puts("FILENAME:#{@client_fn}")
        elsif @client_msg[0..4] == "READ:"
	  @client_fn = @client_msg[5..@client_msg.length-1]
          @client_msg = @client_msg[0..4] << " " << @client.gets.chomp << " " << @client.gets.chomp
	  @directoryserver.puts("FILENAME:#{@client_fn}")
        elsif @client_msg[0..5] == "CLOSE:"
	  @client_fn = @client_msg[6..@client_msg.length-1]
	  @client_msg = @client_msg[0..5]
	  @directoryserver.puts("FILENAME:#{@client_fn}")
	elsif @client_msg[0..5] == "WRITE:"
	  @client_fn = @client_msg[6..@client_msg.length-1]
	  @client_msg = @client_msg[0..5] << " " << @client.gets.chomp << " " << @client.gets.chomp
	  @directoryserver.puts("FILENAME:#{@client_fn}")
        else
	  @client.puts "ERROR -1:Only OPEN, CLOSE, READ, WRITE operations allowed"
	end
      end
    end
  end

  def listen_dserver
    @ds_response = Thread.new do
      loop do
        msg = @directoryserver.gets.chomp.split(" ")
        ip = msg[0][7..msg[0].length-1]
	port = msg[1][5..msg[1].length-1]
	@server_fn = msg[2][9..msg[2].length-1]
	if ip == @fs_ip.to_s && port == @fs_port.to_s
          if @client_msg[0..4] == "OPEN:" || @client_msg[0..4] == "READ:"
	    @client_msg.insert(5,"#{@server_fn}")
	  else
	    @client_msg.insert(6,"#{@server_fn}")
	  end
	  @fileserver0.puts(@client_msg)
	end
      end
    end
  end

  def listen_fserver
    @fs_response = Thread.new do
      loop do
	msg = @fileserver0.gets.chomp
	msg = msg.sub(@server_fn, @client_fn)
	@client.puts(msg)
      end
    end
  end
end

# Initialise the Proxy Server
port = 2631
ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
ClientProxy.new(10, ip, port)

