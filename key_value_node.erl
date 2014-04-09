
-module(key_value_node).

-export([main/1]).



%Macro for ?PROCNAME
-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).


%Check if it's a handler or storage
singleHandlerFilter(Name) ->
	io:format("HERE~n"),
	NameList = atom_to_list(Name),
	io:format("THERE~n"),
	SubName = lists:sublist(NameList, 6),
	io:format("YES~n"),
	SubName == "handler".

%Filter for handlers only
handlerFilter(Names) ->
	[X || X <- Names, singleHandlerFilter(X)].

%Parses the number out of a handler name
handlerNameToNum(Name) ->
	NameList = atom_to_list(Name),
	Number = lists:sublist(NameList, 7, 42),
	list_to_integer(Number).

%progress!
maxConsecutiveDifference([_], Max, First, Second) -> {Max, First, Second}; 
maxConsecutiveDifference([F | Nums], Max, First, Second) ->
	S = hd(Nums),
	if (S - F) > Max -> maxConsecutiveDifference(tl(Nums), S-F, F, S);
	true -> maxConsecutiveDifference(tl(Nums), Max, First, Second)
end.

%Find the widest gap in node locations, then fill it
%Take in a list of handler names
%Return the midpoint as a name, and the next name since we need that too
findWidestHandlerGap(Names, M) ->
	io:format("HERE WE GO~n"),
	Nums = [handlerNameToNum(N) || N <- Names],% lists:map(handlerNameToNum, Names),
	io:format("whereHERE WE GO~n"),
	NumsExtended = lists:append(Nums, hd(Nums) + M),
	io:format("THAR WE GO~n"),
	{_, First, Second} = maxConsecutiveDifference(NumsExtended, 0, 0, 0),
	%We mod by the range to ensure that we get values within the range, so not like past 1024. Good comments guys
	{(First + ((Second - First) div 2)) rem (math:pow(2, M)), Second rem (math:pow(2, M))}.



%Case where we are connecting to other people
mainHelp(M, Name, Other) ->
	%try 
    % Erlang networking boilerplate 
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),
    net_kernel:connect_node(list_to_atom(Other)),
    %Compute right place to start
    Names = global:registered_names(),
    io:format("Registered names: ~w~n", [Names]),
    HandlerNames = handlerFilter(Names),
    io:format("THERERER~n"),
    {NewHandlerID, NextHandlerID} = findWidestHandlerGap(HandlerNames, M),

	%Start the SH
	utils:log("Staring storage handler with ID ~n", [NewHandlerID]),
	%Maybe should not be global?
	%SHOULD HAVE THE RIGHT PROC INDEX
	%Note: This is starting a dummy process so it can figure out where it should be.
	gen_server:start({global, ?HANDLERPROCNAME(NewHandlerID)}, handler, {M, NewHandlerID, NextHandlerID}, []),
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
	utils:log("Registering with name ~w", [?STORAGEPROCNAME(0)]),
	%Maybe should not be global?
	gen_server:start({global, ?STORAGEPROCNAME(0)}, handler, {M, 0}, []),

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

  global:register_name(stupid, self()	),
  timer:sleep(10000),

  Names = global:registered_names(),
  io:format("Registered names (main): ~w~n", [Names]),
  halt().


%main([M | [Name | []]]]) -> 
main([M | [Name | Other]]) when Other == [] -> mainHelp(M, Name);
main([M | [Name | Other]]) -> mainHelp(M, Name, Other).

