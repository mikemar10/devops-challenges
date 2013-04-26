#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 9: Write an application that when passed the arguments
# FQDN, image, and flavor it creates a server of the specified image and
# flavor with the same name as the fqdn, and creates a DNS entry for the
# fqdn pointing to the server's public IP

require "bundler/setup"
require "inifile"
require "fog"

# Basic argument validation
# FQDN requirements:
# |- total length must not exceed 255 characters
# |- valid hostname characters are case insensitive alphanumeric and dashes
# |- hostname length must not exceed 63 characters
# |- TLD can be arbitrarily long and contain case insensitive alphabetical characters and dots
if ARGV.length != 3 or 
  ARGV[0] !~ /(?=^.{1,255}$)([a-z0-9-]{1,63}\.)+[a-z.]+$/i 
  puts "USAGE: challenge9 FQDN IMAGE_ID FLAVOR_ID"
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

fqdn = ARGV[0]
image_id = ARGV[1]
flavor_id = ARGV[2].to_i

puts "Creating server #{fqdn}"
server = service.servers.create(
  name: fqdn,
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

service_info.delete(:version)
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


response = dns_service.add_records(domain_id, [{
  name: fqdn,
  type: 'A',
  data: server.addresses["public"][-1]["addr"]
}])

if (200..299).include? response.status 
  puts "A Record #{fqdn} => #{server.addresses["public"][-1]["addr"]} successfully created"
else
  puts "There was a problem submitting this record"
end
