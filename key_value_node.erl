
-module(key_value_node).

-export([main/1]).

%%Filter for handlers only
handlerFilter(Names) ->
    [X || X <- Names, utils:isHandler(X)].

%%progress!
maxConsecutiveDifference([_], Max, First, Second) -> {Max, First, Second}; 
maxConsecutiveDifference([F | Nums], Max, First, Second) ->
    S = hd(Nums),
    if (S - F) > Max -> maxConsecutiveDifference(Nums, S-F, F, S);
       true -> maxConsecutiveDifference(Nums, Max, First, Second)
    end.

%%Find the widest gap in node locations, then fill it
%%Take in a list of handler names
%%Return the midpoint as a name, and the next name since we need that too
findWidestHandlerGap(Names, M) ->
    TwoM = 1 bsl M,
    Nums = [utils:getID(N) || N <- Names],
    SortedNums = lists:sort(Nums),
    NumsExtended = SortedNums ++ [hd(SortedNums) + TwoM],
    {_, First, Second} = maxConsecutiveDifference(NumsExtended, 0, 0, 0),
    %%We mod by the range to ensure that we get values within the range, so not like past 1024. Good comments guys
    {First rem TwoM, (First + ((Second - First) div 2)) rem TwoM, Second rem TwoM}.



main([M, Name]) -> 
    Minty = list_to_integer(M),
    %%Erlang networking boilerplate
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

    %%Start the SH
    utils:log("Starting storage handler with ID ~w", [0]),
    utils:log("Registering with name ~w", [utils:hname(0)]),

    handler:start({Minty});

main([M, Name, Other]) -> 
    Minty = list_to_integer(M),

    %% Erlang networking boilerplate 
    utils:log("Starting node with name ~w", [Name]),
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

    OtherStr = list_to_atom(Other),
    %%Connect to the specified node
    ConnectResult = net_kernel:connect_node(OtherStr),
    utils:log("Connecting to ~p, result is: ~p", [OtherStr, ConnectResult]),

    %%Sleep to let the global names sync
    %%timer:sleep(1000),
    global:sync(),

    %%Compute right place to start
    Names = global:registered_names(),
    utils:log("Registered names: ~w", [Names]),
    HandlerNames = handlerFilter(Names),
    utils:log("Finding where we should go among handlers ~w", [HandlerNames]),
    {PrevHandlerID, NewHandlerID, NextHandlerID} = findWidestHandlerGap(HandlerNames, Minty),

    %%Start the SH
    utils:log("Starting storage handler with ID ~w", [NewHandlerID]),
    utils:log("Registering with name ~w", [utils:hname(NewHandlerID)]),

    handler:start( {Minty, PrevHandlerID, NewHandlerID, NextHandlerID} ),
    
    %% gen_server:start({global, utils:hname(NewHandlerID)}, handler, {Minty, PrevHandlerID, NewHandlerID, NextHandlerID}, []),
    %% timer:sleep(1000),

    %% Sanity checking for debugging.
    utils:log("Registered names: ~p", [global:registered_names()]).

