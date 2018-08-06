---
title: "Restricting Thrift clients to specific IP addresses with Twisted"
date: 2013-11-11 17:17:11.872022
permalink: /restricting-thrift-clients-to-specific-ip-addresses-with-twisted
---

[Apache Thrift](https://thrift.apache.org/) is pretty awesome - you can build [Twisted](https://twistedmatrix.com/) bindings for your Thrift interface file that work fantastically. There is one thing that took me a while to figure out: I want to restrict clients connecting to the service to a specific set of IP addresses stored in a database.

There were three ways I could see to do this:

   1. Automate UFW or iptables to restrict access to the port when the list of IP addresses is changed
   2. Make Twisted connect to the database and query it
   3. Make Twisted make a HTTP request to a service which then queries the database

I opted for #3, as #1 is hardly portable and #2 isn't maintainable (for various reasons). Unfortunately Twisted doesn't have built in support for this, so the way I managed it is to check it inside the connectionMade method of the protocol:

```python
class AuthenticatingThriftProtocol(TTwisted.ThriftServerProtocol):
	@defer.inlineCallbacks
	def connectionMade(self):
		self.transport.pauseProducing()
		log.msg("Authenticating host")
		result = yield checkHostAgainstWhitelist( self.transport.getHost() )
		if result == False:
	    		self.transport.loseConnection()
		else:
	    		self.transport.resumeProducing()
```

The transport has to be paused while authenticating to stop clients making requests while the authentication process is in progress (Twisted is event driven, so while checkHostAgainstWhitelist is in progress other data could be sent and processed). Once the IP address has been checked then the connection is either dropped if the IP address is not allowed or the transport is resumed, which will process any buffered data sent by the client while it was being authenticated.

The next step would be to tie it into the [cred framework](https://twistedmatrix.com/documents/current/core/howto/cred.html), but that can wait until another time.
    