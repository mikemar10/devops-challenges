#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike.martin@rackspace.com>
# Challenge 12: Write an application that will create a route in mailgun so
# that when an email is sent to <YourSSO>@apichallenges.mailgun.org it calls
# your Challenge 1 script that builds 3 servers.
# Assumptions:
# Assume that challenge 1 can be kicked off by
# accessing http://cldsrvr.com/challenge1 (I am aware this doesn't work. You
# just need to make sure that your message is getting posted to that URL)
# DO NOT PUT THE API KEY IN YOUR SCRIPT. Assume the Mailgun API key exists
# at ~/.mailgunapi. Assume no formatting, the api key will be the only data
# in the file.

require "bundler/setup"
require "multimap"
require "restclient"

api_key = File.read(File.expand_path("~/.mailgunapi")).strip()

puts "Creating new route..."
data = Multimap.new
data[:priority] = 1
data[:description] = "Route that runs my challenge1 script when an email is sent to my SSO"
data[:expression] = "match_recipient('mike.martin@apichallenges.mailgun.org')"
data[:action] = "forward('http://cldsrvr.com/challenge1')"
data[:action] = "stop()"
puts RestClient.post("https://api:#{api_key}@api.mailgun.net/v2/routes", data)

puts "le fin"
