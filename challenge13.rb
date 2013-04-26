#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 13: Write an application that nukes everything in your Cloud
# Account. It should:
# Delete all Cloud Servers
# Delete all Custom Images
# Delete all Cloud Files Containers and Objects
# Delete all Databases
# Delete all Networks
# Delete all CBS Volumes

require "pry"
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

service_info[:rackspace_region] = :ord
cs_service_ord = Fog::Compute.new(service_info)
service_info.delete(:version)
files_service_ord = Fog::Storage.new(service_info)
dns_service = Fog::DNS.new(service_info)
service_info.delete(:provider)
db_service_ord = Fog::Rackspace::Databases.new(service_info)
cbs_service_ord = Fog::Rackspace::BlockStorage.new(service_info)
lb_service_ord = Fog::Rackspace::LoadBalancers.new(service_info)

service_info[:rackspace_region] = :dfw
service_info[:version] = :v2
service_info[:provider] = "Rackspace"
cs_service_dfw = Fog::Compute.new(service_info)
service_info.delete(:version)
files_service_dfw = Fog::Storage.new(service_info)
dns_service = Fog::DNS.new(service_info)
service_info.delete(:provider)
db_service_dfw = Fog::Rackspace::Databases.new(service_info)
cbs_service_dfw = Fog::Rackspace::BlockStorage.new(service_info)
lb_service_dfw = Fog::Rackspace::LoadBalancers.new(service_info)

puts "Deleting servers"
cs_service_ord.servers.each do |s|
  begin
    cs_service_ord.delete_server(s.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end
cs_service_dfw.servers.each do |s|
  begin
    cs_service_dfw.delete_server(s.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end

puts "Deleting images"
cs_service_ord.images.each do |i|
  begin
    cs_service_ord.delete_image(i.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end

cs_service_dfw.images.each do |i|
  begin
    cs_service_dfw.delete_image(i.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end

puts "Deleting networks"

cs_service_ord.networks.each do |n|
  begin
    cs_service_ord.delete_network(n.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end
    
cs_service_dfw.networks.each do |n|
  begin
    cs_service_dfw.delete_network(n.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end
    
puts "Deleting cloud files containers"

files_service_ord.directories.each do |d|
  d.files.each do |f|
    begin
      files_service_ord.delete_object(f.key)
    rescue
      puts "Failed to delete, so we're just gonna keep on truckin'"
      sleep 1
    end
  end
  begin
    files_service_ord.delete_container(d.key)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end


files_service_dfw.directories.each do |d|
  d.files.each do |f|
    begin
      files_service_dfw.delete_object(f.key)
    rescue
      puts "Failed to delete, so we're just gonna keep on truckin'"
      sleep 1
    end
  end
  begin
    files_service_dfw.delete_container(d.key)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end

puts "Deleting databases"

db_service_ord.instances.each do |i|
  begin
    db_service_ord.delete_instance(i.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end


db_service_dfw.instances.each do |i|
  begin
    db_service_dfw.delete_instance(i.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end

puts "Deleting Cloud Block Storage"

cbs_service_ord.volumes.each do |v|
  begin
    cbs_service_ord.delete_volume(v.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end


cbs_service_dfw.volumes.each do |v|
  begin
    cbs_service_dfw.delete_volume(v.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end

puts "Deleting load balancers"

lb_service_ord.load_balancers.each do |lb|
  begin
    lb_service_ord.delete_load_balancer(lb.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end


lb_service_dfw.load_balancers.each do |lb|
  begin
    lb_service_dfw.delete_load_balancer(lb.id)
  rescue
    puts "Failed to delete, so we're just gonna keep on truckin'"
    sleep 1
  end
end

puts "It feels so empty in here"
