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

These scripts only work for macs. They'll start new tabs. They expect the file
to be located in /home/usr/courses/DSHW5. If you want to use them, you may need
to change that or change the location of your files on knuth.


To init the first node:
  Usage: osascript init.scpt <user> <mac> <m> <node>

  Example: osascript init.scpt afrias ash 10 node1

To create every subsequent node:
  Usage: osascript node.scpt <user> <mac> <m> <node> <init_node>

  Example: osascript node.scpt afrias dittany 10 node2 node1@ash

To create 9 nodes for testing (m > 3):
  Usage: osascript test.scpt <user> <m>

  Example: osascript test.scpt afrias 10

Testing file used for sending message nicely:
=============================================

t.erl is the file we use to do our testing. It works best if node1@ash is the 
first node created. You can use our test.scpt described above.

To start:
  t:initAsh() to start kernal and connect to node1@ash (Returns a Seed that can be
              passed in for repeating of tests)

You can also use these:
  t:init() starts the kernal.
  t:connect(Node) connects to the first node, for global registry access.

Commands for each individual message exist. Each one waits for confirmation and 
reports it nicely:
  t:store(Key, Value, ProcID) 
  t:retrieve(Key, ProcID) 
  t:first_key(ProcID) 
  t:last_key(ProcID) 
  t:num_keys(ProcID) 
  t:node_list(ProcID) 
  t:leave(ProcID, M)

Before any store requests:
  t:test_empty(M) - tests that an empty system is as it should be. We assume 
                    that first_key and last_key should return no_value if there 
                    aren't any keys yet.

How to test the rest of system:
  t:test_store_basic(Num, M) - tests that things are stored and retrievable. 
              Sends store requests in parallel and in sequence. Tests that values
              are overwritten properly. Feel free to give it a large number of 
              store requests to make.

  t:test_back_up(Num, KillNum, M) - tests that the backup stays consistant after 
              killing KillNum amount of processes. It stores Num random pairs and 
              then checks that everything is still there after telling multiple 
              nodes to leave (with 5 seconds in between each leave)



Interesting Bugs We Ran Into:
=============================

We were trying to monitor a gen_server process rather than an entire erlang
node. When we then changed the global name of a process, the monitor thought
the connection was lost, causing our system to think the node died. We solved
this by using monitor_node instead. Jesse Wattsrussell helped us figure this
out.

We pulled the modular arithmetic out of the main file with helper functions in
utils.erl. We kept making the same mistake of modding a number and expecting it 
to be positive. We eventually had massive problems with modular arithmetic
and having various functions assume things about modular helper functions.



