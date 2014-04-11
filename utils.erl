%% CSCI182E - Distributed Systems
%% Harvey Mudd College
%% Helpful methods for distributed systems
%% @author Alejandro Frias
%% @doc "utils" A toolbox for Distributed Systems

-module (utils).

-define(STORAGEPROCNAME (Num), list_to_atom( "storage" ++ integer_to_list(Num) ) ).

-define(HANDLERPROCNAME (Num), list_to_atom( "handler" ++ integer_to_list(Num) ) ).

-export ([timestamp/0,
          log/1,
          log/2,
          first_n_elements/2,
          isHandler/1,
          getID/1,
          modDist/3,
          log2/1,
          logB/2,
          pow2/1,
          slog/2,
          slog/3,
          hlog/2,
          hlog/3]).

timestamp() ->
  {A, B, Milli} = now(),
  {{Y, Month, D}, {H, Min, S}} = calendar:now_to_local_time({A,B,0}),
  io:format("~p-~p-~p ~p:~p:~p.~p: ", [Y, Month, D, H, Min, S, Milli]).

log(Message) ->
  timestamp(),
  io:format("~s~n", [Message]).

log(Message, Format) ->
  S = io_lib:format(Message, Format),
  log(S).

slog(Message, ProcNum) -> 
  S = io_lib:format(" (~p) " ++ Message, ?STORAGEPROCNAME(ProcNum)),
  log(S).

slog(Message, Format, ProcNum) ->
  S = io_lib:format(Message, Format),
  slog(S).

hlog(Message, ProcNum) -> 
  S = io_lib:format(" (~p) " ++ Message, ?HANDLERPROCNAME(ProcNum)),
  log(S).

hlog(Message, Format, ProcNum) ->
  S = io_lib:format(Message, Format),
  hlog(S).


first_n_elements(N, List) ->
  case length(List) > N of
    true ->
      {Result, _} = lists:split(N, List),
      Result;
    false ->
      List
  end.

%Check if it's a handler or storage
isHandler(Name) ->
  io:format("name is ~w~n", [Name]),
  NameList = atom_to_list(Name),
  SubName = lists:sublist(NameList, 7),
  io:format("subname is ~w~n", [list_to_atom(SubName)]),
  SubName == "handler".

%Parses the number out of a handler name
getID(Name) ->
  NameList = atom_to_list(Name),
  Number = lists:sublist(NameList, 8, 42),
  list_to_integer(Number).

% returns the distance between two numbers, A and B, when there are 2^M numbers 
% and it wraps around. Finds the distance moving in the positive direction only.
modDist(M, A, B) ->
  Dist = (B - A) rem pow2(M), 
  (Dist + pow2(M)) rem pow2(M).

pow2(M) ->
  1 bsl M.

logB(Num, Base) ->
  math:log(Num) / math:log(Base).

log2(Num) ->
  logB(Num, 2).
