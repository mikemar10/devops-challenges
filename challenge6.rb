#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 6: Write a script that creates a CDN-enabled container in Cloud

require "bundler/setup"
require "inifile"
require "fog"

if ARGV.length > 1
  puts "Usage: ./challenge6 [container_name]"
  exit(1)
end

target_container = ARGV[0].nil? ? "challenge6_container" : ARGV[0]

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
  rackspace_region: credentials[:rackspace_cloud]["region"].downcase.to_sym,
  connection_options: {}
}

if credentials[:rackspace_cloud]["region"] =~ /lon/i
  service_info[:rackspace_auth_url] = "https://lon.identity.api.rackspacecloud.com/v2.0"
end

service = Fog::Storage.new(service_info)

container = service.directories.get(target_container)

if container.nil?
  puts "Container not found, creating new container #{target_container}"
  container = service.directories.create( key: target_container )
end

puts "Setting container #{target_container} to be CDN enabled"
container.public = true
container.save
