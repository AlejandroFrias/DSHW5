
-module(key_value_node).

-export([main/1]).



%Macro for ?PROCNAME
-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).


%Check if it's a handler or storage
singleHandlerFilter(Name) ->
	NameList = atom_to_list(Name),
	SubName = lists:sublist(NameList, 7),
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
	TwoM = round(math:pow(2, M)), %Make it an int instead of a float
	Nums = [handlerNameToNum(N) || N <- Names],
	NumsExtended = Nums ++ [hd(Nums) + TwoM],
	{_, First, Second} = maxConsecutiveDifference(NumsExtended, 0, 0, 0),
	%We mod by the range to ensure that we get values within the range, so not like past 1024. Good comments guys
	{(First + ((Second - First) div 2)) rem TwoM, Second rem TwoM}.



main([M, Name]) -> 
	Minty = list_to_integer(M),
	%Erlang networking boilerplate
	_ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

	%Start the SH
	utils:log("Starting storage handler with ID ~w", [0]),
	utils:log("Registering with name ~w", [?HANDLERPROCNAME(0)]),
	
	gen_server:start({global, ?HANDLERPROCNAME(0)}, handler, {Minty, 0}, []),

 	timer:sleep(10000);

main([M, Name, Other]) -> 
	Minty = list_to_integer(M),

    % Erlang networking boilerplate 
    utils:log("Starting node with name ~w", [Name]),
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

    %Connect to the specified node
    ConnectResult = net_kernel:connect_node(list_to_atom(Other)),
    utils:log("Connecting to ~w, result is: ~w", [Other, ConnectResult]),

    %Sleep to let the global names sync
    timer:sleep(1000),
    
    %Compute right place to start
    Names = global:registered_names(),
    utils:log("Registered names: ~w", [Names]),
    HandlerNames = handlerFilter(Names),
    utils:log("Finding where we should go among handlers ~w", [HandlerNames]),
    {NewHandlerID, NextHandlerID} = findWidestHandlerGap(HandlerNames, Minty),

	%Start the SH
	utils:log("Staring storage handler with ID ~w", [NewHandlerID]),
	gen_server:start({global, ?HANDLERPROCNAME(NewHandlerID)}, handler, {Minty, NewHandlerID, NextHandlerID}, []).

