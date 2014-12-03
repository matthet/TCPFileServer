require "socket"

class DirectoryServer
  def initialize(size, ip, port)
    @d_server = TCPServer.open(ip, port)
    @directories = Hash.new
    @ser_fns = Hash.new
    @ser_ips = Hash.new
    @ser_ports = Hash.new
    @directories[:ser_fns] = @ser_fns
    @directories[:ser_ips] = @ser_ips
    @directories[:ser_ports] = @ser_ports
    @directories[:ser_fns]["hello"] = "hellofile.txt"
    @directories[:ser_ips]["hellofile.txt"] = "134.226.32.10"
    @directories[:ser_ports]["134.226.32.10"] = "2632"
    run
  end

  def run
    loop do
      Thread.start(@d_server.accept) do |client|
        loop do
	  msg = client.gets.chomp
	  puts msg
	  filename = msg[9..msg.length-1].to_s
	  look_up_file(filename, client)
        end
      end
    end
  end

  def look_up_file(filename, client)
    $server_fn = $server_ip = $server_port = ""
    @directories[:ser_fns].each do |other_name, fs_filename|
      if(filename == other_name) 
        $server_fn = fs_filename 
      end
    end
    @directories[:ser_ips].each do |other_name, fs_ip|
      if($server_fn == other_name)
        $server_ip = fs_ip
      end
    end
    @directories[:ser_ports].each do |other_server, fs_port|
      puts "TARA:#{@directories[:ser_ports]}"
      if($server_ip == other_server)
        $server_port = fs_port
      end
    end
    client.puts "SERVER:#{$server_ip} PORT:#{$server_port} FILENAME:#{$server_fn}"
  end
end

# Initialise the Directory Server
ds_port = 2633
ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
DirectoryServer.new(10, ip, ds_port)
	
