#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 5: Write a script that creates a Cloud Database instance. This instance should contain at least one 
# database, and the database should have at least one user that can connect to it. Worth 1 Point

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

service = Fog::Rackspace::Databases.new(service_info)

flavor_id = service.flavors.first.id

puts "Creating 512MB Cloud Database instance with 5GB storage"
response = service.create_instance("devops_database", flavor_id, 5)
instance_id = response.body["instance"]["id"]

until service.get_instance(instance_id).body["instance"]["status"] =~ /ACTIVE/i
  sleep 2
end

puts "Creating database db_uno within newly created instance"
service.create_database(instance_id, "db_uno")

until service.list_databases(instance_id).body["databases"].select{|db| db["name"] =~ /db_uno/} != []
  sleep 2
end

# http://stackoverflow.com/questions/88311/how-best-to-generate-a-random-string-in-ruby
rand_pw = (0..16).map{ ('A'..'Z').to_a[rand(26)]}.join
puts "Adding user devops with password #{rand_pw}"
service.create_user(instance_id, "devops", rand_pw, {
  databases: [{
    name: "db_uno"
  }]
})

puts "le fin"
