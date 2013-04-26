#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 7: Write a script that will create 2 Cloud Servers and add them
# as nodes to a new Cloud Load Balancer.

require "bundler/setup"
require "inifile"
require "fog"

credentials = IniFile.load(File.expand_path("~/.rackspace_cloud_credentials"))

if credentials.nil?
  puts "Please make sure your credentials are properly set in ~/.rackspace_cloud_credentials"
  exit(-1)
end

if (credentials[:rackspace_cloud]["region"] =~ /ord|dfw|lon/i).nil?
  puts "Region incorrectly specified, setting to default region ORD"
  credentials[:rackspace_cloud]["region"] = "ord"
end

service_info = {
  rackspace_username: credentials[:rackspace_cloud]["username"],
  rackspace_api_key: credentials[:rackspace_cloud]["api_key"],
  rackspace_region: credentials[:rackspace_cloud]["region"].downcase.to_sym,
  connection_options: {}
}

if credentials[:rackspace_cloud]["region"] =~ /lon/i
  service_info[:rackspace_auth_url] = "https://lon.identity.api.rackspacecloud.com/v2.0"
end

lb_service = Fog::Rackspace::LoadBalancers.new(service_info)

service_info[:provider] = "Rackspace"
service_info[:version] = :v2

cs_service = Fog::Compute.new(service_info)
SERVER_BASE_NAME = "web"

# Determine image and flavor id programmatically in case they change in the future
image_id = cs_service.images.select { |img| img.name =~ /Ubuntu 12.10/i }[0].id
flavor_id = cs_service.flavors.select { |f| f.name =~ /512mb/i }[0].id

server_ips = []
puts "Creating 2 servers"
2.times do |n|
  puts "Creating server #{SERVER_BASE_NAME + (n + 1).to_s}"
  server = cs_service.servers.create(
    name: SERVER_BASE_NAME + (n + 1).to_s,
    flavor_id: flavor_id,
    image_id: image_id
  )
  
  server.wait_for { ready? }

  puts "Name: #{server.name}"
  puts "Username: root"
  puts "Password: #{server.password}"
  puts "Public IPs: "
  server.addresses["public"].each { |ip| puts ip["addr"] }
  puts "Private IPs: "
  server.addresses["private"].each { |ip| puts ip["addr"] }
  server_ips << server.addresses["private"].first["addr"]
end

puts "Creating and populating load balancer challenge7_lb"
vips = [{"type" => "PUBLIC"}]
nodes = [{
  "address" => server_ips[0],
  "port"    => 80,
  "condition" => "ENABLED"
  },{
  "address" => server_ips[1],
  "port"    => 80,
  "condition" => "ENABLED"
}]

lb = lb_service.create_load_balancer("challenge7_lb", "HTTP", 80, vips, nodes)
lb = lb.body["loadBalancer"]["id"]

until lb_service.get_load_balancer(lb).body["loadBalancer"]["status"] =~ /ACTIVE/
  sleep 2
end

puts "Load balancer challenge7_lb successfully created!"
