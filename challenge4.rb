#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 4: Write a script that uses Cloud DNS to create a new A record when passed a FQDN and 
# IP address as arguments. Worth 1 Point

require "bundler/setup"
require "inifile"
require "fog"

# Basic argument validation
# FQDN requirements:
# |- total length must not exceed 255 characters
# |- valid hostname characters are case insensitive alphanumeric and dashes
# |- hostname length must not exceed 63 characters
# |- TLD can be arbitrarily long and contain case insensitive alphabetical characters and dots
# 
# IP addresses must be IPv4
if ARGV.length != 2 or 
  ARGV[0] !~ /(?=^.{1,255}$)([a-z0-9-]{1,63}\.)+[a-z.]+$/i or 
  ARGV[1].split('.').select {|octet| (0..255).include? octet.to_i }.length != 4
  puts "USAGE: challenge4 FQDN IP_ADDRESS"
  puts "Example: challenge4 foo.bar.com 127.0.0.1"
  exit(-1)
end

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

options = {
  provider: "Rackspace",
  rackspace_username: credentials[:rackspace_cloud]["username"],
  rackspace_api_key: credentials[:rackspace_cloud]["api_key"],
  connection_options: {}
}

if credentials[:rackspace_cloud]["region"] =~ /lon/i
  options[:rackspace_auth_url] = "https://lon.identity.api.rackspacecloud.com/v2.0"
end

service = Fog::DNS.new(options)

# Check for existence of domain
domain_name = ARGV[0].split('.')[-2,2].join('.')
domain_id = service.list_domains.body["domains"].select { |d| d["name"] == domain_name }.first

if domain_id.nil?
  puts "Domain #{domain_name} does not exist, please create domain via control panel"
  exit(-1)
end

domain_id = domain_id["id"]

response = service.add_records(domain_id, [{
  name: ARGV[0],
  type: 'A',
  data: ARGV[1]
}])

if (200..299).include? response.status 
  puts "A Record #{ARGV[0]} => #{ARGV[1]} successfully created"
else
  puts "There was a problem submitting this record"
end
