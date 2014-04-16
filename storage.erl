%%% -------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% A Storage Process implementation.
%%%
%%% A storage process receives requests from the outside world.
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

-define(m, S#state.m).
-define(myID, S#state.myID).
-define(myDict, S#state.myDict).
-define(myHandlerPid, S#state.myHandlerPid).

-record(state, {m, myID, myDict, myHandlerPid}).


%%%============================================================================
%%% Utility Functions
%%%============================================================================

%Two to the M
twoM(M) -> 1 bsl M.

%Get the hash of a value
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

%Distance from me (ID gathered from S) to the ID specified around the ring
distTo(ID, S) ->
  utils:modDistZero(?myID, ID, ?m).



%%%============================================================================
%%% GenServer Calls/Casts
%%%============================================================================


%%%============================================================================
%%% GenServer Callbacks (For the rest of the code)
%%%============================================================================

%Initialize a storage process with specified data
init( {M, MyID, MyHandlerPid, MyDict} ) ->
    utils:slog( "Starting with handler Pid ~w.", [MyHandlerPid], MyID),
    process_flag(trap_exit, true),
    { ok, #state{m = M, myID = MyID, myDict = MyDict, myHandlerPid = MyHandlerPid} }.

%%Handle call messages, Send all our data to our handler
handle_call({all_data}, _From, S) ->
  utils:slog("Received all_data message from my handler!", ?myID),
  ListDict = dict:to_list(?myDict),
  ListWithID = [{Key, Value, ?myID} || {Key, Value} <- ListDict],
  utils:slog("  Replying with my data.", ?myID),
  {reply, ListWithID, S};

%Terminate message from our handler.
handle_call(terminate, _From, S) ->
  utils:slog("Goodbye.", ?myID),
  {stop, normal, terminated, S};

%Other messages!
handle_call(Msg, _From, S) ->
  utils:slog("UH OH! We don't support msgs like ~p.", [Msg], ?myID),
	{noreply, S}.


%%%%%%%%%% END SYNCRHONOUS MESSAGES FROM OTHER STORAGE PROCESSES %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% MESSAGES FROM THE CONTROLLER %%%%%%%%%%%%%%%%%%%%%%%%%%%

%Store requests from outside world
handle_cast(Msg = {Pid, Ref, store, Key, Value}, S) ->
	Dest = hash(Key, ?m),
	case Dest == ?myID of
    %If we have to store it
		true -> 
			utils:slog("Stored {~p, ~p} and notifying handler.", [Key, Value], ?myID),
			OldDict = ?myDict,
			NewDict = dict:store(Key, Value, OldDict),

			%Notify our handler about it
			gen_server:cast(?myHandlerPid, {Pid, Ref, backup_store, Key, Value, ?myID}),

			{noreply, S#state{myDict = NewDict}};
    %If it's not for us, forward it to the closest
		false ->
			Closest = findClosestTo(Dest, S),
			utils:slog("Received store message for SP ~w, forwarding it to ~w", [Dest, Closest], ?myID),
			gen_server:cast({global, utils:sname(Closest)}, Msg),
			{noreply, S}
	end;

%Retrieve messages from OW
handle_cast(Msg = {Pid, Ref, retrieve, Key}, S) ->
	case (Dest = hash(Key, ?m)) == ?myID of
		true -> 
      %If it's something we're storing, look it up and send the value
      case dict:is_key(Key, ?myDict) of
        true ->
          Value = dict:fetch(Key, ?myDict);
        false ->
          Value = no_value
      end,
      utils:slog("Retrieved Value ~p for Key ~p.", [Value, Key], ?myID),
      Pid ! {Ref, retrieved, Value};
    false ->
      %Otherwise forward it to the closest
      Closest = findClosestTo(Dest, S),
      utils:slog("Received retrieve message for SP ~w, forwarding it to ~w", [Dest, Closest], ?myID),
      gen_server:cast({global, utils:sname(Closest)}, Msg)
	end,
  {noreply, S};

handle_cast(Msg, S) ->
  utils:slog("Ummm, ~p is not a supported message. What happened?", [Msg], ?myID).




% Receive messages from outside world and forward them as internal messages
handle_info(Msg = {_Pid, _Ref, store, _Key, _Value}, S) ->
	gen_server:cast({global, utils:sname(?myID)}, Msg),
	{noreply, S};

handle_info(Msg = {_Pid, _Ref, retrieve, _Key}, S) ->
  gen_server:cast({global, utils:sname(?myID)}, Msg),
  {noreply, S};

handle_info(Msg = {_Pid, _Ref, first_key}, S) ->
	utils:slog("Received first_key request from outside world, forwarding to handler.", ?myID),
	gen_server:cast(?myHandlerPid, Msg),
	{noreply, S};

handle_info(Msg = {_Pid, _Ref, last_key}, S) ->
	utils:slog("Received last_key request from outside world, forwarding to handler.", ?myID),
	gen_server:cast(?myHandlerPid, Msg),
	{noreply, S};

handle_info(Msg = {_Pid, _Ref, num_keys}, S) ->
	utils:slog("Received num_keys request from outside world, forwarding to handler.", ?myID),
	gen_server:cast(?myHandlerPid, Msg),
	{noreply, S};

handle_info({Pid, Ref, node_list}, S) ->
  utils:slog("Received node_list request from outside world.", ?myID),
  Names = global:registered_names(),
  ActiveNodeIDs = lists:sort([utils:getID(N) || N <- Names, utils:isHandler(N)]),
  utils:slog("Sending Active Node IDs: ~p", [ActiveNodeIDs], ?myID),
  Pid ! {Ref, result, ActiveNodeIDs},
  {noreply, S};

handle_info(Msg = {_Pid, _Ref, leave}, S) ->
  utils:slog("Received leave request from outside world, forwarding to handler.", ?myID),
  gen_server:cast(?myHandlerPid, Msg),
  {noreply, S};


handle_info(_, S) ->
	utils:slog("Received unexpected message! OHHHH NOOOOOO", ?myID),
	{noreply, S}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    lal.


    
