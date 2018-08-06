---
title: "Displaying a processes output on a web page with Websockets and Python"
date: 2013-07-15 18:40:38.700955
tags:
    - experiments
---

A few days ago a colleague of mine asked me how you would pipe the standard output of a process into a browser. I hacked around for a few hours and came up with a websockets based solution (using [Twisted](https://www.twistedmatrix.com) and [Autobahn.ws](https://autobahn.ws/python)) that you can see below (**Your browser needs to support WebSockets, sorry IE9 and lower**).

This is a live instant-updating tail of this sites web logs (tail -F access_log) with IP addresses omitted:

*Edit*: Offline for now :(


The code is very simple and can be found below or [here on Github](https://github.com/orf/websocket_stdout_example). It works like so:

When the file is executed by Python a *WebSocketProcessOutputterThingFactory* is created, which in turn creates a *ProcessProtocol*. The *ProcessProtocol* runs a command of your choosing (specified via the command line) and buffers the last 10 lines in memory. While this is chugging along a websocket client can connect on port 9000 and is added to a list of connected clients, which is managed by the *WebSocketProcessOutputterThingFactory*. Whenever the *ProcessProtocol* receives output it passes it to the *WebSocketProcessOutputterThingFactory* which then blasts that message to all the connected clients via their websocket connection. A bit of JavaScript can then display the data any way it likes.

All of this happens inside Twisted's event loop, which is pretty cool because its event-driven nature allows you to mix and match protocols (in this case a ProcessProtocol and Websockets), you could send the output over any protocol (IRC, a HTTP stream, whatever) if you wanted.

Overall I'm pretty impressed with Autobahn, even though the docs are a bit crap.

### How to use:
Grab the code from [the Github repo](https://github.com/orf/websocket_stdout_example). You need to install [Twisted](https://twistedmatrix.com/) and [AutoBahn](https://pypi.python.org/pypi/autobahn), and if you are running this on Windows you also require [PyWin32](https://sourceforge.net/projects/pywin32/). Once those are all installed you can run the script like so:

    python runner.py [shell command to run]

e.g:

    python runner.py tail -F /var/log/nginx/access_log

or:

    python runner.py /bin/sh -c "tail -F /var/log/nginx/access.log -n 150 | grep -v static --line-buffered | awk '{\$1=\"\"; print}'"

This should start a websocket server on port 9000, and the supplied index.html should connect to this and display the output. The .html file attempts to connect to localhost:9000, so you may need to change this if your .py file is running somewhere else or on a different port.

The code:

```python
from twisted.internet import reactor, protocol
from autobahn.websocket import WebSocketServerFactory, \
                               WebSocketServerProtocol, \
                               listenWS
from twisted.python.log import startLogging, msg
import sys
startLogging(sys.stdout)

# Examples:
# runner.py /bin/sh -c "tail -f /var/log/nginx/access.log | grep -v secret_admin_page" --line-buffered | awk '{\$1=\"\"; print}'"
# runner.py tail tail -F /var/log/nginx/access.log

COMMAND_NAME = sys.argv[1]
COMMAND_ARGS = sys.argv[1:]
LOCAL_ONLY = False
DEBUG = True


class ProcessProtocol(protocol.ProcessProtocol):
    """ I handle a child process launched via reactor.spawnProcess.
    I just buffer the output into a list and call WebSocketProcessOutputterThingFactory.broadcast when
    any new output is read
    """
    def __init__(self, websocket_factory):
        self.ws = websocket_factory
        self.buffer = []

    def outReceived(self, message):
        self.ws.broadcast(message)
        self.buffer.append(message)
        self.buffer = self.buffer[-10:] # Last 10 messages please

    def errReceived(self, data):
        print "Error: %s" % data


# https://autobahn.ws/python
class WebSocketProcessOutputterThing(WebSocketServerProtocol):
    """ I handle a single connected client. We don't need to do much here, simply call the register and un-register
    functions when needed.
    """
    def onOpen(self):
        self.factory.register(self)
        for line in self.factory.process.buffer:
            self.sendMessage(line)

    def connectionLost(self, reason):
        WebSocketServerProtocol.connectionLost(self, reason)
        #super(WebSocketProcessOutputterThing, self).connectionLost(self, reason)
        self.factory.unregister(self)


class WebSocketProcessOutputterThingFactory(WebSocketServerFactory):
    """ I maintain a list of connected clients and provide a method for pushing a single message to all of them.
    """
    protocol = WebSocketProcessOutputterThing

    def __init__(self, *args, **kwargs):
        WebSocketServerFactory.__init__(self, *args, **kwargs)
        #super(WebSocketProcessOutputterThingFactory, self).__init__(self, *args, **kwargs)
        self.clients = []
        self.process = ProcessProtocol(self)
        reactor.spawnProcess(self.process,COMMAND_NAME, COMMAND_ARGS, {}, usePTY=True)

    def register(self, client):
        msg("Registered client %s" % client)
        if not client in self.clients:
            self.clients.append(client)

    def unregister(self, client):
        msg("Unregistered client %s" % client)
        if client in self.clients:
            self.clients.remove(client)

    def broadcast(self, message):
        for client in self.clients:
            client.sendMessage(message)


if __name__ == "__main__":
    print "Running process %s with args %s" % (COMMAND_NAME, COMMAND_ARGS)
    factory = WebSocketProcessOutputterThingFactory("ws://%s:9000" % ("localhost" if LOCAL_ONLY else "0.0.0.0"), debug=False)
    listenWS(factory)
    reactor.run()
```
    