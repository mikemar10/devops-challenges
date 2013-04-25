This is a collection of bugs in Fog and/or Rackspace products I stumbled across during this process.

==ALL==
So far my region selection seems to be failing for challenge3 and challenge5.

==Cloud Databases==
===Fog===
Setting the rackspace_region field appears to do nothing.  I used :ord but my databases built in dfw.
Missing ability to add single database for a user, had to add as single database as though i were adding many.

===Control Panel===
Issuing a delete on the details page of a database results in a 500
