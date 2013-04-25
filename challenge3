#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 3: Write a script that accepts a directory as an argument as well as a container name. 
# The script should upload the contents of the specified directory to the container (or create it if it doesn't exist).
# The script should handle errors appropriately. (Check for invalid paths, etc.) Worth 2 Points

require "bundler/setup"
require "inifile"
require "fog"

if ARGV.length != 2
  puts "Usage: ./challenge3 <target_directory> <target_container>"
  exit(1)
end

target_directory = ARGV[0]
target_container = ARGV[1]

unless Dir.exists?(File.expand_path(target_directory))
  puts "Target directory does not exist"
  exit(2)
end

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
   
puts "Uploading files in #{target_directory}"
Dir.glob(File.join(File.expand_path(target_directory), "**/*")) do |f|
  next unless File.file?(f)
  puts f
  container.files.create(
    key: f.gsub(File.expand_path(target_directory) + "/", ""),
    body: File.open(f)
  )
end
