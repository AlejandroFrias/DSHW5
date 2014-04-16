%%% -------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% A Non-Storage Process (Handler) implementation.
%%% 
%%% This process handles management of a node, like fault tolerance, backup, some
%%% communication with the outside world, re-balancing on join and leave, etc. 
%%%--------------------------------------------------------------------


-module(handler).
-behavior(gen_server).

%% External exports
-export([start/1]).

%% gen_server callbacks
-export([init/1, 
	 handle_call/3, 
	 handle_cast/2, 
	 handle_info/2, 
	 code_change/3, 
	 terminate/2]).

%% Indices where Key, Value, and ID are stored in the backup.
%% Kept as constants for flexibility (and to reduce irritation with
%% 1-indexing).
-define(KEY, 1).
-define(VAL, 2).
-define(ID, 3).

-define(m, S#state.m).
-define(myID, S#state.myID).
-define(nextNodeID, S#state.nextNodeID).
-define(prevNodeID, S#state.prevNodeID).
-define(myBackup, S#state.myBackup).
-define(minKey, S#state.minKey).
-define(maxKey, S#state.maxKey).
-define(myBackupSize, S#state.myBackupSize).
-define(myInProgressRefs, S#state.myInProgressRefs).
-define(myAllDataAssembling, S#state.myAllDataAssembling).
-define(myProcsWaitingFor, S#state.myProcsWaitingFor).
-define(myMonitoredNode, S#state.myMonitoredNode).

-record(state, {m, 
		myID,
		nextNodeID,
		prevNodeID,
		myBackup,
		minKey,
		maxKey,
		myBackupSize ,
		myInProgressRefs,
		myMonitoredNode
	       }).



start( {Minty} ) ->
    gen_server:start({global, utils:hname(0)}, handler, {Minty, 0}, []),
    global:sync();

start( {Minty, PrevHandlerID, NewHandlerID, NextHandlerID} ) ->
    gen_server:start({global, utils:hname(NewHandlerID)}, handler, 
		     {Minty, PrevHandlerID, NewHandlerID, NextHandlerID}, []),
    global:sync().



%% Start up everything as the first node in a system
%% Start ID will always be 0
init({M, MyID}) ->
    %% net_kernel:start([node(), shortnames]),
    %% ConnectResult = net_kernel:connect_node(OriginProcess),
    %% utils:log("Connecting to ~w, result is: ~w", [OriginProcess, ConnectResult]),
    global:sync(),
    utils:hlog("Handler starting with node ID ~w and no next ID", [MyID], MyID),

    %% Start all the processes
    startAllSPs(MyID, utils:pow2(M) - 1, M, []),
    utils:hlog("Handler started successfully.", MyID),
    utils:hlog("My node name is ~w", [node()], MyID),
    {ok, #state{m = M, myID = MyID, nextNodeID = 0, prevNodeID = 0,
		myBackup = [], minKey = no_value, maxKey = no_value, myBackupSize = 0,
		myInProgressRefs = [], %%myMonitorRef = make_ref()
		myMonitoredNode = erlang:node()
	       }}; %Fix these keys

%% Start up everything as a non-first node in a system
init({M, PrevNodeID, MyID, NextNodeID}) -> 
    utils:hlog("Handler starting with node ID ~w and next ID ~w", [MyID, NextNodeID], MyID),
    
    %% Tell the previous guy stop his nodes.  Get his Pid back.
    MonitorPid = gen_server:call({global, utils:hname(PrevNodeID)}, {joining_front, MyID}),
    MonitorNode = erlang:node( MonitorPid ),
    %% Start monitoring previous node
    %%NewMonitorRef = erlang:monitor(process, MonitorPid),
    %%    NewMonitorRef = erlang:monitor(process, {utils:hname(PrevNodeID), MonitorPid}),

    %% Different method, suggested by Jesse W-R, because globally-registered processes
    %% cannot be monitored directly
    erlang:monitor_node( MonitorNode, true ),

    %% Get the data from our next node and then spin up instances
    {NextBackupData, MinKey, MaxKey} = gen_server:call({global, utils:hname(NextNodeID)}, {joining_behind, MyID}),
    BackupData = startAllSPs(MyID, utils:modDec(NextNodeID, M), M, NextBackupData),

    NumKeys = length(BackupData),

    utils:hlog("Ready to go. My node name is ~w", [node()], MyID),
    {ok, #state{m = M, myID = MyID, nextNodeID = NextNodeID, prevNodeID = PrevNodeID,
		myBackup = BackupData, minKey = MinKey, maxKey = MaxKey, myBackupSize = NumKeys,
		myInProgressRefs = [], %%myMonitorRef = NewMonitorRef
		myMonitoredNode = MonitorNode
	       }}.

%% A new node is joining in front of this node. Need to terminate processes
%% for the transfer.
handle_call({joining_front, NodeID}, _From, S) ->
    utils:hlog("New node joining in front of me at ~p", [NodeID], ?myID),
    ProcsToTerminate = [{global, utils:sname(ID)} || ID <- utils:modSeq(NodeID, utils:modDec(?nextNodeID, ?m), ?m)],
    terminateProcs(ProcsToTerminate),
    {reply, self(), S#state{nextNodeID = NodeID}};


%% A new node is joining behind this node. Need to give it all the data for start
%% up and back up and then delete the backup data we no longer need.
handle_call({joining_behind, NodeID}, _From = {Pid, _Tag}, S) ->
    utils:hlog("New node joining behind me at ~p", [NodeID], ?myID),

    erlang:monitor_node( ?myMonitoredNode, false ),
    NewMonitoredNode = erlang:node( Pid ),
    erlang:monitor_node( NewMonitoredNode, true ),

    NewBackup = [D || D = {_Key, _Value, ID} <- ?myBackup, utils:modDist(ID, ?myID, ?m) =< utils:modDist(NodeID, ?myID, ?m)],
    {NewMinKey, NewMaxKey} = calculateMinMaxKey(NewBackup),
    utils:hlog("Replying with my backup data.", ?myID),
    {reply, {?myBackup, ?minKey, ?maxKey}, S#state{prevNodeID = NodeID,
						   myBackup = NewBackup,
                           myBackupSize = length(NewBackup),
                           minKey = NewMinKey,
                           maxKey = NewMaxKey,
						   myMonitoredNode = NewMonitoredNode}};


handle_call({_Pid, _Ref, leave}, _From, S) ->
    ProcsToTerminate = [{global, utils:sname(ID)} || ID <- utils:modSeq(?myID, utils:modDec(?nextNodeID, ?m), ?m)],
    terminateProcs(ProcsToTerminate),
    utils:hlog("Asked to leave by outside world.", ?myID),
    {stop, normal, "Asked to leave by outside world", S};


handle_call(Msg, _From, S) ->
    utils:hlog("UH OH! We don't support handle call msgs like ~p.", [Msg], ?myID),
    {noreply, S}.

%% Receives a backup_store message. Should forward to next node if its from it's 
%% own storage process, or, if not, store in back up and tell outside world a 
%% confirmation of store
handle_cast(Msg = {Pid, Ref, backup_store, Key, Value, ProcessID}, S) ->
    case isMyProcess(ProcessID, S) of
	true ->
	    utils:hlog("Received a backup_store request from my process: ~p", [ProcessID], ?myID),
	    utils:hlog("Forwarding the message to the next node (~p) to backup.", [?nextNodeID], ?myID),
	    gen_server:cast({global, utils:hname(?nextNodeID)}, Msg),
	    {noreply, S};
	false ->
	    utils:hlog("Received a backup_store request for {~p, ~p}.", [Key, Value], ?myID),
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
	    utils:hlog("Backed up {~p, ~p}, old value was ~p.", [Key, Value, OldValue], ?myID),
	    utils:hlog("Sending stored confirmation to ~p", [Pid], ?myID),
	    %% Message the outside world that the value was stored
	    Pid ! {Ref, stored, OldValue},

	    %% Store the value and update min, max, and number of keys
	    NewMinKey = updateMinKey(Key, S),
	    NewMaxKey = updateMaxKey(Key, S),
	    {noreply, S#state{myBackup = NewBackup,
			      myBackupSize = NewBackupSize,
			      minKey = NewMinKey,
			      maxKey = NewMaxKey} }
    end;

%% Getting a message from one of our SPs looking for the first key
handle_cast({Pid, Ref, first_key}, S) ->
    NextHandler = ?nextNodeID,
    MyFirstKey = ?minKey, 
    OldInProgressRefs = ?myInProgressRefs,

    utils:hlog("Received message from my SP looking for first_key.", ?myID),

    NewInProgressRefs = [Ref | OldInProgressRefs],

    gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, first_key, MyFirstKey}),

    {noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%% Getting a message from another handler about first keys
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
	    NewFirstKey = utils:key_min(?minKey, ComputationSoFar),
	    gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, first_key, NewFirstKey}),

	    {noreply, S}
    end;

%% Getting a message from one of our SPs looking for the last key
handle_cast({Pid, Ref, last_key}, S) ->
    NextHandler = ?nextNodeID,
    MyLastKey = ?maxKey, 

    OldInProgressRefs = ?myInProgressRefs,

    utils:hlog("Received message from my SP looking for last_key.", ?myID),

    NewInProgressRefs = [Ref | OldInProgressRefs],

    gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, last_key, MyLastKey}),

    {noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%% Getting a message from another handler about last keys
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
	    NewLastKey = utils:key_max(?maxKey, ComputationSoFar),
	    gen_server:cast({global, utils:hname(NextHandler)}, {Pid, Ref, last_key, NewLastKey}),

	    {noreply, S}
    end;

%% Getting a message from one of our SPs looking for the last key
handle_cast({Pid, Ref, num_keys}, S) ->
    utils:hlog("Received message from my SP looking for num_keys.", ?myID),
    NewInProgressRefs = [Ref | ?myInProgressRefs],
    utils:hlog("Sending num_key request to be computed to ~p. Starting at size: ~p", [?nextNodeID, ?myBackupSize], ?myID),
    gen_server:cast({global, utils:hname(?nextNodeID)}, {Pid, Ref, num_keys, ?myBackupSize}),

    {noreply, S#state{myInProgressRefs = NewInProgressRefs}};

%% Getting a message from another handler about last keys
handle_cast({Pid, Ref, num_keys, ComputationSoFar}, S) ->
    case lists:member(Ref, ?myInProgressRefs) of
    true -> 
        utils:hlog("Finished num_keys computation. Result was: ~p", [ComputationSoFar], ?myID),

        Pid ! {Ref, result, ComputationSoFar},

        NewInProgressRefs = lists:delete(Ref, ?myInProgressRefs),

        {noreply, S#state{myInProgressRefs = NewInProgressRefs}};
    false ->
        utils:hlog("Got num_keys computation from another handler. So far, the computation is : ~p", [ComputationSoFar], ?myID),
        NewNumKeys = ?myBackupSize + ComputationSoFar,
        utils:hlog("Forwarding num_key request after computation to ~p. Current size: ~p", [?nextNodeID, NewNumKeys], ?myID),
	    gen_server:cast({global, utils:hname(?nextNodeID)}, {Pid, Ref, num_keys, NewNumKeys}),

	    {noreply, S}
    end;


handle_cast({_Pid, _Ref, leave}, S) ->
    utils:hlog("Asked to leave by outside world. About to halt.", ?myID),
    % ProcsToTerminate = [{global, utils:sname(ID)} || ID <- utils:modSeq(?myID, ?nextNodeID - 1, ?m)],
    % terminateProcs(ProcsToTerminate),

    % {stop, normal, "Asked to leave by outside world", S};
    erlang:halt();

%% Replace the backup data with the new backup data
handle_cast({Node, backupNode, NewPrevID, NewBackupData}, S) ->
	utils:hlog("Got backup data from previous node, my new previous ID is ~p", [NewPrevID], ?myID),
    {NewMinKey, NewMaxKey} = calculateMinMaxKey(NewBackupData),
    BackupSize = erlang:length(NewBackupData),
    erlang:monitor_node(Node, true),
    {noreply, S#state{prevNodeID = NewPrevID,
		       myBackup = NewBackupData,
		       minKey = NewMinKey,
		       maxKey = NewMaxKey,
		       myBackupSize = BackupSize,
		       myMonitoredNode = Node
		      }};

%% Send out all of my data, formatted as a backup which was requested
handle_cast( {Pid, backupRequest, DiedNodeID}, S )
  when DiedNodeID == ?nextNodeID ->
  	utils:hlog("Received backupRequest for me, assembling backup from my SPs. ", ?myID),
    % get all my storage nodes' data
    AllMyData = gatherAllData( utils:modSeq(?myID, utils:modDec(?nextNodeID), ?m) ),
    utils:hlog("Data assembled, sending to next node ~p.", [?nextNodeID], ?myID),
    gen_server:cast( Pid, {node(), backupNode, ?myID, AllMyData} ),
    {noreply, S};

%% Forward a request for data which was not intended for me
handle_cast( Msg = {_, backupRequest, _}, S ) ->
	utils:hlog("Received backupRequest, forwarding it along", ?myID),
    gen_server:cast( {global, utils:hname(?nextNodeID)}, Msg ),
    {noreply, S};

%% We also take a new node ID, since we need to keep track of prevNodeID properly
handle_cast( {appendBackup, BackupData, NewPrevNodeID}, S ) ->
	utils:hlog("Received appendBackup message from the node behind me.", ?myID),
	NewBackupData = BackupData ++ ?myBackup,
    {NewMinKey, NewMaxKey} = calculateMinMaxKey(NewBackupData),

    utils:hlog("Changing my prevNodeID to ~p", [NewPrevNodeID], ?myID),
	{noreply, S#state{myBackup = NewBackupData,
					  myBackupSize = length(NewBackupData),
					  minKey = NewMinKey,
					  maxKey = NewMaxKey,
					  prevNodeID = NewPrevNodeID
	                   }};

handle_cast(Msg, S) ->
    utils:hlog("UH OH! We don't support handle_cast msgs like ~p.", [Msg], ?myID),
    {noreply, S}.


%% Sent by the erlang system when the previous node dies (since we have a monitor on it)
handle_info( {nodedown, Node}, S ) when Node == ?myMonitoredNode ->
    utils:hlog("Oh no!  The previous node (~p) died.  " ++  
		   "Its ID was ~p.  I'm now going to rebalance the data so " ++
		   "that I am running its storage processes and holding all " ++
		   "of the backups, and then change my ID to the dead node's ID.", 
	       [Node, ?prevNodeID], ?myID),
    global:unregister_name( utils:hname(?myID) ),
    utils:hlog("Changing my ID from ~p to ~p", [?myID, ?prevNodeID], ?myID),
    global:register_name( utils:hname( ?prevNodeID ), self() ),


    %% start the necessary storage processes from backup   
    utils:hlog("Starting processes from ~p to ~p.", [?prevNodeID, utils:modDec(?myID, ?m)], ?prevNodeID), 
    startAllSPs(?prevNodeID, utils:modDec(?myID, ?m), ?m, ?myBackup),

    %% Transfer our backup data to next node
    utils:hlog("Sending appendBackup message to handler~p", [?nextNodeID], ?myID),
    gen_server:cast({global, utils:hname( ?nextNodeID )}, {appendBackup, ?myBackup, ?prevNodeID}),
    
    %% Request new backup data
    utils:hlog("Sending a backupRequest request around the ring, starting with handler~p", [?nextNodeID], ?myID),
    gen_server:cast( {global, utils:hname( ?nextNodeID )},
		     {self(), backupRequest, ?prevNodeID} ),

    
    {noreply, S#state{myID = ?prevNodeID}};

handle_info(Msg, S) ->
    utils:hlog("UH OH! We don't support handle_info msgs like ~p.", [Msg], ?myID),
    {noreply, S}.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%       FUNCTIONS REQUIRED BY GEN_SERVER THAT WE DON'T CARE ABOUT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    lal.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                          HELPER FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


distTo(ID, S) ->
    utils:modDist(?myID, ID, ?m).


isMyProcess(ID, S) ->
    (distTo(ID, S) < distTo(?nextNodeID, S)) and ((?nextNodeID) =/= (?myID)).

%% init
%% We use start as handler ID
startAllSPs(Stop, Stop, M, Data) -> 
    {SPData, Rest} = dataToDict(Data, Stop),
    gen_server:start({global, utils:sname(Stop)}, storage, {M, Stop, self(), SPData}, []),
    Rest;

startAllSPs(Start, Stop, M, Data) ->
    {SPData, Rest} = dataToDict(Data, Stop),

    %%Start the SP
    gen_server:start({global, utils:sname(Stop)}, storage, {M, Stop, self(), SPData}, []),
    startAllSPs(Start, utils:modDec(Stop, M), M, Rest).


dataToDict(Data, ID) ->
    IDData = [{Key, Value} || {Key, Value, ThisID} <- Data, ThisID == ID], %lists:keytake(ID, ?ID, Data),
    Rest = [Datum || Datum = {_Key, _Value, RestID} <- Data, RestID =/= ID],
    %%lists:keytake(ID, ?ID, Data),
    %%StrippedData = [stripID(D) || D <- IDData], %lists:map(stripID, IDData),
    {dict:from_list(IDData), Rest}.



terminateProcs([]) ->
    done;
terminateProcs([Proc | Procs]) ->
    gen_server:call(Proc, terminate),
    terminateProcs(Procs).

%% backup_store
updateMinKey(Key, S) ->
    case ((Key < ?minKey) or (?myBackupSize == 0)) of
    	true ->
    	    Key;
    	false ->
    	    ?minKey
    end.

updateMaxKey(Key, S) ->
    case ((Key > ?maxKey) or (?myBackupSize == 0)) of
	true ->
	    Key;
	false ->
	    ?maxKey
    end.

calculateMinMaxKey([]) -> 
    {no_value, no_value};

calculateMinMaxKey([{FirstKey,_,_}|Rest]) ->
    calculateMinMaxKey(Rest, FirstKey, FirstKey).

calculateMinMaxKey([{NextKey,_,_}|Rest], MaxKey, MinKey) ->
    calculateMinMaxKey(Rest, utils:key_max(MaxKey, NextKey), utils:key_min(MinKey, NextKey));

calculateMinMaxKey([], MaxKey, MinKey) ->
    {MinKey, MaxKey}.


gatherAllData(IDs) -> gatherAllData(IDs, []).

gatherAllData( [], DataSoFar) ->
    % utils:log("DATA SO FAR: ~p", [DataSoFar]),
    DataSoFar;

gatherAllData( [ID | Rest], DataSoFar) ->
    NextData = gen_server:call( {global, utils:sname(ID)},
                                {all_data} ),
    gatherAllData(Rest, DataSoFar ++ NextData).


