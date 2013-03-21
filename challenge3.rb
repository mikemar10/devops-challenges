#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 3: Write a script that accepts a directory as an argument as well as a container name. 
# The script should upload the contents of the specified directory to the container (or create it if it doesn't exist). 
# The script should handle errors appropriately. (Check for invalid paths, etc.) Worth 2 Points

require "inifile"
require "openstack/compute"
