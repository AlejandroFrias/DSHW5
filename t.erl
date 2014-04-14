-module (t).

-export([initAsh/0,
         init/0,
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

%% Alphabet (lower case and upper case) and space
-define (CHARS, lists:seq(97, 122) ++ lists:seq(65, 90) ++ [32]).

initAsh() ->
    Seed = init(),
    connect('node1@ash'),
    Seed.

%% Only need to call once to the daemon running and kernel started.
%% Also seeds the random to now() and returns the seed used for repeating the 
%% test if desired
init() ->
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([testy, shortnames]),
    {A1, A2, A3} = now(),
    utils:log("Seeding random with ~p", [{A1, A2, A3}]),
    random:seed(A1, A2, A3),
    {A1, A2, A3}.

%% Used to (re)connect to the original node for global registry access.
connect(Node) ->
    net_kernel:connect_node(Node).

%% Gets the pid of the storage process
getPid(ProcNum) ->
    global:whereis_name(utils:sname(ProcNum)).

%% Sends store request and waits for response
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

%% Sends retrieve request and waits for response
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

%% Sends first_key request and waits for response
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

%% Sends last_key request and waits for response
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

%% Sends num_keys request and waits for response
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

%% Sends node_list request and waits for response
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

%% Sends leave request
leave(ProcID) ->
    Ref = make_ref(),
    Dest = getPid(ProcID),
    Dest ! {self(), Ref, leave}.

%% Store many different in sequence
store_many_sequence(Num) ->
    done.
    
store_many_sequence(0, KeyValuePairs) ->
    utils:log("~p"),
    KeyValuePairs.


%% Store many different in parallel

%% Store many same in sequence

%% Store many same in parallel

randProc(M) ->
    ID = random:uniform(utils:pow2(M)),
    utils:sname(ID).

randKeyValue() ->
    Key = get_random_string(random:uniform(20) + 5, ?CHARS),
    Value = get_random_string(random:uniform(20) + 5, ?CHARS),
    {Key, Value}.

get_random_string(Length, AllowedChars) ->
    lists:foldl(fun(_, Acc) ->
                    [lists:nth(random:uniform(length(AllowedChars)),
                               AllowedChars)]
                        ++ Acc
                end, [], lists:seq(1, Length)).

