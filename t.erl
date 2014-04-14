-module (t).

-export([init/0,
         connect/1,
         getPid/1,
         store/3,
         retrieve/2,
         firstKey/1,
         lastKey/1,
         numKeys/1,
         nodeList/1,
	 leave/1]).

-define (TIMEOUT, 10000).

%% Only need to call once to the daemon running and kernel started.
init() ->
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([testy, shortnames]).

%% used to reconnect to the original node.
connect(Node) ->
    net_kernel:connect_node(Node).

%% Gets the pid of the storage process
getPid(ProcNum) ->
    global:whereis_name(utils:sname(ProcNum)).

%% sends store message and waits for response
store(Key, Value, ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, store, Key, Value},
    receive
	{Ref, stored, OldValue} ->
	    utils:log("{~p, ~p} stored, replacing ~p.", [Key, Value, OldValue])
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for store confirmation of {~p, ~p}. sent to storage~p.", [Key, Value, ProcID]) 
    end.

%% sends retrieve message and waits for response
retrieve(Key, ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, retrieve, Key},
    receive
	{Ref, retrieved, Value} ->
	    utils:log("Retrieved ~p from key ~p.", [Value, Key])
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for retrieved data of key ~p sent to storage~p.", [Key, ProcID]) 
    end.

%% sends store message and waits for response
firstKey(ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, first_key},
    receive
	{Ref, result, Result} ->
	    utils:log("First key: ~p.", [Result])
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) 
    end.

lastKey(ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, last_key},
    receive
	{Ref, result, Result} ->
	    utils:log("Last key: ~p.", [Result])
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) 
    end.


numKeys(ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, num_keys},
    receive
	{Ref, result, Result} ->
	    utils:log("Num keys: ~p.", [Result])
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) 
    end.

nodeList(ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, node_list},
    receive
	{Ref, result, Result} ->
	    utils:log("Node List: ~p.", [Result])
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) 
    end.

leave(ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, leave}.
