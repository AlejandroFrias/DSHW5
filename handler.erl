%%% -------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% A Storage Process implementation.
%%%--------------------------------------------------------------------


-module(handler).
-behavior(gen_server).

%% External exports
%-export([init/1]).

%% gen_server callbacks
-export([init/1, 
	  handle_call/3, 
	  handle_cast/2, 
	  handle_info/2, 
	  code_change/3, 
	  terminate/2]).

-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).
-define(KEY, 1).
-define(VAL, 2).
-define(ID, 3).

-define(m, S#state.m).
-define(myID, S#state.myID).
-define(nextNodeID, S#state.nextNodeID).
-define(myBackup, S#state.myBackup).
-define(minKey, S#state.minKey).
-define(maxKey, S#state.maxKey).
-define(myBackupSize, S#state.myBackupSize).
-define(myInProgressRefs, S#state.myInProgressRefs).
-define(myAllDataAssembling, S#state.myAllDataAssembling).
-define(myProcsWaitingFor, S#state.myProcsWaitingFor).

-record(state, {m, myID, nextNodeID, myBackup, minKey, maxKey, myBackupSize,
	       myInProgressRefs, myAllDataAssembling, myProcsWaitingFor}).
%% myInProgressRefs is a list of refs for messages for *key computations I started
%  myAllDataAssembling - when we pull all data from nodes, we need a place to keep it while we get it all.
%  myProcsWaitingFor - the number of processes that still haven't sent us their data. 
%    See all data send and all data request messages

%Start up everything as the first node in a system
%Start ID will always be 0
init({M, MyID}) ->
	%net_kernel:start([node(), shortnames]),
	%ConnectResult = net_kernel:connect_node(OriginProcess),
    %utils:log("Connecting to ~w, result is: ~w", [OriginProcess, ConnectResult]),
    timer:sleep(1000),

	utils:log("Handler starting with node ID ~w and no next ID", [MyID]),
	utils:log("My node name is ~w", [node()]),
	Names = global:registered_names(),
  	utils:log("Registered names (first handler): ~w~n", [Names]),

	startAllSPs(0, (twoM(M)) - 1),
	utils:log("Handler started successfully."),
	{ok, #state{m = M, myID = MyID, nextNodeID = 0, 
		myBackup = dict:new(), minKey = [], maxKey = [], myBackupSize = 0,
		myInProgressRefs = [], myAllDataAssembling = dict:new(), myProcsWaitingFor = 0}}; %Fix these keys

%Start up everything as a non-first node in a system
init({M, MyID, NextNodeID}) -> 
	utils:log("Handler starting with node ID ~w and next ID ~w", [MyID, NextNodeID]),
	utils:log("My node name is ~w", [node()]),
	Names = global:registered_names(),
  	io:format("Registered names (new handler): ~w~n", [Names]),

	startAllSPs(0, (twoM(M)) - 1),
	{ok, #state{m = M, myID = MyID, nextNodeID = NextNodeID, 
		myBackup = dict:new(), minKey = [], maxKey = [], myBackupSize = 0,
		myInProgressRefs = [], myAllDataAssembling = dict:new(), myProcsWaitingFor = 0}}. %Fix these keys



handle_call(getState, _, S) ->
	{noreply, S}.

% Receives a backup_store message. Should forward to next node if its from it's 
% own storage process, or, if not, store in back up and tell outside world a 
% confirmation of store
handle_cast(Msg = {Pid, Ref, backup_store, Key, Value, ProcessID}, S) ->
	case isMyProcess(ProcessID, S) of
		true ->
			gen_server:cast({global, ?HANDLERPROCNAME(?nextNodeID)}, Msg),
			{noreply, S};
		false ->
			case lists:keyfind(Key, ?KEY, ?myBackup) of
				false ->
					OldValue = no_value,
					NewBackup = [{Key, Value, ProcessID} | ?myBackup],
					NewBackupSize = ?myBackupSize + 1;
				OldBackupData = {_Key, Val, _ID} ->
					OldValue = Val,
					NewBackup = [{Key, Value, ProcessID} | lists:delete(OldBackupData, ?myBackup) ],
					NewBackupSize = ?myBackupSize
			end,
			% Message the outside world that the value was stored
			Pid ! {Ref, stored, OldValue},

			% Store the value and update min, max, and number of keys
			NewMinKey = updateMinKey(Key, S),
			NewMaxKey = updateMaxKey(Key, S),
			{noreply, S#state{myBackup = NewBackup,
			                  myBackupSize = NewBackupSize,
			                  minKey = NewMinKey,
			                  maxKey = NewMaxKey} }
	end;

%Getting a message from one of our SPs looking for the first key
handle_cast({Pid, Ref, first_key}, S) ->
	NextHandler = ?nextNodeID,
	MyFirstKey = ?minKey, 
	OldInProgressRefs = ?myInProgressRefs,

	NewInProgressRefs = [Ref | OldInProgressRefs],

	gen_server:cast({global, ?HANDLERPROCNAME(NextHandler)}, {Pid, Ref, first_key, MyFirstKey}),

	{noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%Getting a message from another handler about first keys
handle_cast({Pid, Ref, first_key, ComputationSoFar}, S = #state{myInProgressRefs = InProgressRefs}) ->
	InProgressRefs = ?myInProgressRefs,

	case list:member(Ref, InProgressRefs) of
		true -> 
			Pid ! {Ref, result, ComputationSoFar},

			NewInProgressRefs = lists:delete(Ref, InProgressRefs),

			{noreply, S#state{myInProgressRefs = NewInProgressRefs}};
		false ->
			NextHandler = ?nextNodeID,
			NewFirstKey = min(?minKey, ComputationSoFar),
			gen_server:cast({global, ?HANDLERPROCNAME(NextHandler)}, {Pid, Ref, first_key, NewFirstKey}),

			{noreply, S}
	end;

%Getting a message from one of our SPs looking for the last key
handle_cast({Pid, Ref, last_key}, S) ->
	NextHandler = ?nextNodeID,
	MyLastKey = ?maxKey, 
	OldInProgressRefs = ?myInProgressRefs,

	NewInProgressRefs = [Ref | OldInProgressRefs],

	gen_server:cast({global, ?HANDLERPROCNAME(NextHandler)}, {Pid, Ref, last_key, MyLastKey}),

	{noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%Getting a message from another handler about last keys
handle_cast({Pid, Ref, last_key, ComputationSoFar}, S = #state{myInProgressRefs = InProgressRefs}) ->
	InProgressRefs = ?myInProgressRefs,

	case list:member(Ref, InProgressRefs) of
		true -> 
			Pid ! {Ref, result, ComputationSoFar},

			NewInProgressRefs = lists:delete(Ref, InProgressRefs),

			{noreply, S#state{myInProgressRefs = NewInProgressRefs}};
		false ->
			NextHandler = ?nextNodeID,
			NewLastKey = max(?maxKey, ComputationSoFar),
			gen_server:cast({global, ?HANDLERPROCNAME(NextHandler)}, {Pid, Ref, last_key, NewLastKey}),

			{noreply, S}
	end;

%Getting a message from one of our SPs looking for the last key
handle_cast({Pid, Ref, num_keys}, S) ->
	NextHandler = ?nextNodeID,
	MyNumKeys = ?myBackupSize, 
	OldInProgressRefs = ?myInProgressRefs,

	NewInProgressRefs = [Ref | OldInProgressRefs],

	gen_server:cast({global, ?HANDLERPROCNAME(NextHandler)}, {Pid, Ref, num_keys, MyNumKeys}),

	{noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%Getting a message from another handler about last keys
handle_cast({Pid, Ref, num_keys, ComputationSoFar}, S = #state{myInProgressRefs = InProgressRefs}) ->
	InProgressRefs = ?myInProgressRefs,

	case list:member(Ref, InProgressRefs) of
		true -> 
			Pid ! {Ref, result, ComputationSoFar},

			NewInProgressRefs = lists:delete(Ref, InProgressRefs),

			{noreply, S#state{myInProgressRefs = NewInProgressRefs}};
		false ->
			NextHandler = ?nextNodeID,
			NewNumKeys = ?myInProgressRefs + ComputationSoFar,
			gen_server:cast({global, ?HANDLERPROCNAME(NextHandler)}, {Pid, Ref, num_keys, NewNumKeys}),

			{noreply, S}
	end.

handle_info({_Pid, _Ref, chill}, S) ->
	{noreply, S}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    lal.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 								HELPER FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


distTo(ID, S) ->
	utils:modDist(?m, ?myID, ID).
	
isMyProcess(ID, S) ->
  distTo(ID, S) < distTo(?nextNodeID, S).

%Two to the M
twoM(M) -> 1 bsl M.

%% init
startAllSPs(_Start, _Stop) ->
	true.
	%Start the SP
	%gen_server:start({global, ?PROCNAME}, philosopher, {NodesToConnectTo}, []),

%% backup_store
updateMinKey(Key, S) ->
	case Key < ?minKey of
		true ->
			Key;
		false ->
			?minKey
	end.

updateMaxKey(Key, S) ->
	case Key > ?maxKey of
		true ->
			Key;
		false ->
			?maxKey
	end.

