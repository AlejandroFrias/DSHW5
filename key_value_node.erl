
-module(key_value_node).

-export([main/1]).

%Macro for ?PROCNAME
-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).
-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).

%Case where we're not connecting to anyone else
main([M | Name]) ->
	try 
    % Erlang networking boilerplate 
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

	%Start the SH
	utils:log("Staring storage handler...")
	%Maybe should not be global?
	gen_server:start({global, ?STORAGEPROCNAME(0)}, handler, {M, Name}, [])

	%Call another gen_server thing to give it M and Name for the record
    
    %register(philosopher, self()),
    %Set the cookie to PHILOSOPHER (was causing an error when I tried to connect to my partner's nodes)
    %erlang:set_cookie(node(), 'storage'),
    %dsutils:log("My node name is '~s'", [node()]),
    %N = [list_to_atom(X) || X <- Neighbors],
    %joining(N) % We begin in the joining state
  catch
    _:_ -> dsutils:log("Error parsing command line parameters.")
  end,
  halt().

%Case where we are connecting to other people
main([M | Name | Other]) ->
	try 
    % Erlang networking boilerplate 
    _ = os:cmd("epmd -daemon"),
    net_kernel:start([list_to_atom(Name), shortnames]),

	%Start the SH
	utils:log("Staring storage handler...")
	%Maybe should not be global?
	%SHOULD HAVE THE RIGHT PROC INDEX
	gen_server:start({global, ?STORAGEPROCNAME()}, handler, {M, Name, Other}, [])
  catch
    _:_ -> dsutils:log("Error parsing command line parameters.")
  end,
  halt().



