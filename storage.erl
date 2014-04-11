%%% -------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% A Storage Process implementation.
%%%--------------------------------------------------------------------


-module(storage).
-behavior(gen_server).

%% External exports
%-export( [init/1, init/2] ).

%% gen_server callbacks
-export([init/1, 
	  handle_call/3, 
	  handle_cast/2, 
	  handle_info/2, 
	  code_change/3, 
	  terminate/2]).

-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).


-define(m, S#state.m).
-define(myID, S#state.myID).
-define(myDict, S#state.myDict).
-define(myHandlerID, S#state.myHandlerID).

-record(state, {m, myID, myDict, myHandlerID}).


%%%============================================================================
%%% Utility Functions
%%%============================================================================

%Two to the M
twoM(M) -> 1 bsl M.

hash( Key, M ) ->
    MaxProcID = twoM(M),
    % this erlang built-in hash function works on any erlang term (though in
    % this assignment we're restricted to strings).  More irritatingly, though,
    % the range (MaxProcID) is limited to 2^32.
    erlang:phash2( Key, MaxProcID ).

% Round down the log2 of the distance to the process, to know how many powers of 
% two, then use that chord.
findClosestTo(Dest, S) ->
  Dist = distTo(Dest, S),
  Chord = trunc(utils:log2(Dist)),
  (?myID + utils:pow2(Chord)) rem utils:pow2(?m).

distTo(ID, S) ->
  utils:modDist(?m, ?myID, ID).



%%%============================================================================
%%% GenServer Calls/Casts
%%%============================================================================


%%%============================================================================
%%% GenServer Callbacks (For the rest of the code)
%%%============================================================================

init( {M, MyID, MyHandlerID} ) ->
    utils:slog( "Starting on node ~w.", [MyHandlerID], MyID),
    MyDict = dict:new(),
    process_flag(trap_exit, true),
    { ok, #state{m = M, myID = MyID, myDict = MyDict, myHandlerID = MyHandlerID} }.


handle_call(getState, _, S) ->
	{noreply, S}.


%%%%%%%%%% END ASYNCRHONOUS MESSAGES FROM OTHER STORAGE PROCESSES %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% MESSAGES FROM THE CONTROLLER %%%%%%%%%%%%%%%%%%%%%%%%%%%

handle_cast({Pid, Ref, store, Key, Value}, S) ->
	Dest = hash(Key, ?m),
	case Dest == ?myID of
		true -> 
			utils:slog("Received store message for me, storing it and notifying handler", ?myID),
			OldDict = ?myDict,
			NewDict = dict:store(Key, Value, OldDict),

			%Notify our handler about it
			gen_server:cast({global, ?HANDLERPROCNAME(?myHandlerID)}, {Pid, Ref, backup_store, Key, Value, ?myID}),

			{noreply, S#state{myDict = NewDict}};
		false ->
			Closest = findClosestTo(Dest, S),
			utils:slog("Received store message for SP ~w, forwarding it to ~w", [Dest, Closest], ?myID),
			gen_server:cast({global, ?STORAGEPROCNAME(Closest)}, {Pid, Ref, store, Key, Value}),
			{noreply, S}
	end;

handle_cast({Pid, Ref, retrieve, Key}, S) ->
	case hash(Key, ?m) == ?myID of
		true -> storeit;
		false -> forwardmessage
	end,
    %gen_server:cast(Pid, {Ref, retrieved, dict:fetch(Key, MyDict)}),
    {noreply, S};

handle_cast({Pid, Ref, retrieve, Key, Value}, S) -> changeme
    % pass the store request along
    ;

handle_cast({}, _S) -> changeme.




%Receive store messages from outside world
handle_info({Pid, Ref, store, Key, Value}, S) ->
	gen_server:cast({global, ?STORAGEPROCNAME(?myID)}, {Pid, Ref, store, Key, Value}),
	{noreply, S};

handle_info({Pid, Ref, first_key}, S) ->
	utils:slog("Received first_key request from outside world, forwarding to handler.", ?myID),
	gen_server:cast({global, ?HANDLERPROCNAME(?myHandlerID)}, {Pid, Ref, first_key}),
	{noreply, S};

handle_info({Pid, Ref, last_key}, S) ->
	utils:slog("Received last_key request from outside world, forwarding to handler.", ?myID),
	gen_server:cast({global, ?HANDLERPROCNAME(?myHandlerID)}, {Pid, Ref, last_key}),
	{noreply, S};

handle_info({Pid, Ref, num_keys}, S) ->
	utils:slog("Received num_keys request from outside world, forwarding to handler.", ?myID),
	gen_server:cast({global, ?HANDLERPROCNAME(?myHandlerID)}, {Pid, Ref, num_keys}),
	{noreply, S};

handle_info(_, S) ->
	utils:slog("Received unexpected message! OHHHH NOOOOOO", ?myID),
	{noreply, S}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    lal.


    
