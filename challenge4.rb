#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 4: Write a script that uses Cloud DNS to create a new A record when passed a FQDN and 
# IP address as arguments. Worth 1 Point

require "inifile"
require "openstack/compute"