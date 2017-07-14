-module(ra_log).

-include("ra.hrl").

-export([init/2,
         close/1,
         append/3,
         fetch/2,
         take/3,
         last/1,
         next_index/1,
         % release/2,
         read_snapshot/1,
         write_snapshot/2,
         read_meta/2,
         read_meta/3,
         write_meta/3
        ]).

-type ra_log_init_args() :: #{atom() => term()}.
-type ra_log_state() :: term().
-type ra_log() :: {Module :: module(), ra_log_state()}.
-type ra_meta_key() :: atom().
-type ra_log_snapshot() :: {ra_index(), ra_term(), ra_cluster(), term()}.

-export_type([ra_log_init_args/0,
              ra_log_state/0,
              ra_log/0,
              ra_meta_key/0,
              ra_log_snapshot/0
             ]).

-callback init(Args:: ra_log_init_args()) -> ra_log_state().

-callback close(State::  ra_log_state()) -> ok.

-callback append(Entry::log_entry(), Overwrite::boolean(),
                 State::ra_log_state()) ->
    {ok, ra_log_state()} | {error, integrity_error}.

-callback take(Start :: ra_index(), Num :: non_neg_integer(),
               State :: ra_log_state()) ->
    [log_entry()].

-callback next_index(State :: ra_log_state()) ->
    ra_index().

-callback fetch(Inx :: ra_index(), State :: ra_log_state()) ->
    maybe(log_entry()).

-callback last(State :: ra_log_state()) ->
    maybe(log_entry()).

% % release log entries at specified indices
% -callback release(Indices :: [ra_index()], State :: ra_log_state()) ->
%     ra_log_state().

% writes snapshot to storage and discards any prior entries
-callback write_snapshot(Snapshot :: ra_log_snapshot(),
                         State :: ra_log_state()) ->
    ra_log_state().

-callback read_snapshot(State :: ra_log_state()) ->
    maybe(ra_log_snapshot()).

-callback read_meta(Key :: ra_meta_key(), State :: ra_log_state()) ->
    maybe(term()).

-callback write_meta(Key :: ra_meta_key(), Value :: term(),
                     State :: ra_log_state()) ->
    {ok, ra_log_state()} | {error, term()}.

%%
%% API
%%

-spec init(Mod::atom(), Args :: ra_log_init_args()) -> ra_log().
init(Mod, Args) ->
    {Mod, Mod:init(Args)}.

-spec close(Log :: ra_log()) -> ok.
close({Mod, Log}) ->
    Mod:close(Log).

-spec fetch(Idx::ra_index(), Log::ra_log()) -> maybe(log_entry()).
fetch(Idx, {Mod, Log}) ->
    Mod:fetch(Idx, Log).

-spec append(Entry :: log_entry(), Overwrite::boolean(),
                 State::ra_log()) ->
    {ok, ra_log()} | {error, integrity_error}.
append(Entry, Overwrite, {Mod, Log0}) ->
    case Mod:append(Entry, Overwrite, Log0) of
        {ok, Log} ->
            {ok, {Mod, Log}};
        Err ->
            Err
    end.

-spec take(Start::ra_index(), Num::non_neg_integer(),
           State::ra_log()) -> [log_entry()].
take(Start, Num, {Mod, Log}) ->
    Mod:take(Start, Num, Log).

-spec last(State::ra_log()) -> maybe(log_entry()).
last({Mod, Log}) ->
    Mod:last(Log).

-spec next_index(State::ra_log()) -> ra_index().
next_index({Mod, Log}) ->
    Mod:next_index(Log).

-spec write_snapshot(Snapshot :: ra_log_snapshot(), State::ra_log()) -> ra_log().
write_snapshot(Snapshot, {Mod, Log0}) ->
    Log = Mod:write_snapshot(Snapshot, Log0),
    {Mod, Log}.

-spec read_snapshot(State::ra_log()) -> maybe(ra_log_snapshot()).
read_snapshot({Mod, Log0}) ->
    Mod:read_snapshot(Log0).

% -spec release(Indices :: [ra_index()], State :: ra_log()) ->
%     ra_log().
% release(Indices, {Mod, Log}) ->
%     {Mod, Mod:release(Indices, Log)}.

-spec read_meta(Key :: ra_meta_key(), State :: ra_log()) ->
    maybe(term()).
read_meta(Key, {Mod, Log}) ->
    Mod:read_meta(Key, Log).

-spec read_meta(Key :: ra_meta_key(), State :: ra_log(),
                Default :: term()) ->
    term().
read_meta(Key, {Mod, Log}, Default) ->
    ra_lib:default(Mod:read_meta(Key, Log), Default).

-spec write_meta(Key :: ra_meta_key(), Value :: term(),
                     State :: ra_log()) ->
    {ok, ra_log()} | {error, term()}.
write_meta(Key, Value, {Mod, Log}) ->
    case Mod:write_meta(Key, Value, Log) of
        {ok, Inner} ->
            {ok, {Mod, Inner}};
        {error, _} = Err ->
            Err
    end.
