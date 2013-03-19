#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 5: Write a script that creates a Cloud Database instance. This instance should contain at least one 
# database, and the database should have at least one user that can connect to it. Worth 1 Point

require "inifile"
require "openstack/compute"
