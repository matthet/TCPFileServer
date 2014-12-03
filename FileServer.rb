require 'thread'
require "socket"

class FileServer
  def initialize(size, ip, port)
    @fileserver = TCPServer.new(ip, port)

    @size = size
    @jobs = Queue.new

    @error0 = "\nERROR 0:File already exists.\n\n"
    @error1 = "\nERROR 1:File does not exist.\n\n"
    @error2 = "\nERROR 2:File size smaller than required."

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
  
  # Tell the pool that work is to be done: a client is trying to connect
  def schedule(*args, &block)
    @jobs << [block, args]
  end

  # Entry Point
  # Schedule a client request
  def run
    loop do
      schedule(@fileserver.accept) do |client|
        loop do
          request = client.gets.chomp
          if request[0..4] == "OPEN:"
	    open_request(request[5..request.length-1], client)
	  elsif request[0..5] == "CLOSE:"
	    close_request(request[6..request.length-1], client)
	  elsif request[0..4] == "READ:"
	    read_request(request[5..request.length-1], client)
	  elsif request[0..5] == "WRITE:"
	    write_request(request[6..request.length-1], client)
	  end
	end
      end
    end
    @fileserver.close
    at_exit { @pool.shutdown }
  end
  
  # Client has requested to open a file
  def open_request(filename, client)
    more_info = client.gets.chomp
    is_new = more_info[7..more_info.length-1].to_i
    if is_new == 1 #create new file request
      if File.exist?(filename)
        client.puts @error0
      else
        File.open(filename, "w"){ |somefile| somefile.puts "Hello new file!"}
        client.puts "\nOK:#{filename}\n\n"
      end
    else
      if File.exist?(filename)
        File.open(filename)
        client.puts "\nOK:#{filename}\n\n"
      else client.puts @error1
      end
    end
  end

  # Client has requested to close a file
  # Null operation.. can't check if file is closed without opening first.
  def close_request(filename, client)
    if File.exist?(filename)
      client.puts "\nOK:#{filename}\n\n"
    else client.puts @error1
    end
  end

  # Client has requested to read a file
  def read_request(filename, client)
    if File.exist?(filename)
      start_pos = client.gets.chomp
      start_n = start_pos[6..start_pos.length-1].to_i
      len = client.gets.chomp
      len_n = len[7..len.length-1].to_i
      file_size = File.size(filename)
      if start_n >= file_size || len_n > file_size
        client.puts "#{@error2} (#{file_size})\n\n"
      else
	content = IO.binread(filename,len_n,start_n)
        client.puts "\nOK:#{filename}\nSTART:#{start_n}\nLENGTH:#{len_n}\n#{content}\n\n"
      end
    else client.puts @error1
    end
  end

  # Client has requested to write to a file
  def write_request(filename, client)
    if File.exist?(filename)
      start_pos = client.gets.chomp
      start_n = start_pos[6..start_pos.length-1].to_i
      IO.binwrite(filename, client.gets.chomp, start_n)
      client.puts "\nOK:#{filename}\nSTART:#{start_n}\n\n"
    else client.puts @error1
    end
  end

  # Shutdown, wait for all threads to exit.
  def shutdown
    @size.times do
      schedule { throw :exit }
    end
    @pool.map(&:join)
  end
end

# Initialise the File Server
fs_port = 2632
ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
puts ip
FileServer.new(10, ip, fs_port)

