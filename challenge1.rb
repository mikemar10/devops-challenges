#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 1: Write a script that builds three 512 MB Cloud
# Servers that following a similar naming convention. (ie., web1, web2,
# web3) and returns the IP and login credentials for each server. Use any
# image you want. Worth 1 point

require "inifile"
require "openstack/compute"

@cloud_servers_ng_dfw = OpenStack::Compute::Connection.new(
:username => @credentials[:username], 
:api_key => @credentials[:api_key], 
:auth_url => @credentials[:auth_url], 
:auth_method => 'rax-kskey', 
:region => 'dfw', 
:service_name => 'cloudServersOpenStack')


@cloud_servers_ng_ord = OpenStack::Compute::Connection.new(
:username => @credentials[:username], 
:api_key => @credentials[:api_key],
:auth_url => @credentials[:auth_url], 
:auth_method => 'rax-kskey',
:region => 'ord', 
:service_name => 'cloudServersOpenStack')


