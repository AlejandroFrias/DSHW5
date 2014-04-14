%%% ----------------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% Tests and stuff.
%%% 
%%% Functions for by-hand testing as well as more built out tests are here
%%%-----------------------------------------------------------------------------



-module (t).

-export([initAsh/0,
         init/0,
         init/1,
         connect/1,
         get_pid/1,
         store/3,
         retrieve/2,
         first_key/1,
         last_key/1,
         num_keys/1,
         node_list/1,
         leave/1,
         store_many_sequence/2]).

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

%% If you desire to init with a given seed. Good for reproducing tests
init(Seed = {A1, A2, A3}) ->
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([testy, shortnames]),
    utils:log("Seeding random with ~p", [Seed]),
    random:seed(A1, A2, A3).

%% Used to (re)connect to the original node for global registry access.
connect(Node) ->
    net_kernel:connect_node(Node).

%% Gets the pid of the storage process
get_pid(ProcNum) ->
    case global:whereis_name(utils:sname(ProcNum)) of
        undefined ->
            utils:log("Storage Process ID ~p does not exist.", [ProcNum]);
        Pid ->
            Pid
    end.

%% Sends a store request and returns the Ref for it
send_store(Key, Value, ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, store, Key, Value},
    Ref.

%% Sends store request and waits for response
store(Key, Value, ProcID) ->
    Ref = send_store(Key, Value, ProcID),
    receive
	{Ref, stored, OldValue} ->
	    utils:log("{~p, ~p} stored, replacing ~p.", [Key, Value, OldValue]),
        Success = {ok, OldValue}
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for store confirmation of {~p, ~p}. sent to storage~p.", [Key, Value, ProcID]),
        Success = error
    end,
    Success.


%% Sends a retrieve request and returns the Ref for it
send_retrieve(Key, ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, retrieve, Key},
    Ref.

%% Sends retrieve request and waits for response
retrieve(Key, ProcID) ->
    Ref = send_retrieve(Key, ProcID),
    receive
    {Ref, retrieved, Value} ->
        utils:log("Retrieved ~p from key ~p.", [Value, Key]),
        Success = {ok, Value}
    after
    ?TIMEOUT ->
        utils:log("Timed out waiting for retrieved data of key ~p sent to storage~p.", [Key, ProcID]) ,
        Success = error
    end,
    Success.

%% Sends a first_key request and returns the Ref for it
send_first_key(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, first_key, ProcID},
    Ref.

%% Sends first_key request and waits for response
first_key(ProcID) ->
    Ref = send_first_key(ProcID),
    receive
	{Ref, result, Result} ->
	    utils:log("First key: ~p.", [Result]),
        Success = {ok, Result}
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) ,
        Success = error
    end,
    Success.

%% Sends a last_key request and returns the Ref for it
send_last_key(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, last_key, ProcID},
    Ref.

%% Sends last_key request and waits for response
last_key(ProcID) ->
    Ref = send_last_key(ProcID),
    receive
    {Ref, result, Result} ->
        utils:log("Last key: ~p.", [Result]),
        Success = {ok, Result}
    after
    ?TIMEOUT ->
        utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) ,
        Success = error
    end,
    Success.

%% Sends a num_keys request and returns the Ref for it
send_num_keys(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, num_keys, ProcID},
    Ref.

%% Sends num_keys request and waits for response
num_keys(ProcID) ->
    Ref = send_num_keys(ProcID),
    receive
    {Ref, result, Result} ->
        utils:log("Num keys: ~p.", [Result]),
        Success = {ok, Result}
    after
    ?TIMEOUT ->
        utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) ,
        Success = error
    end,
    Success.

%% Sends a node_list request and returns the Ref for it
send_node_list(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, node_list, ProcID},
    Ref.

%% Sends node_list request and waits for response
node_list(ProcID) ->
    Ref = send_node_list(ProcID),
    receive
	{Ref, result, Result} ->
	    utils:log("Node List: ~p.", [Result]),
        Success = {ok, Result}
    after
	?TIMEOUT ->
	    utils:log("Timed out waiting for result. sent to storage~p.", [ProcID]) ,
        Success = error
    end,
    Success.

%% Sends leave request
leave(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, leave}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                              TESTS YAY!!!                                %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Store many different key-value pairs in sequence (wait for response after every store)
%% Num is the number of store requests to make
store_many_sequence(Num, M) ->
    store_many_sequence(Num, M, dict:new()).

store_many_sequence(0, M, KeyValuePairs) ->
    case receive_many_sequence(KeyValuePairs, M) of
        true ->
            utils:log("++ SUCCESS store_many_sequence ++");
        false ->
            utils:log("-- FAIL store_many_sequence ++")
    end,
    KeyValuePairs;
store_many_sequence(Num, M, KeyValuePairs) ->
    {Key, Value} = rand_key_value(),
    NewKeyValuePairs = dict:store(Key, Value, KeyValuePairs),
    case store(Key, Value, rand_id(M)) of
        {ok, _OldValue} ->
            store_many_sequence(Num - 1, M, NewKeyValuePairs);
        error ->
            utils:log("-- FAIL store_many_sequence --"),
            NewKeyValuePairs
    end.

%% One at a time, confirm that each key-value pair exists.
receive_many_sequence(KeyValueDict, M) ->
    receive_many_sequence(KeyValueDict, M, dict:fetch_keys(KeyValueDict)).

receive_many_sequence(_KeyValueDict, _M, []) ->
    utils:log("++ SUCCESS receive_many_sequence"),
    true;
receive_many_sequence(Dict, M, [Key| Keys]) ->
    case retrieve(Key, rand_id(M)) of
        {ok, Value} ->
            case dict:fetch(Key, Dict) == Value of
                true ->
                    receive_many_sequence(Dict, M, Keys);
                false ->
                    utils:log("Expected: ~p. Retrieved ~p", [dict:fetch(Key, Dict), Value]),
                    utils:log("-- FAIL receive_many_sequence --"),
                    false
            end;
        error ->
            utils:log("-- FAIL receive_many_sequence --"),
            false
    end.

%% Store many different key-value pairs in parallel (wait for all responses at end)

%% Store many same in sequence

%% Store many same in parallel

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                       TEST HELPERS YAY!!!                                %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


rand_id(M) ->
    random:uniform(utils:pow2(M)) - 1.

rand_key_value() ->
    Key = get_random_string(random:uniform(20) + 5, ?CHARS),
    Value = get_random_string(random:uniform(20) + 5, ?CHARS),
    {Key, Value}.

get_random_string(Length, AllowedChars) ->
    lists:foldl(fun(_, Acc) ->
                    [lists:nth(random:uniform(length(AllowedChars)),
                               AllowedChars)]
                        ++ Acc
                end, [], lists:seq(1, Length)).

