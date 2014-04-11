-module (t).

-export([init/0, connect/1, getPid/1]).

-define(STORAGEPROCNAME (Num), list_to_atom("storage" ++ integer_to_list(Num))).

-define(HANDLERPROCNAME (Num), list_to_atom("handler" ++ integer_to_list(Num))).


init() ->
  _ = os:cmd("epmd -daemon"),
  net_kernel:start([testy, shortnames]),
  connect(node()).

connect(Node) ->
  net_kernel:connect_node(Node).

getPid(ProcNum) ->
  global:whereis_name(?STORAGEPROCNAME(ProcNum)).



