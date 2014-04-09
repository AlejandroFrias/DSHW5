%% CSCI182E - Distributed Systems
%% Harvey Mudd College
%% Helpful methods for distributed systems
%% @author Alejandro Frias
%% @doc "utils" A toolbox for Distributed Systems

-module (utils).

-export ([timestamp/0, log/1, log/2, first_n_elements/2]).

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

first_n_elements(N, List) ->
  case length(List) > N of
    true ->
      {Result, _} = lists:split(N, List),
      Result;
    false ->
      List
  end.

