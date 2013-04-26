#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 8: Write a script that will create a static webpage served out
# of Cloud Files. The script must create a new container, cdn enable it,
# enable it to serve an index file, create an index file object, upload the
# object to the container, and create a CNAME record pointing to the CDN URL
# of the container.

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

puts "Creating container challenge8"
container_name = "challenge8"
container = service.directories.create( :key => container_name, :public => true )
container.metadata["Web-Index"] = "index.html"
container.save

puts "Uploading index file"
container.files.create(
  key: "index.html",
  body: "<html><body><h1>Hello World</h1></body></html>"
)

dns_service = Fog::DNS.new(service_info)

fqdn = "www.rsdevopschallenge8.com"
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
  type: 'CNAME',
  data: container.public_url
}])

if (200..299).include? response.status 
  puts "CNAME Record #{fqdn} => #{container.public_url} successfully created"
else
  puts "There was a problem submitting this record"
end
