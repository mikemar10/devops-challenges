#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 10: Write an application that will:
# - Create 2 servers, supplying a ssh key to be installed at
#   /root/.ssh/authorized_keys.
# - Create a load balancer
# - Add the 2 new servers to the LB
# - Set up LB monitor and custom error page.
# - Create a DNS record based on a FQDN for the LB VIP.
# - Write the error page html to a file in cloud files for backup.

require "bundler/setup"
require "inifile"
require "fog"

fqdn = "www.rsdevopschallenge10.com"
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

# create 2 servers and provide an SSH key
server_ips = []
puts "Creating servers, using SSH public key in ~/.ssh/id_rsa.pub"
2.times do |n|
  puts "Creating server #{SERVER_BASE_NAME + (n + 1).to_s}"
  server = service.servers.bootstrap(
    name: SERVER_BASE_NAME + (n + 1).to_s,
    flavor_id: flavor_id,
    image_id: image_id,
    public_key_path: "~/.ssh/id_rsa.pub"
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

service_info.delete(:version)
files_service = Fog::Storage.new(service_info)

target_container = "challenge10"
container = files_service.directories.get(target_container)

if container.nil?
  puts "Container not found, creating new container #{target_container}"
  container = files_service.directories.create( key: target_container )
end

puts "Uploading LB error page to Cloud Files for backup"
container.files.create(
  key: "error.html",
  body: "<html><body><h1><blink>ERROR :(</blink></h1></body></html>"
)


service_info.delete(:provider)

lb_service = Fog::Rackspace::LoadBalancers.new(service_info)


# Create a load balancer with the 2 servers behind it
puts "Creating and populating load balancer challenge10_lb"

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

lb = lb_service.create_load_balancer("challenge10_lb", "HTTP", 80, vips, nodes)
lb = lb.body["loadBalancer"]["id"]

until lb_service.get_load_balancer(lb).body["loadBalancer"]["status"] =~ /ACTIVE/
  sleep 2
end

puts "Load balancer challenge10_lb successfully created"


puts "Configuring LB monitoring"
# Setup loadbalancer monitor
lb_service.set_monitor(lb, "CONNECT", 10, 10, 3)

puts "Configuring LB error page"
# Setup custom error page
begin
  lb_service.set_error_page(lb, "<html><body><h1><blink>ERROR :(</blink></h1></body></html>")
rescue
  # This is necessary because despite the fact that the load balancer is marked ACTIVE I was
  # receiving an error indicating it was currently immutable.  No idea why :(
  sleep 30
  lb_service.set_error_page(lb, "<html><body><h1><blink>ERROR :(</blink></h1></body></html>")
end

service_info[:provider] = "Rackspace"
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
  puts "A Record #{fqdn} => #{lb_service.get_load_balancer(lb).body["loadBalancer"]["virtualIps"].first["address"]} successfully created"
else
  puts "There was a problem submitting this record"
end
