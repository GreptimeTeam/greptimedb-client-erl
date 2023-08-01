%% Copyright 2023 Greptime Team
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(greptimedb_worker).

-behaviour(gen_server).

-behavihour(ecpool_worker).

-include_lib("grpcbox/include/grpcbox.hrl").

-export([handle/2, stream/1, ddl/0, health_check/1]).
-export([start_link/1, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, async_handle/3]).
-export([connect/1]).

-record(state, {channel, requests}).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-define(CALL_TIMEOUT, 12_000).
-define(HEALTH_CHECK_TIMEOUT, 1_000).
-define(REQUEST_TIMEOUT, 10_000).
-define(CONNECT_TIMEOUT, 5_000).
-define(ASYNC_BATCH_SIZE, 1).
-define(ASYNC_REQ(Req, ExpireAt, ResultCallback),
        {async, Req, ExpireAt, ResultCallback}
       ).
-define(REQ(Req, ExpireAt),
        {Req, ExpireAt}
       ).
-define(PEND_REQ(ReplyTo, Req), {ReplyTo, Req}).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================
init(Args) ->
    logger:debug("[GreptimeDB] genserver has started (~w)~n", [self()]),
    Endpoints = proplists:get_value(endpoints, Args),
    Options = proplists:get_value(gprc_options, Args, #{connect_timeout => ?CONNECT_TIMEOUT}),
    Channels =
        lists:map(fun({Schema, Host, Port}) -> {Schema, Host, Port, []} end, Endpoints),
    Channel = list_to_atom(pid_to_list(self())),
    {ok, _} = grpcbox_channel_sup:start_child(Channel, Channels, Options),
    {ok, #state{channel = Channel, requests = #{ pending => queue:new(), pending_count => 0}}}.

handle_call({handle, Request}, _From, #state{channel = Channel} = State) ->
    Ctx = ctx:with_deadline_after(?REQUEST_TIMEOUT, millisecond),
    Reply = greptime_v_1_greptime_database_client:handle(Ctx, Request, #{channel => Channel}),
    case Reply of
        {ok, Resp, _} ->
            {reply, {ok, Resp}, State};
        {error, {?GRPC_STATUS_UNAUTHENTICATED, Msg}, Other} ->
            {reply, {error, {unauth, Msg, Other}}, State};
        Err ->
            {reply, Err, State}
    end;
handle_call(health_check, _From, #state{channel = Channel} = State) ->
    Request = #{},
    Ctx = ctx:with_deadline_after(?HEALTH_CHECK_TIMEOUT, millisecond),
    Reply =
        greptime_v_1_health_check_client:health_check(Ctx, Request, #{channel => Channel}),
    case Reply of
        {ok, Resp, _} ->
            {reply, {ok, Resp}, State};
        Err ->
            {reply, Err, State}
    end;
handle_call(channel, _From, #state{channel = Channel} = State) ->
    {reply, {ok, Channel}, State}.

handle_info(?ASYNC_REQ(Request, ExpireAt, ResultCallback), State0) ->
    Req = ?REQ(Request, ExpireAt),
    State1 = enqueue_req(ResultCallback, Req, State0),
    State = maybe_shoot(State1),
    {noreply, State};
handle_info(Info, State) ->
    logger:warn("~p unexpected_info: ~p, channel: ~p", [?MODULE, Info, State#state.channel]),

    {noreply, State}.


start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

handle_cast(_Request, State) ->
    {noreply, State}.

terminate(Reason, #state{channel = Channel} = State) ->
    logger:debug("[GreptimeDB] genserver has stopped (~w)~n", [self()]),
    grpcbox_channel:stop(Channel),
    {stop, Reason, State}.


%%%===================================================================
%%% Helper functions
%%%===================================================================
now_() ->
    erlang:system_time(millisecond).


fresh_expire_at(infinity = _Timeout) ->
    infinity;
fresh_expire_at(Timeout) when is_integer(Timeout) ->
    now_() + Timeout.

enqueue_latest_fn(#{prioritise_latest := true}) ->
    fun queue:in_r/2;
enqueue_latest_fn(_) ->
    fun queue:in/2.

peek_oldest_fn(#{prioritise_latest := true}) ->
    {fun queue:peek_r/1, fun queue:out_r/1};
peek_oldest_fn(_) ->
    {fun queue:peek/1, fun queue:out/1}.

%% For async-request, we evaluate the result-callback with {error, timeout}
maybe_reply_timeout({F, A}) when is_function(F) ->
    _ = erlang:apply(F, A ++ [{error, timeout}]),
    ok;
maybe_reply_timeout(_) ->
    %% This is not a callback, but the gen_server:call's From
    %% The caller should have alreay given up waiting for a reply,
    %% so no need to call gen_server:reply(From, {error, timeout})
    ok.

reply({F, A}, Result) when is_function(F) ->
    _ = erlang:apply(F, A ++ [Result]),
    ok;
reply(From, Result) ->
    gen_server:reply(From, Result).


%%%===================================================================
%%% Async requests queue functions
%%%===================================================================
enqueue_req(ReplyTo, Req, #state{requests = Requests0} = State) ->
    #{
      pending := Pending,
      pending_count := PC
     } = Requests0,
    InFun = enqueue_latest_fn(Requests0),
    NewPending = InFun(?PEND_REQ(ReplyTo, Req), Pending),
    Requests = Requests0#{pending := NewPending, pending_count := PC + 1},
    State#state{requests = drop_expired(Requests)}.


%% Try to write requests
maybe_shoot(#state{requests = Requests0, channel = Channel} = State0) ->
    State = State0#state{requests = drop_expired(Requests0)},
    %% If the channel is down
    ClientDown = is_pid(Channel) andalso (not is_process_alive(Channel)),
    case ClientDown of
        true ->
            State;
        false ->
            do_shoot(State)
    end.

do_shoot(#state{requests = #{pending := Pending0, pending_count := N} = Requests0, channel = Channel} = State0) when N >= ?ASYNC_BATCH_SIZE ->
    {{value, ?PEND_REQ(ReplyTo, Req)}, Pending} = queue:out(Pending0),
    Requests = Requests0#{pending := Pending, pending_count := N - 1},
    State1 = State0#state{requests = Requests},
    Ctx = ctx:with_deadline_after(?REQUEST_TIMEOUT, millisecond),
    {ok, Stream} = greptime_v_1_greptime_database_client:handle_requests(Ctx, #{channel => Channel}),
    shoot(Stream, Req, ReplyTo, State1, []);

do_shoot(State) ->
    State.

shoot(Stream, ?REQ(Req, _), ReplyTo, #state{requests = #{pending_count := 0}} = State, ReplyToList) ->

    %% Write the last request and finish stream
    case greptimedb_stream:write_request(Stream, Req) of
        ok ->
            Result =  greptimedb_stream:finish(Stream),
            lists:foreach(fun(ReplyTo0) ->
                                  reply(ReplyTo0, Result)
                          end, [ReplyTo | ReplyToList]);
        Error ->
            lists:foreach(fun(ReplyTo0) ->
                                  reply(ReplyTo0, Error)
                          end, [ReplyTo | ReplyToList])
    end,
    State;

shoot(Stream, ?REQ(Req, _), ReplyTo, #state{requests = #{pending := Pending0, pending_count := N} = Requests0} = State0, ReplyToList) ->
    case greptimedb_stream:write_request(Stream, Req) of
        ok ->
            {{value, ?PEND_REQ(ReplyTo, Req)}, Pending} = queue:out(Pending0),
            Requests = Requests0#{pending := Pending, pending_count := N - 1},
            State1 = State0#state{requests = Requests},
            shoot(Stream, Req, ReplyTo, State1, [ReplyTo | ReplyToList]);
        Error ->
            lists:foreach(fun(ReplyTo0) ->
                                  reply(ReplyTo0, Error)
                          end, [ReplyTo | ReplyToList]),
            State0
    end.

%% Continue droping expired requests, to avoid the state RAM usage
%% explosion if http client can not keep up.
drop_expired(#{pending_count := 0} = Requests) ->
    Requests;
drop_expired(Requests) ->
    drop_expired(Requests, now_()).

drop_expired(#{pending_count := 0} = Requests, _Now) ->
    Requests;
drop_expired(#{pending := Pending, pending_count := PC} = Requests, Now) ->
    {PeekFun, OutFun} = peek_oldest_fn(Requests),
    {value, ?PEND_REQ(ReplyTo, ?REQ(_, ExpireAt))} = PeekFun(Pending),
    case is_integer(ExpireAt) andalso Now > ExpireAt of
        true ->
            {_, NewPendings} = OutFun(Pending),
            NewRequests = Requests#{pending => NewPendings, pending_count => PC - 1},
            ok = maybe_reply_timeout(ReplyTo),
            drop_expired(NewRequests, Now);
        false ->
            Requests
    end.

%%%===================================================================
%%% Public functions
%%%===================================================================
handle(Pid, Request) ->
    gen_server:call(Pid, {handle, Request}, ?CALL_TIMEOUT).

async_handle(Pid, Request, ResultCallback) ->
    ExpireAt = fresh_expire_at(?REQUEST_TIMEOUT),
    _ = erlang:send(Pid, ?ASYNC_REQ(Request, ExpireAt, ResultCallback)),
    ok.

health_check(Pid) ->
    gen_server:call(Pid, health_check, ?HEALTH_CHECK_TIMEOUT).

stream(Pid) ->
    {ok, Channel} = gen_server:call(Pid, channel, ?CALL_TIMEOUT),
    Ctx = ctx:with_deadline_after(?REQUEST_TIMEOUT, millisecond),
    greptime_v_1_greptime_database_client:handle_requests(Ctx, #{channel => Channel}).

ddl() ->
    todo.

%%%===================================================================
%%% ecpool callback
%%%===================================================================
connect(Options) ->
    start_link(Options).


%%%===================================================================
%%% Tests
%%%===================================================================
-ifdef(TEST).

prioritise_latest_test() ->
    Opts = #{prioritise_latest => true},
    Seq = [1, 2, 3, 4],
    In = enqueue_latest_fn(Opts),
    {PeekOldest, OutOldest} = peek_oldest_fn(Opts),
    Q = lists:foldl(fun(I, QIn) -> In(I, QIn) end, queue:new(), Seq),
    ?assertEqual({value, 1}, PeekOldest(Q)),
    ?assertMatch({{value, 1}, _}, OutOldest(Q)),
    ?assertMatch({{value, 4}, _}, queue:out(Q)).

prioritise_oldest_test() ->
    Opts = #{prioritise_latest => false},
    Seq = [1, 2, 3, 4],
    In = enqueue_latest_fn(Opts),
    {PeekOldest, OutOldest} = peek_oldest_fn(Opts),
    Q = lists:foldl(fun(I, QIn) -> In(I, QIn) end, queue:new(), Seq),
    ?assertEqual({value, 1}, PeekOldest(Q)),
    ?assertMatch({{value, 1}, _}, OutOldest(Q)),
    ?assertMatch({{value, 1}, _}, queue:out(Q)).

-endif.
