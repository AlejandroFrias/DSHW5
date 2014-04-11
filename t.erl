-module (t).

-export([init/0, connect/1, getPid/1, store/3, retrieve/2]).

-define(STORAGEPROCNAME (Num), list_to_atom("storage" ++ integer_to_list(Num))).

-define(HANDLERPROCNAME (Num), list_to_atom("handler" ++ integer_to_list(Num))).

-define (TIMEOUT, 10000).

% Only need to call once to the daemon running and kernel started.
init() ->
  _ = os:cmd("epmd -daemon"),
  net_kernel:start([testy, shortnames]).

% used to reconnect to the original node.
connect(Node) ->
  net_kernel:connect_node(Node).

% Gets the pid of the storage process
getPid(ProcNum) ->
  global:whereis_name(?STORAGEPROCNAME(ProcNum)).

% sends store message and waits for response
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

% sends retrieve message and waits for response
retrieve(Key, ProcID) ->
  Ref = make_ref(),
  Dest = getPid(ProcID),
  Dest ! {self(), Ref, retrieve, Key},
  receive
    {Ref, retrieved, Value} ->
      utils:log("~p retrieved from key ~p.", [Value, Key])
    after
      ?TIMEOUT ->
        utils:log("Timed out waiting for retrieved data of key ~p sent to storage~p.", [Key, ProcID]) 
  end.