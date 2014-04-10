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

-define(?TwoM, (1 bsl M))

-record(state, {m, myID, myDict, myHandlerID}).


%%%============================================================================
%%% Utility Functions
%%%============================================================================

%Two to the M
twoM(M) -> 1 bsl M

hash( Key, M ) ->
    MaxProcID = 1 bsl M,
    % this erlang built-in hash function works on any erlang term (though in
    % this assignment we're restricted to strings).  More irritatingly, though,
    % the range (MaxProcID) is limited to 2^32.
    erlang:phash2( Key, MaxProcID ).

%TO DO: MAKE THIS ACTUALLY FIND THE CLOSEST
findClosestTo(_Dest, Me, M) ->
	(Me + 1) rem twoM(M).

%%%============================================================================
%%% GenServer Calls/Casts
%%%============================================================================


%%%============================================================================
%%% GenServer Callbacks (For the rest of the code)
%%%============================================================================

init( {M, MyID, MyHandlerID} ) ->
    utils:log( "Starting storage process ~p on node ~p." ),
    MyDict = dict:new(),
    process_flag(trap_exit, true),
    { ok, #state{m = M, myID = MyID, myDict = MyDict, myHandlerID = MyHandlerID} }.


handle_call(getState, _, S) ->
	{noreply, S}.


%%%%%%%%%% END ASYNCRHONOUS MESSAGES FROM OTHER STORAGE PROCESSES %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% MESSAGES FROM THE CONTROLLER %%%%%%%%%%%%%%%%%%%%%%%%%%%

handle_cast({Pid, Ref, store, Key, Value}, S = #state{myID = MyID}) ->
	Dest = hash(Key, ?m),
	case Dest == MyID of
		true -> 
			OldDict = ?myDict,
			NewDict = dict:store(Key, Value, OldDict),
			{noreply, S#state{myDict = NewDict}};
		false ->
			Closest = findClosestTo(Dest, MyID, ?m),
			gen_server:cast({global, ?STORAGEPROCNAME(Closest)}, {Pid, Ref, store, Key, Value}),
			{noreply, S}
	end;

handle_cast({Pid, Ref, retrieve, Key}, S = #state{myID = MyID, myDict = MyDict}) ->
	case hash(Key, ?m) == MyID of
		true -> storeit;
		false -> forwardmessage
	end,
    %gen_server:cast(Pid, {Ref, retrieved, dict:fetch(Key, MyDict)}),
    {noreply, S};

handle_cast({Pid, Ref, retrieve, Key, Value}, S = #state{myID = MyID}) -> changeme
    % pass the store request along
    ;

handle_cast({}, _S) -> changeme.




%Receive store messages from outside world
handle_info({Pid, Ref, store, Key, Value}, S) ->
	gen_server:cast({global, ?STORAGEPROCNAME(?myID)}, {Pid, Ref, store, Key, Value}),
	{noreply, S};

handle_info({Pid, Ref, first_key}) ->
	

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    lal.


    
