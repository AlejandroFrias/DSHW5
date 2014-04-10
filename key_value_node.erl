
-module(key_value_node).

-export([main/1]).



%Macro for ?PROCNAME
-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).


%Check if it's a handler or storage
singleHandlerFilter(Name) ->
	io:format("name is ~w~n", [Name]),
	NameList = atom_to_list(Name),
	SubName = lists:sublist(NameList, 7),
	io:format("subname is ~w~n", [list_to_atom(SubName)]),
	SubName == "handler".

%Filter for handlers only
handlerFilter(Names) ->
	[X || X <- Names, singleHandlerFilter(X)].

%Parses the number out of a handler name
handlerNameToNum(Name) ->
	NameList = atom_to_list(Name),
	Number = lists:sublist(NameList, 8, 42),
	list_to_integer(Number).

%progress!
maxConsecutiveDifference([_], Max, First, Second) -> {Max, First, Second}; 
maxConsecutiveDifference([F | Nums], Max, First, Second) ->
	S = hd(Nums),
	if (S - F) > Max -> maxConsecutiveDifference(Nums, S-F, F, S);
	true -> maxConsecutiveDifference(Nums, Max, First, Second)
end.

%Find the widest gap in node locations, then fill it
%Take in a list of handler names
%Return the midpoint as a name, and the next name since we need that too
findWidestHandlerGap(Names, M) ->
	TwoM = round(math:pow(2, M)),

	io:format("HERE WE GO~n"),
	Nums = [handlerNameToNum(N) || N <- Names],% lists:map(handlerNameToNum, Names),
	io:format("whereHERE WE GO: Nums is ~w~n", [Nums]),
	NumsExtended = Nums ++ [hd(Nums) + TwoM],
	io:format("THAR WE GO: NumSextended is ~w~n", [NumsExtended]),
	{_, First, Second} = maxConsecutiveDifference(NumsExtended, 0, 0, 0),
	%We mod by the range to ensure that we get values within the range, so not like past 1024. Good comments guys
	{(First + ((Second - First) div 2)) rem TwoM, Second rem TwoM}.



%Case where we are connecting to other people
mainHelp(M, Name, Other) ->
	Minty = list_to_integer(M),
	%try 
    % Erlang networking boilerplate 
    utils:log("Starting node with name ~w", [Name]),

    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

    ConnectResult = net_kernel:connect_node(list_to_atom(Other)),

    utils:log("Connecting to ~w, result is: ~w", [Other, ConnectResult]),

    %Sleep to let the global names sync
    timer:sleep(1000),
    
    %Compute right place to start
    Names = global:registered_names(),
    utils:log("Registered names: ~w~n", [Names]),
    HandlerNames = handlerFilter(Names),
    utils:log("Finding where we should go among handlers ~w", [HandlerNames]),
    {NewHandlerID, NextHandlerID} = findWidestHandlerGap(HandlerNames, Minty),

	%Start the SH
	utils:log("Staring storage handler with ID ~w~n", [NewHandlerID]),
	%Maybe should not be global?
	%SHOULD HAVE THE RIGHT PROC INDEX
	%Note: This is starting a dummy process so it can figure out where it should be.
	gen_server:start({global, ?HANDLERPROCNAME(NewHandlerID)}, handler, {Minty, NewHandlerID, NextHandlerID, node()}, []),
  %catch
  %  _:_ -> dsutils:log("Error parsing command line parameters.")
  %end,
  halt().


%Case where we're not connecting to anyone else
mainHelp(M, Name) ->
	%try 
    % Erlang networking boilerplate 
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

	%Start the SH
	utils:log("Starting storage handler with ID ~w", [0]),
	utils:log("Registering with name ~w", [?HANDLERPROCNAME(0)]),
	%Maybe should not be global?
	Minty = list_to_integer(M),
	gen_server:start({global, ?HANDLERPROCNAME(0)}, handler, {Minty, 0, node()}, []),

	%Call another gen_server thing to give it M and Name for the record
    
    %register(philosopher, self()),
    %Set the cookie to PHILOSOPHER (was causing an error when I tried to connect to my partner's nodes)
    %erlang:set_cookie(node(), 'storage'),
    %dsutils:log("My node name is '~s'", [node()]),
    %N = [list_to_atom(X) || X <- Neighbors],
    %joining(N) % We begin in the joining state
  %catch
  %  _:_ -> dsutils:log("Error parsing command line parameters.")
  %end,

  timer:sleep(10000),

  Names = global:registered_names(),
  %io:format("Registered names (main): ~w~n", [Names]),
  halt().


%main([M | [Name | []]]]) -> 
main([M | [Name | Other]]) when Other == [] -> mainHelp(M, Name);
main([M | [Name | [Other]]]) -> mainHelp(M, Name, Other).

