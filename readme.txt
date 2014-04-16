Distributed Systems Homework 5: Distributed Key-Value Storage
=============================================================

* Created: 2014-03-29

Team Members:
=============

* Alejandro Frias
* Ravi Kumar
* David Scott


Testing Script Usage:
=====================

To init the first node:
  osascript init.scpt <user> <mac> <m> <node>

  osascript init.scpt afrias ash 10 node1

To create every subsequent node:
  osascript node.scpt <user> <mac> <m> <node> <init_node>

  osascript node.scpt afrias dittany 10 node2 node1@ash

To create 9 nodes for testing (m > 3):
  osascript test.scpt <user> <m>

Testing file used for sending message nicely:
=============================================

t.erl is the file we use to do individual hand tests.

t:init() starts the kernal.
t:connect(Node) connects to the first node, for global registry access.

commands for sending each request to a desired process are also there. They wait
for the proper response, too, giving a nice error or success message.


Interesting Bugs We Ran Into:
=============================

We were trying to monitor a gen_server process rather than an entire erlang
node. When we then changed the global name of a process, the monitor thought
the connection was lost, causing our system to think the node died. We solved
this by using monitor_node instead. Jesse Watts-Russell helped us figure this
out.

We pulled the modular arithmetic out of the main file with helper functions in
utils.erl. We kept making the same mistake of modding a number and expecting it 
to be positive. We eventually had massive problems with modular arithmetic
and having various functions assume things about modular helper functions.

And so many more.................................................................