#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 1: Write a script that builds three 512 MB Cloud
# Servers that following a similar naming convention. (ie., web1, web2,
# web3) and returns the IP and login credentials for each server. Use any
# image you want. Worth 1 point

require "bundler/setup"
require "inifile"
require "fog" 

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

if (credentials[:rackspace_cloud]["region"] =~ /ord|dfw|lon/i).nil?
  puts "Region incorrectly specified, setting to default region ORD"
  credentials[:rackspace_cloud]["region"] = "ord"
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
  service_info[:rackspace_auth_url] = "https://lon.identity.api.rackspacecloud.com/v2.0"
end

service = Fog::Compute.new(service_info)

# Determine image and flavor id programmatically in case they change in the future
image_id = service.images.select { |img| img.name =~ /Ubuntu 12.10/i }[0].id
flavor_id = service.flavors.select { |f| f.name =~ /512mb/i }[0].id

puts "Creating 3 servers"
3.times do |n|
  puts "Creating server #{SERVER_BASE_NAME + (n + 1).to_s}"
  server = service.servers.create(
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
end
