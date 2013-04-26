#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 2: Write a script that clones a server (takes an image and deploys the image as a new server).
# Worth 2 Points

require "bundler/setup"
require "inifile"
require "fog"

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

image_source = service.servers.first

puts "Creating image \"#{image_source.name + '-backup'}\" of server #{image_source.name}"
image = image_source.create_image "#{image_source.name}-backup"

image.wait_for { ready? }
flavor_id = service.flavors.select { |f| f.name =~ /512mb/i }[0].id

puts "Deploying image #{image.name}"

server = service.servers.create(
  name: image.name,
  flavor_id: flavor_id,
  image_id: image.id
)

server.wait_for { ready? }

puts "Name: #{server.name}"
puts "Username: root"
puts "Password: #{server.password}"
puts "Public IPs: "
server.addresses["public"].each { |ip| puts ip["addr"] }
puts "Private IPs: "
server.addresses["private"].each { |ip| puts ip["addr"] }
