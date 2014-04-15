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
         leave/2,
         test_store_basic/2,
         test_empty/1,
         test_back_up/3,
         store_many_sequence/2,
         store_many_parallel/2,
         retrieve_many_sequence/2]).

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
    case net_kernel:connect_node(Node) of
        true ->
            utils:log("Connected Successfully to ~p", [Node]);
        _Other ->
            utils:log("Failed to Connect to ~p", [Node])
    end.

%% Gets the pid of the storage process
get_pid(ProcNum) ->
    case global:whereis_name(utils:sname(ProcNum)) of
        undefined ->
            utils:log("ERROR: Storage Process ID ~p does not exist.", [ProcNum]);
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
    store(Key, Value, ProcID, true).

store(Key, Value, ProcID, Debug) ->
    Ref = send_store(Key, Value, ProcID),
    receive
	{Ref, stored, OldValue} ->
	    utils:dlog("{~p, ~p} stored, replacing ~p.", [Key, Value, OldValue], Debug),
        Success = {ok, OldValue}
    after
	?TIMEOUT ->
	    utils:dlog("Timed out waiting for store confirmation of {~p, ~p}. sent to storage~p.", [Key, Value, ProcID], Debug),
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
    retrieve(Key, ProcID, true).

retrieve(Key, ProcID, Debug) ->
    Ref = send_retrieve(Key, ProcID),
    receive
    {Ref, retrieved, Value} ->
        utils:dlog("Retrieved ~p from key ~p.", [Value, Key], Debug),
        Success = {ok, Value}
    after
    ?TIMEOUT ->
        utils:dlog("Timed out waiting for retrieved data of key ~p sent to storage~p.", [Key, ProcID], Debug) ,
        Success = error
    end,
    Success.

%% Sends a first_key request and returns the Ref for it
send_first_key(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, first_key},
    Ref.

%% Sends first_key request and waits for response
first_key(ProcID) ->
    first_key(ProcID, true).

first_key(ProcID, Debug) ->
    Ref = send_first_key(ProcID),
    receive
	{Ref, result, Result} ->
	    utils:dlog("First key: ~p.", [Result], Debug),
        Success = {ok, Result}
    after
	?TIMEOUT ->
	    utils:dlog("Timed out waiting for result. sent to storage~p.", [ProcID], Debug) ,
        Success = error
    end,
    Success.

%% Sends a last_key request and returns the Ref for it
send_last_key(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, last_key},
    Ref.

%% Sends last_key request and waits for response
last_key(ProcID) ->
    last_key(ProcID, true).

last_key(ProcID, Debug) ->
    Ref = send_last_key(ProcID),
    receive
    {Ref, result, Result} ->
        utils:dlog("Last key: ~p.", [Result], Debug),
        Success = {ok, Result}
    after
    ?TIMEOUT ->
        utils:dlog("Timed out waiting for result. sent to storage~p.", [ProcID], Debug),
        Success = error
    end,
    Success.

%% Sends a num_keys request and returns the Ref for it
send_num_keys(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, num_keys},
    Ref.

%% Sends num_keys request and waits for response
%% Returns {ok, NumKeys} or error
num_keys(ProcID) ->
    num_keys(ProcID, true).

num_keys(ProcID, Debug) ->
    Ref = send_num_keys(ProcID),
    receive
    {Ref, result, Result} ->
        utils:dlog("Num keys: ~p.", [Result], Debug),
        Success = {ok, Result}
    after
    ?TIMEOUT ->
        utils:dlog("Timed out waiting for result. sent to storage~p.", [ProcID], Debug),
        Success = error
    end,
    Success.

%% Sends a node_list request and returns the Ref for it
%% Returns the Ref used for the request
send_node_list(ProcID) ->
    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, node_list},
    Ref.

%% Sends node_list request and waits for response
%% Returns {ok, NodeList} or error
node_list(ProcID) ->
    node_list(ProcID, true).

node_list(ProcID, Debug) ->
    Ref = send_node_list(ProcID),
    receive
	{Ref, result, Result} ->
	    utils:dlog("Node List: ~p.", [Result], Debug),
        Success = {ok, Result}
    after
	?TIMEOUT ->
	    utils:dlog("Timed out waiting for result. sent to storage~p.", [ProcID], Debug),
        Success = error
    end,
    Success.

%% Sends leave request
leave(ProcID, M) ->
    leave(ProcID, M, true).

leave(ProcID, M, Debug) ->
    utils:dlog("Telling storage~p to leave.", [ProcID], Debug),
    {BeforeNumKeys, BeforeFirstKey, BeforeLastKey} = get_state(M),
    {ok, BeforeNodeList} = node_list(ProcID, false),
    BeforeStorageProcIDs = lists:sort([utils:getID(N) || N <- global:registered_names(), utils:isStorage(N)]),

    Ref = make_ref(),
    Dest = get_pid(ProcID),
    Dest ! {self(), Ref, leave},
    timer:sleep(5000),

    {AfterNumKeys, AfterFirstKey, AfterLastKey} = get_state(M),
    {ok, AfterNodeList} = node_list(ProcID, false),
    AfterStorageProcIDs = lists:sort([utils:getID(N) || N <- global:registered_names(), utils:isStorage(N)]),

    NumKeysSuccess = (AfterNumKeys == BeforeNumKeys),
    FirstKeySuccess = (AfterFirstKey == BeforeFirstKey),
    LastKeySuccess = (AfterLastKey == BeforeLastKey),
    LeaveSuccess = (length(BeforeNodeList) == length(AfterNodeList) - 1),
    StorageSuccess = (BeforeStorageProcIDs == AfterStorageProcIDs),

    case (NumKeysSuccess and FirstKeySuccess and LastKeySuccess and LeaveSuccess and StorageSuccess) of
        true ->
            utils:dlog("Leave was successful.", Debug),
            true;
        false ->
            utils:log("FAIL leave. NumKeysSuccess: ~p FirstKeySuccess: ~p LastKeySuccess: ~p LeaveSuccess: ~p StorageSuccess: ~p",
                [NumKeysSuccess, FirstKeySuccess, LastKeySuccess, LeaveSuccess, StorageSuccess]),
            false
    end.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                              TESTS YAY!!!                                %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Tests that an empty untouched system is as it should be. Assumes no requests
%% have been made before this function is called after a system is set up
test_empty(M) ->
    Good1 = test_num_keys_all(0, utils:pow2(M) - 1),
    Good2 = test_first_keys_all([], utils:pow2(M) - 1) and Good1,
    Good3 = test_num_keys_all_parallel(0, utils:pow2(M) - 1) and Good2,
    Good4 = test_last_keys_all_parallel([], utils:pow2(M) - 1) and Good3,
    Good4.


%% Tests that key-value pairs are stored and retrievable
%% @param Num Number of store requests to make
test_store_basic(Num, M) ->
    utils:log("BEGIN Basic Store Test"),
    {StartNumKeys, StartFirstKey, StartLastKey} = get_state(M),

    {ok, Dict} = store_many_sequence(Num, M),

    {MinKey, _} = lists:min(dict:to_list(Dict)),
    {MaxKey, _} = lists:max(dict:to_list(Dict)),
    {EndNumKeys, EndFirstKey, EndLastKey} = get_state(M),

    RetrieveSuccess = retrieve_many_sequence(Dict, M),
    NumKeySuccess = (StartNumKeys + dict:size(Dict) == EndNumKeys),
    FirstKeySuccess = (EndFirstKey == key_min(MinKey, StartFirstKey)),
    LastKeySuccess = (EndLastKey == key_max(MaxKey, StartLastKey)),
    OldValueSuccess = store_many_parallel(Num, M),


    case (RetrieveSuccess and NumKeySuccess and FirstKeySuccess and LastKeySuccess and OldValueSuccess) of
        true ->
            utils:log("++ PASS test_store_basic");
        false ->
            utils:log("-- FAIL test_store_basic. RetrieveSuccess: ~p NumKeySuccess: ~p FirstKeySuccess: ~p LastKeySuccess: ~p OldValueSuccess: ~p",
                [RetrieveSuccess, NumKeySuccess, FirstKeySuccess, LastKeySuccess, OldValueSuccess])
    end.



%% Tests that stores are backed up properly, by making node leave and trying to
%% retrieve after re-balance.
%% @param Num Number of store requests to make
%% @param Kill Number of nodes to kill
test_back_up(Num, Kill, M) ->
    utils:log("BEGIN test_back_up"),
    {StartNumKeys, StartFirstKey, StartLastKey} = get_state(M),
    {ok, Dict} = store_many_sequence(Num, M),

    LeaveSuccesses = [leave(rand_id(M), M, false) || _X <- lists:seq(1, Kill)],
    LeaveSuccess = not lists:member(false, LeaveSuccesses),
    
    {MinKey, _} = lists:min(dict:to_list(Dict)),
    {MaxKey, _} = lists:max(dict:to_list(Dict)),
    {EndNumKeys, EndFirstKey, EndLastKey} = get_state(M),

    RetrieveSuccess = retrieve_many_sequence(Dict, M),
    NumKeySuccess = (StartNumKeys + dict:size(Dict) == EndNumKeys),
    FirstKeySuccess = (EndFirstKey == key_min(MinKey, StartFirstKey)),
    LastKeySuccess = (EndLastKey == key_max(MaxKey, StartLastKey)),

    case (RetrieveSuccess and NumKeySuccess and FirstKeySuccess and LastKeySuccess and LeaveSuccess) of
        true ->
            utils:log("++ PASS test_back_up");
        false ->
            utils:log("-- FAIL test_back_up. RetrieveSuccess: ~p NumKeySuccess: ~p FirstKeySuccess: ~p LastKeySuccess: ~p LeaveSuccess: ~p",
                [RetrieveSuccess, NumKeySuccess, FirstKeySuccess, LastKeySuccess, LeaveSuccess])
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                       TEST HELPERS YAY!!!                                %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Sends a num_key request to all storage process up to the given one and
%% checks that they are the Expected Value
%% Returns boolean if successful or not
test_num_keys_all(ExpectedNum, 0) ->
    utils:log("Num Keys: ~p",[ExpectedNum]),
    true;
test_num_keys_all(ExpectedNum, ProcID) ->
    case num_keys(ProcID, false) of
        {ok, ExpectedNum} ->
            test_num_keys_all(ExpectedNum, ProcID - 1);
        {ok, Other} ->
            utils:log("ERROR Num Keys - Expected ~p. Got ~p", [ExpectedNum, Other]), 
            false;
        error ->
            utils:log("ERROR Num Keys - num_keys request sent to ~p never returned", [ProcID]),
            false
    end.

test_first_keys_all(ExpectedKey, 0) ->
    utils:log("First Keys: ~p",[ExpectedKey]),
    true;
test_first_keys_all(ExpectedKey, ProcID) ->
    case first_key(ProcID, false) of
        {ok, ExpectedKey} ->
            test_first_keys_all(ExpectedKey, ProcID - 1);
        {ok, Other} ->
            utils:log("ERROR First Key - Expected ~p. Got ~p", [ExpectedKey, Other]), 
            false;
        error ->
            utils:log("ERROR First Key - first_key request sent to ~p never returned", [ProcID]),
            false
    end.


test_num_keys_all_parallel(ExpectedNum, ProcID) ->
    Refs = [send_num_keys(ProcessID) || ProcessID <- lists:seq(0, ProcID)],
    receive_snap_all(ExpectedNum, Refs, num_keys).
    

receive_snap_all(ExpectedVal, [], Type) ->
  utils:log("~p Parallel: ~p",[Type, ExpectedVal]),
  true;
receive_snap_all(ExpectedVal, [Ref | Refs], Type) ->
    receive 
        {Ref, result, ExpectedVal} -> receive_snap_all(ExpectedVal, Refs, Type);
        {Ref, result, OtherNum} -> 
            utils:log("ERROR Parallel ~p - Expected ~p. Got ~p", [Type, ExpectedVal, OtherNum]), 
            false
    after ?TIMEOUT ->
        utils:log("ERROR Parallel ~p - ~p request with ref ~p never returned", [Type, Type, Ref]),
        false
    end.

test_last_keys_all_parallel(ExpectedKey, ProcID) ->
    Refs = [send_last_key(ProcessID) || ProcessID <- lists:seq(0, ProcID)],
    receive_snap_all(ExpectedKey, Refs, last_key).
    

%% Store many different key-value pairs in sequence (wait for response after every store)
%% Num is the number of store requests to make
store_many_sequence(Num, M) ->
    utils:log("BEGIN store_many_sequence"),
    store_many_sequence(Num, M, dict:new()).

store_many_sequence(0, _M, KeyValuePairs) ->
    utils:log("++ PASS store_many_sequence"),
    {ok, KeyValuePairs};
store_many_sequence(Num, M, KeyValuePairs) ->
    {Key, Value} = rand_key_value(),
    NewKeyValuePairs = dict:store(Key, Value, KeyValuePairs),
    case store(Key, Value, rand_id(M), false) of
        {ok, _OldValue} ->
            store_many_sequence(Num - 1, M, NewKeyValuePairs);
        error ->
            utils:log("-- FAIL store_many_sequence --"),
            error
    end.


store_many_parallel(Num, M) ->
    RandKeyValues = [{rand_key_value(), rand_id(M)} || _N <- lists:seq(1, Num)],
    RefKeys = [{send_store(Key, Value, ID), {Key, Value}} || {{Key, Value}, ID} <- RandKeyValues],
    ReceiveSucceeded = receive_store_all(RefKeys),

    %Now try overwriting
    %Send overwrites
    NewRefKeys = [{send_store(Key, element(2, rand_key_value()), rand_id(M)), {Key, Value}} || {_Ref, {Key, Value}} <- RefKeys],
    OverwriteSucceeded = receive_overwrite_all(NewRefKeys),
    ReceiveSucceeded and OverwriteSucceeded.
    

receive_store_all([]) ->
  utils:log("store Parallel: Succeeded."),
  true;
receive_store_all([{Ref, {_Key, _Value}} | Rest]) ->
    receive 
        {Ref, stored, _OldValue} -> receive_store_all(Rest)
    after ?TIMEOUT ->
        utils:log("ERROR Parallel store request with ref ~p never returned", [Ref]),
        false
    end.

receive_overwrite_all([]) ->
  utils:log("overwrite Parallel: Succeeded."),
  true;
receive_overwrite_all([{Ref, {_Key, OldValue}} | Rest]) ->
    receive 
        {Ref, stored, OldValue} -> receive_overwrite_all(Rest)
    after ?TIMEOUT ->
        utils:log("ERROR Parallel overwrite request with ref ~p never returned", [Ref]),
        false
    end.


%% One at a time, confirm that each key-value pair exists.
retrieve_many_sequence(KeyValueDict, M) ->
    utils:log("BEGIN retrieve_many_sequence"),
    retrieve_many_sequence(KeyValueDict, M, dict:fetch_keys(KeyValueDict)).

retrieve_many_sequence(_KeyValueDict, _M, []) ->
    utils:log("++ PASS retrieve_many_sequence"),
    true;
retrieve_many_sequence(Dict, M, [Key| Keys]) ->
    case retrieve(Key, rand_id(M), false) of
        {ok, Value} ->
            case dict:fetch(Key, Dict) == Value of
                true ->
                    retrieve_many_sequence(Dict, M, Keys);
                false ->
                    utils:log("Expected: ~p. Retrieved ~p", [dict:fetch(Key, Dict), Value]),
                    utils:log("-- FAIL retrieve_many_sequence --"),
                    false
            end;
        error ->
            utils:log("-- FAIL retrieve_many_sequence --"),
            false
    end.

%% Get the current state of the system (minus the node list)
get_state(M) ->
    {ok, NumKeys} = num_keys(rand_id(M), false),
    {ok, FirstKey} = first_key(rand_id(M), false),
    {ok, LastKey} = last_key(rand_id(M), false),
    utils:log("State: ~nNumber of Keys => ~p.~nFirst Key => ~p.~nLast Key => ~p.", 
         [NumKeys, FirstKey, LastKey]),
    {NumKeys, FirstKey, LastKey}.

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

key_min(A, B) ->
    case B == no_value of
        true ->
            A;
        false ->
            min(A, B)
    end.

key_max(A, B) ->
    case B == no_value of
        true ->
            A;
        false ->
            max(A, B)
    end.
