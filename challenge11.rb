#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 11: Write an application that will:
# Create an SSL terminated load balancer (Create self-signed certificate.)
# Create a DNS record that should be pointed to the load balancer.
# Create Three servers as nodes behind the LB.
# Each server should have a CBS volume attached to it. (Size and type
# are irrelevant.)
# All three servers should have a private Cloud Network shared between
# them.
# Login information to all three servers returned in a readable format
# as the result of the script, including connection information.

require "bundler/setup"
require "inifile"
require "fog"

fqdn = "www.rsdevopschallenge11.com"
SERVER_BASE_NAME = "web"

# Use a credential file in the format:
#   [rackspace_cloud]
#   username = myusername
#   api_key = 01234567890abcdef
#   region = ord

# Grab credentials
credentials = IniFile.load(File.expand_path("~/.rackspace_cloud_credentials"))

if credentials.nil?
  puts "Please make sure your credentials are properly set in ~/.rackspace_cloud_credentials"
  exit(-1)
end

service_info = {
  provider: "Rackspace",
  rackspace_username: credentials[:rackspace_cloud]["username"],
  rackspace_api_key: credentials[:rackspace_cloud]["api_key"],
  version: :v2,
  rackspace_region: credentials[:rackspace_cloud]["region"].downcase.to_sym,
  connection_options: {}
}

if credentials[:rackspace_cloud]["region"] =~ /lon/i
  options[:rackspace_auth_url] = "https://lon.identity.api.rackspacecloud.com/v2.0"
end

service = Fog::Compute.new(service_info)

image_id = service.images.select { |img| img.name =~ /Ubuntu 12.10/i }[0].id
flavor_id = service.flavors.select { |f| f.name =~ /512mb/i }[0].id

puts "Creating cloud network"
response = service.create_network('challenge11','192.168.23.0/24')
network_id = response.body["network"]["id"]

# create 3 servers
servers = []
puts "Creating servers"
3.times do |n|
  current_server = {}
  puts "Creating server #{SERVER_BASE_NAME + (n + 1).to_s}"
  response = service.create_server(
    SERVER_BASE_NAME + (n + 1).to_s,
    image_id,
    flavor_id,
    1,
    5,
    { networks: [{
      uuid: '00000000-0000-0000-0000-000000000000'
    },{
      uuid: '11111111-1111-1111-1111-111111111111'
    },{
      uuid: network_id
    }] }
  )
  current_server[:id] = response.body["server"]["id"]

  until service.get_server(current_server[:id]).body["server"]["status"] =~ /ACTIVE/
    sleep 2
  end

  server = service.get_server(current_server[:id]).body["server"]

  current_server[:name] = server["name"]
  current_server[:user] = "root"
  current_server[:password] = response.body["server"]["adminPass"]
  current_server[:ips] = []
  server["addresses"].each_pair do |_,v|
    v.each do |ip|
      current_server[:ips] << ip["addr"]
    end
  end

  servers << current_server
end

service_info.delete(:version)
service_info.delete(:provider)

lb_service = Fog::Rackspace::LoadBalancers.new(service_info)


# Create a load balancer with the 2 servers behind it
puts "Creating and populating load balancer challenge11_lb"

vips = [{"type" => "PUBLIC"}]
nodes = []
servers.each do |s|
  nodes << {
    "address" => s[:ips].select{|ip| ip =~ /^10\..*/}[0],
    "port"    => 80,
    "condition" => "ENABLED"
  }
end

lb = lb_service.create_load_balancer("challenge11_lb", "HTTP", 80, vips, nodes)
lb = lb.body["loadBalancer"]["id"]

until lb_service.get_load_balancer(lb).body["loadBalancer"]["status"] =~ /ACTIVE/
  sleep 2
end

puts "Load balancer challenge11_lb successfully created"

puts "Enabling SSL termination on LB"
lb_service.set_ssl_termination(lb, 443, File.read("challenge11.key"), File.read("challenge11.crt"), { enabled: true })


dns_service = Fog::DNS.new(service_info)

# Check for existence of domain
domain_name = fqdn.split('.')[-2,2].join('.')
domain_id = dns_service.list_domains.body["domains"].select { |d| d["name"] == domain_name }.first

if domain_id.nil?
  puts "Creating domain #{domain_name}"
  response = dns_service.create_domains([{:name => domain_name, :email => "ipadmin@stabletransit.com"}])
  job_id = response.body["jobId"]
  puts "Waiting for domain creation to complete"
  until dns_service.callback(job_id).body["status"] =~ /COMPLETED/
    sleep 2
  end
  domain_id = dns_service.callback(job_id).body["response"]["domains"].first["id"]
else
  domain_id = domain_id["id"]
end

# Create A record for FQDN to LB VIP
response = dns_service.add_records(domain_id, [{
  name: fqdn,
  type: 'A',
  data: lb_service.get_load_balancer(lb).body["loadBalancer"]["virtualIps"].first["address"]
}])

if (200..299).include? response.status 
  puts "A Record #{fqdn} => #{server.addresses["public"][-1]["addr"]} successfully created"
else
  puts "There was a problem submitting this record"
end

cbs_service = Fog::Rackspace::BlockStorage.new(service_info)

puts "Creating CBS volumes"
volumes = []

3.times do |n|
   volumes << cbs_service.volumes.create(size: 100, display_name: "volume#{n+1}", volume_type: "SATA")
end

puts "Attaching volumes"

servers.each do |s|
  current_server = service.servers.get(s[:id])
  current_server.attach_volume(volumes.pop().id)
end

puts "All actions complete, server information follows:"
servers.each do |s|
  puts "Server name: #{s[:name]}"
  puts "User: #{s[:user]}"
  puts "Password: #{s[:password]}"
  puts "IP Addresses: "
  s[:ips].each do |ip|
    puts ip
  end
end
