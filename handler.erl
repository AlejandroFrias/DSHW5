%%% -------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% A Storage Process implementation.
%%%--------------------------------------------------------------------


-module(handler).
-behavior(gen_server).

%% External exports
-export([init/1]).

%% gen_server callbacks
-export([init/1, 
	  handle_call/3, 
	  handle_cast/2, 
	  handle_info/2, 
	  code_change/3, 
	  terminate/2]).

-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).

-record(state, {m, myID, nextNodeID, myBackup, minKey, maxKey, myBackupSize,
	       myInProgressRefs, myAllDataAssembling, myProcsWaitingFor}).
%% myInProgressRefs is a list of refs for messages for *key computations I started
%  myAllDataAssembling - when we pull all data from nodes, we need a place to keep it while we get it all.
%  myProcsWaitingFor - the number of processes that still haven't sent us their data. 
%    See all data send and all data request messages

%Start up everything as the first node in a system
init({M, Name}) ->
	MyID = %my ID
	startAllSPs(0, math:pow(2, M) - 1),
	{ok, #state{m = M, myID = MyID, nextNodeID = NextNodeID, 
		myBackup = dict:new(), minKey = [], maxKey = [], myBackupSize = 0,
		myInProgressRefs = [], myAllDataAssembling = dict:new(), myProcsWaitingFor = 0} %Fix these keys

%Start up everything as a non-first node in a system
init({M, Name, Other}) -> true.


startAllSPs(Start, Stop) ->
	%Start the SP
	gen_server:start({global, ?PROCNAME}, philosopher, {NodesToConnectTo}, []),
	
