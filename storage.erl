%%% -------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% A Storage Process implementation.
%%%--------------------------------------------------------------------


-module(storage).
-behavior(gen_server).

%% External exports
-export( [init/1, init/2] ).

%% gen_server callbacks
-export([init/1, 
	  handle_call/3, 
	  handle_cast/2, 
	  handle_info/2, 
	  code_change/3, 
	  terminate/2]).

-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).

-record(state, {m, myID, myDict, myHandlerID}).


%%%============================================================================
%%% Utility Functions
%%%============================================================================

hash( Key, M ) ->
    MaxProcID = 1 bsl M,
    % this erlang built-in hash function works on any erlang term (though in
    % this assignment we're restricted to strings).  More irritatingly, though,
    % the range (MaxProcID) is limited to 2^32.
    erlang:phash2( Key, MaxProcID ).

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


%%%%%%%%%% END ASYNCRHONOUS MESSAGES FROM OTHER STORAGE PROCESSES %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% MESSAGES FROM THE CONTROLLER %%%%%%%%%%%%%%%%%%%%%%%%%%%

handle_cast({Pid, Ref, store, Key, Value}, S = #state{myID = MyID}) when
      hash(Key) == MyID ->
    % deal with storing your own data
    ;

handle_cast({Pid, Ref, store, Key, Value}, S = #state{myID = MyID}) ->
    % pass the store request along
    ;

handle_cast({Pid, Ref, retrieve, Key}, S = #state{myID = MyID, myDict = MyDict}) 
  when hash(Key) == MyID ->
    gen_server:cast(Pid, {Ref, retrieved, dict:fetch(Key, MyDict)}),
    {noreply, S};

handle_cast({Pid, Ref, retrieve, Key, Value}, S = #state{myID = MyID}) ->
    % pass the store request along
    ;

handle_cast() ->






    
