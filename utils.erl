%%% -------------------------------------------------------------------
%%% CSCI182E - Distributed Systems
%%% @author Alejandro Frias, Ravi Kumar, David Scott
%%%
%%% Helpful utility functions used for Homework 5.
%%%--------------------------------------------------------------------


-module (utils).

-export ([timestamp/0,
          log/1,
          log/2,
          first_n_elements/2,
          isHandler/1,
          isStorage/1,
          getID/1,
          modDist/3,
          log2/1,
          logB/2,
          pow2/1,
          slog/2,
          slog/3,
          hlog/2,
          hlog/3,
          dlog/2,
          dlog/3,
          sname/1,
          hname/1,
          modSeq/3,
          modInc/2,
          modDec/2,
          key_min/2,
          key_max/2]).

%% Prints a time stamp.
timestamp() ->
  {A, B, Milli} = now(),
  {{Y, Month, D}, {H, Min, S}} = calendar:now_to_local_time({A,B,0}),
  io:format("~p-~p-~p ~p:~p:~p.~p: ", [Y, Month, D, H, Min, S, Milli]).

%% Prints a message with a time stamped
log(Message) ->
  timestamp(),
  io:format("~s~n", [Message]).
log(Message, Format) ->
  S = io_lib:format(Message, Format),
  log(S).

%% Logs a message, but accepts a debug mode which turns it off or on
dlog(Message, Debug) ->
  case Debug of
    true ->
      timestamp(),
      io:format("~s~n", [Message]);
    _Other ->
      ok
  end.
dlog(Message, Format, Debug) ->
  S = io_lib:format(Message, Format),
  dlog(S, Debug).

%% Logging for storage processes
slog(Message, ProcNum) -> 
  S = io_lib:format(" (~p) " ++ Message, [sname(ProcNum)]),
  log(S).
slog(Message, Format, ProcNum) ->
  S = io_lib:format(Message, Format),
  slog(S, ProcNum).

%% Logging for handler processes
hlog(Message, ProcNum) -> 
  S = io_lib:format(" (~p) " ++ Message, [hname(ProcNum)]),
  log(S).
hlog(Message, Format, ProcNum) ->
  S = io_lib:format(Message, Format),
  hlog(S, ProcNum).

%% Grabs the first n elemented from a list, or all the items if N > length(List)
first_n_elements(N, List) ->
  case length(List) > N of
    true ->
      {Result, _} = lists:split(N, List),
      Result;
    false ->
      List
  end.

%% Check if Name is a handler process
isHandler(Name) ->
  % io:format("name is ~w~n", [Name]),
  NameList = atom_to_list(Name),
  SubName = lists:sublist(NameList, 7),
  % io:format("subname is ~w~n", [list_to_atom(SubName)]),
  SubName == "handler".

%% Check if Nameis is a storage process
isStorage(Name) ->
  % io:format("name is ~w~n", [Name]),
  NameList = atom_to_list(Name),
  SubName = lists:sublist(NameList, 7),
  % io:format("subname is ~w~n", [list_to_atom(SubName)]),
  SubName == "storage".

%% Parses the ID number out of a handler or storage name
getID(Name) ->
  NameList = atom_to_list(Name),
  Number = lists:sublist(NameList, 8, 42),
  list_to_integer(Number).

%% returns the distance between two numbers, A and B, when there are 2^M numbers 
%% and it wraps around. Finds the distance moving in the positive direction only.
modDist(M, A, B) ->
  Dist = (B - A) rem pow2(M), 
  (Dist + pow2(M)) rem pow2(M).

%% Using bit shift left to return 2^M
pow2(M) ->
  1 bsl M.

%% Log with given base
logB(Num, Base) ->
  math:log(Num) / math:log(Base).

%% Log base 2
log2(Num) ->
  logB(Num, 2).

%% Creates an atom for a storage process out of ID num
sname(Num) ->
  list_to_atom("storage" ++ integer_to_list(Num)).

%% Creates an atom for a handler process out of ID num
hname(Num) ->
  list_to_atom("handler" ++ integer_to_list(Num)).

%% Returns a sequence from Start to End that wraps around 2^M
modSeq(Start, End, M) ->
  modSeq(Start, End, M, []).

modSeq(Start, Start, _M, Seq) ->
  lists:reverse([Start | Seq]);
modSeq(Start, End, M, Seq) ->
  modSeq(modInc(Start, M), End, M, [Start | Seq]).

%% Increments Num modulo 2^M
modInc(Num, M) ->
  (Num + 1) rem pow2(M).

%% Decrements Num modulo 2^M (always positive results)
modDec(Num, M) ->
  (Num - 1 + pow2(M)) rem pow2(M).

key_min(A, B) ->
    case B == no_value of
        true ->
            A;
        false ->
            min(A, B)
    end.

key_max(A, B) ->
    case B == no_value of
        true ->
            A;
        false ->
            max(A, B)
    end.
