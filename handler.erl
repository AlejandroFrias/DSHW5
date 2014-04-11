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
	       myInProgressRefs}).
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
    io:format("TEST"),
	utils:hlog("Handler starting with node ID ~w and no next ID", [MyID], MyID),
	io:format("TEST2"),
	utils:hlog("My node name is ~w", [node()], MyID),
	% Start all the processes
	startAllSPs(MyID, utils:pow2(M) - 1, M, MyID, []),
	utils:hlog("Handler started successfully.", MyID),
	{ok, #state{m = M, myID = MyID, nextNodeID = 0, 
		myBackup = [], minKey = [], maxKey = [], myBackupSize = 0,
		myInProgressRefs = []}}; %Fix these keys

%Start up everything as a non-first node in a system
init({M, MyID, NextNodeID}) -> 
	utils:hlog("Handler starting with node ID ~w and next ID ~w", [MyID, NextNodeID], MyID),
	utils:hlog("My node name is ~w", [node()], MyID),
	%Names = global:registered_names(),
  	%io:format("Registered names (new handler): ~w~n", [Names]),

	startAllSPs(MyID, NextNodeID - 1, M, MyID, []),


  	% BackupData = gen_server:call({global, ?HANDLERPROCNAME(NextNodeID)}, {joining_behind, MyID}),

  	% gen_server:call({global, })



	{ok, #state{m = M, myID = MyID, nextNodeID = NextNodeID, 
		myBackup = [], minKey = [], maxKey = [], myBackupSize = 0,
		myInProgressRefs = []}}. %Fix these keys

% A new node is joining in front of this node. Need to terminate processes
% for the transfer.
handle_call({joining_front, NodeID}, _From, S) ->
	ProcsToTerminate = [{global, utils:sname(ID)} || ID <- utils:modSeq(NodeID, ?nextNodeID - 1, ?m)],
	terminateProcs(ProcsToTerminate),
	{reply, done, S};


% A new node is joining behind this node. Need to give it all the data for start
% up and back up and then delete the backup data we no longer need.
handle_call({joining_behind, NodeID}, _From, S) ->
  NewBackup = [D || D = {_Key, _Value, ID} <- ?myBackup, utils:modDist(ID, ?myID, ?m) =< utils:modDist(NodeID, ?myID, ?m)],
  {reply, ?myBackup, S#state{myBackup = NewBackup}};


handle_call(Msg, _From, S) ->
  utils:slog("UH OH! We don't support msgs like ~p.", [Msg], ?myID),
	{noreply, S}.

% Receives a backup_store message. Should forward to next node if its from it's 
% own storage process, or, if not, store in back up and tell outside world a 
% confirmation of store
handle_cast(Msg = {Pid, Ref, backup_store, Key, Value, ProcessID}, S) ->
	case isMyProcess(ProcessID, S) of
		true ->
			utils:hlog("Received a backup_store request from my process: ~p", [ProcessID], ?myID),
			utils:hlog("Forwarding the message to the next node (~p) to backup.", [?nextNodeID], ?myID),
			gen_server:cast({global, utils:hname(?nextNodeID)}, Msg),
			{noreply, S};
		false ->
			utils:hlog("Received a backup_store request to be stored.", ?myID),
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
			utils:hlog("Stored ~p, old value was ~p.", [Value, OldValue], ?myID),
			utils:hlog("Sending stored confirmation to ~p", [Pid], ?myID),
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

	utils:hlog("Received message from my SP looking for first_key.", ?myID),

	NewInProgressRefs = [Ref | OldInProgressRefs],

	gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, first_key, MyFirstKey}),

	{noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%Getting a message from another handler about first keys
handle_cast({Pid, Ref, first_key, ComputationSoFar}, S = #state{myInProgressRefs = InProgressRefs}) ->
	InProgressRefs = ?myInProgressRefs,

	case lists:member(Ref, InProgressRefs) of
		true -> 
			utils:hlog("Finished first_key computation. Result was: ~p", [ComputationSoFar], ?myID),
			Pid ! {Ref, result, ComputationSoFar},

			NewInProgressRefs = lists:delete(Ref, InProgressRefs),

			{noreply, S#state{myInProgressRefs = NewInProgressRefs}};
		false ->
			utils:hlog("Got first_key computation from another handler. So far, the computation is : ~p", [ComputationSoFar], ?myID),

			NextHandler = ?nextNodeID,
			NewFirstKey = min(?minKey, ComputationSoFar),
			gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, first_key, NewFirstKey}),

			{noreply, S}
	end;

%Getting a message from one of our SPs looking for the last key
handle_cast({Pid, Ref, last_key}, S) ->
	NextHandler = ?nextNodeID,
	MyLastKey = ?maxKey, 
	OldInProgressRefs = ?myInProgressRefs,

	utils:hlog("Received message from my SP looking for last_key.", ?myID),

	NewInProgressRefs = [Ref | OldInProgressRefs],

	gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, last_key, MyLastKey}),

	{noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%Getting a message from another handler about last keys
handle_cast({Pid, Ref, last_key, ComputationSoFar}, S = #state{myInProgressRefs = InProgressRefs}) ->
	InProgressRefs = ?myInProgressRefs,

	case lists:member(Ref, InProgressRefs) of
		true -> 
			utils:hlog("Finished last_key computation. Result was: ~p", [ComputationSoFar], ?myID),

			Pid ! {Ref, result, ComputationSoFar},

			NewInProgressRefs = lists:delete(Ref, InProgressRefs),

			{noreply, S#state{myInProgressRefs = NewInProgressRefs}};
		false ->
			utils:hlog("Got last_key computation from another handler. So far, the computation is : ~p", [ComputationSoFar], ?myID),

			NextHandler = ?nextNodeID,
			NewLastKey = max(?maxKey, ComputationSoFar),
			gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, last_key, NewLastKey}),

			{noreply, S}
	end;

%Getting a message from one of our SPs looking for the last key
handle_cast({Pid, Ref, num_keys}, S) ->
	NextHandler = ?nextNodeID,
	MyNumKeys = ?myBackupSize, 
	OldInProgressRefs = ?myInProgressRefs,

	utils:hlog("Received message from my SP looking for num_keys.", ?myID),

	NewInProgressRefs = [Ref | OldInProgressRefs],

	gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, num_keys, MyNumKeys}),

	{noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%Getting a message from another handler about last keys
handle_cast({Pid, Ref, num_keys, ComputationSoFar}, S = #state{myInProgressRefs = InProgressRefs}) ->
	InProgressRefs = ?myInProgressRefs,

	case lists:member(Ref, InProgressRefs) of
		true -> 
			utils:hlog("Finished num_keys computation. Result was: ~p", [ComputationSoFar], ?myID),

			Pid ! {Ref, result, ComputationSoFar},

			NewInProgressRefs = lists:delete(Ref, InProgressRefs),

			{noreply, S#state{myInProgressRefs = NewInProgressRefs}};
		false ->
			utils:hlog("Got num_keys computation from another handler. So far, the computation is : ~p", [ComputationSoFar], ?myID),

			NextHandler = ?nextNodeID,
			NewNumKeys = ?myInProgressRefs + ComputationSoFar,
			gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, num_keys, NewNumKeys}),

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
  (distTo(ID, S) < distTo(?nextNodeID, S)) and ((?nextNodeID) =/= (?myID)).

%% init
startAllSPs(Stop, Stop, M, HandlerID, Data) -> 
	SPData = dataToDict(Data, Stop),
	gen_server:start({global, utils:sname(Stop)}, storage, {M, Stop, HandlerID, SPData}, []),
	done;
startAllSPs(Start, Stop, M, HandlerID, Data) ->
	SPData = dataToDict(Data, Stop),

	%Start the SP
	gen_server:start({global, utils:sname(Stop)}, storage, {M, Stop, HandlerID, SPData}, []),
	startAllSPs(Start, ((Stop - 1 + utils:pow2(M)) rem utils:pow2(M)), M, HandlerID, Data).


dataToDict(Data, ID) ->
	IDData = [{Key, Value} || {Key, Value, ThisID} <- Data, ThisID == ID], %lists:keytake(ID, ?ID, Data),
	%StrippedData = [stripID(D) || D <- IDData], %lists:map(stripID, IDData),
	dict:from_list(IDData).

stripID({Key, Value, _ID}) -> {Key, Value}.



terminateProcs([]) ->
	done;
terminateProcs([Proc | Procs]) ->
	gen_server:call(Proc, terminate),
	terminateProcs(Procs).

%% backup_store
updateMinKey(Key, S) ->
	case (Key < ?minKey) or (?myBackupSize == 0) of
		true ->
			Key;
		false ->
			?minKey
	end.

updateMaxKey(Key, S) ->
	case (Key > ?maxKey) or (?myBackupSize == 0) of
		true ->
			Key;
		false ->
			?maxKey
	end.

