-module(greptimedb_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

%%t_write, t_write_stream, t_insert_requests, t_write_batch, t_bench_perf,
all() ->
    [t_write_stream, t_async_write_batch].

%%[t_bench_perf].
%%[t_insert_requests, t_bench_perf].

init_per_suite(Config) ->
    application:ensure_all_started(greptimedb),
    Config.

end_per_suite(_Config) ->
    application:stop(greptimedb).

points(N) ->
    lists:map(fun(Num) ->
                 #{fields => #{<<"temperature">> => Num},
                   tags =>
                       #{<<"from">> => <<"mqttx_4b963a8e">>,
                         <<"host">> => <<"serverB">>,
                         <<"qos">> => "1",
                         <<"region">> => <<"ningbo">>,
                         <<"to">> => <<"kafka">>},
                   timestamp => 1619775143098 + Num}
              end,
              lists:seq(1, N)).

t_insert_requests(_) ->
    Points =
        [#{fields => #{<<"temperature">> => 1},
           tags =>
               #{<<"from">> => <<"mqttx_4b963a8e">>,
                 <<"host">> => <<"serverA">>,
                 <<"qos">> => "0",
                 <<"device">> => <<"NO.1">>,
                 <<"region">> => <<"hangzhou">>},
           timestamp => 1619775142098},
         #{fields => #{<<"temperature">> => 2},
           tags =>
               #{<<"from">> => <<"mqttx_4b963a8e">>,
                 <<"host">> => <<"serverB">>,
                 <<"qos">> => "1",
                 <<"region">> => <<"ningbo">>,
                 <<"to">> => <<"kafka">>},
           timestamp => 1619775143098},
         #{fields => #{<<"temperature">> => 3},
           tags =>
               #{<<"from">> => <<"mqttx_4b963a8e">>,
                 <<"host">> => <<"serverB">>,
                 <<"qos">> => "2",
                 <<"region">> => <<"xiamen">>,
                 <<"to">> => <<"kafka">>},
           timestamp => 1619775144098}],

    Metric = "Test",
    AuthInfo = {basic, #{username => "test", password => "test"}},
    Client = #{cli_opts => [{auth, AuthInfo}, {timeunit, second}]},
    Request = greptimedb_encoder:insert_requests(Client, [{Metric, Points}]),
    case Request of
        #{header := #{dbname := DbName, authorization := Auth},
          request := {inserts, #{inserts := [#{columns := Columns}]}}} ->
            ?assertEqual(DbName, "greptime-public"),
            ?assertEqual(8, length(Columns)),
            ?assertEqual(Auth, #{auth_scheme => AuthInfo}),

            {value, TemperatureColumn} =
                lists:search(fun(C) -> maps:get(column_name, C) == <<"temperature">> end, Columns),
            ?assertEqual([1, 2, 3], maps:get(f64_values, maps:get(values, TemperatureColumn))),

            {value, QosColumn} =
                lists:search(fun(C) -> maps:get(column_name, C) == <<"qos">> end, Columns),
            ?assertEqual(["0", "1", "2"], maps:get(string_values, maps:get(values, QosColumn))),

            {value, ToColumn} =
                lists:search(fun(C) -> maps:get(column_name, C) == <<"to">> end, Columns),
            ?assertEqual([<<"kafka">>, <<"kafka">>],
                         maps:get(string_values, maps:get(values, ToColumn))),
            ?assertEqual(<<0:6/integer, 1:1/integer, 1:1/integer>>, maps:get(null_mask, ToColumn)),

            {value, DeviceColumn} =
                lists:search(fun(C) -> maps:get(column_name, C) == <<"device">> end, Columns),
            ?assertEqual([<<"NO.1">>], maps:get(string_values, maps:get(values, DeviceColumn))),
            ?assertEqual(<<0:5/integer, 1:1/integer, 0:1/integer, 0:1/integer>>,
                         maps:get(null_mask, DeviceColumn)),

            {value, TimestampColumn} =
                lists:search(fun(C) -> maps:get(column_name, C) == <<"greptime_timestamp">> end,
                             Columns),
            ?assertEqual([1619775142098, 1619775143098, 1619775144098],
                         maps:get(ts_second_values, maps:get(values, TimestampColumn)));
        _ ->
            ?assert(false)
    end,
    ok.

t_write(_) ->
    Metric = <<"temperatures">>,
    Points =
        [#{fields => #{<<"temperature">> => 1},
           tags =>
               #{<<"from">> => <<"mqttx_4b963a8e">>,
                 <<"host">> => <<"serverA">>,
                 <<"qos">> => greptimedb_values:int64_value(0),
                 <<"region">> => <<"hangzhou">>},
           timestamp => 1619775142098},
         #{fields => #{<<"temperature">> => 2},
           tags =>
               #{<<"from">> => <<"mqttx_4b963a8e">>,
                 <<"host">> => <<"serverB">>,
                 <<"qos">> => greptimedb_values:int64_value(1),
                 <<"region">> => <<"ningbo">>,
                 <<"to">> => <<"kafka">>},
           timestamp => 1619775143098}],
    Options =
        [{endpoints, [{http, "localhost", 4001}]},
         {pool, greptimedb_client_pool},
         {pool_size, 5},
         {pool_type, random},
         {auth, {basic, #{username => <<"greptime_user">>, password => <<"greptime_pwd">>}}}],

    {ok, Client} = greptimedb:start_client(Options),
    true = greptimedb:is_alive(Client),
    {ok, #{response := {affected_rows, #{value := 2}}}} =
        greptimedb:write(Client, Metric, Points),
    greptimedb:stop_client(Client),
    ok.

t_auth_error(_) ->
    Metric = <<"temperatures">>,
    Points =
        [#{fields => #{<<"temperature">> => 1},
           tags =>
               #{<<"from">> => <<"mqttx_4b963a8e">>,
                 <<"host">> => <<"serverA">>,
                 <<"qos">> => greptimedb_values:int64_value(0),
                 <<"region">> => <<"hangzhou">>},
           timestamp => 1619775142098},
         #{fields => #{<<"temperature">> => 2},
           tags =>
               #{<<"from">> => <<"mqttx_4b963a8e">>,
                 <<"host">> => <<"serverB">>,
                 <<"qos">> => greptimedb_values:int64_value(1),
                 <<"region">> => <<"ningbo">>,
                 <<"to">> => <<"kafka">>},
           timestamp => 1619775143098}],
    Options =
        [{endpoints, [{http, "localhost", 4001}]},
         {pool, greptimedb_client_pool},
         {pool_size, 5},
         {pool_type, random},
         {auth, {basic, #{username => <<"greptime_user">>, password => <<"wrong_pwd">>}}}],
    {ok, Client} = greptimedb:start_client(Options),
    {error, {unauth, _, _}} = greptimedb:write(Client, Metric, Points).

t_write_stream(_) ->
    Options =
        [{endpoints, [{http, "localhost", 4001}]},
         {pool, greptimedb_client_pool},
         {pool_size, 8},
         {pool_type, random},
         {auth, {basic, #{username => <<"greptime_user">>, password => <<"greptime_pwd">>}}}],

    {ok, Client} = greptimedb:start_client(Options),
    true = greptimedb:is_alive(Client),
    {ok, Stream} = greptimedb:write_stream(Client),

    Metric = <<"temperatures_stream">>,
    lists:foreach(fun(N) ->
                     Points = points(N),
                     ok = greptimedb_stream:write(Stream, Metric, Points)
                  end,
                  lists:seq(1, 10)),

    {ok, #{response := {affected_rows, #{value := 55}}}} = greptimedb_stream:finish(Stream),
    greptimedb:stop_client(Client),
    ok.

t_write_batch(_) ->
    Options =
        [{endpoints, [{http, "localhost", 4001}]},
         {pool, greptimedb_client_pool},
         {pool_size, 8},
         {pool_type, random},
         {auth, {basic, #{username => <<"greptime_user">>, password => <<"greptime_pwd">>}}}],

    {ok, Client} = greptimedb:start_client(Options),
    true = greptimedb:is_alive(Client),

    Metric = <<"temperatures_">>,
    MetricAndPoints =
        lists:map(fun(N) ->
                     Points = points(N),
                     {erlang:iolist_to_binary([Metric, integer_to_binary(N)]), Points}
                  end,
                  lists:seq(1, 10)),

    {ok, #{response := {affected_rows, #{value := 55}}}} =
        greptimedb:write_batch(Client, MetricAndPoints),
    greptimedb:stop_client(Client),
    ok.

rand_string(Bytes) ->
    base64:encode(
        crypto:strong_rand_bytes(Bytes)).

bench_points(StartTs, N) ->
    lists:map(fun(Num) ->
                 #{fields =>
                       #{<<"f0">> => Num,
                         <<"f1">> => Num,
                         <<"f2">> => Num,
                         <<"f3">> => Num,
                         <<"f4">> => Num,
                         <<"f5">> => Num,
                         <<"f6">> => Num,
                         <<"f7">> => Num,
                         <<"f8">> => Num,
                         <<"f9">> => rand:uniform(Num)},
                   tags =>
                       #{<<"tag0">> => <<"tagv0">>,
                         <<"tag1">> => <<"tagv1">>,
                         <<"tag2">> => <<"tagv2">>,
                         <<"tag3">> => <<"tagv3">>,
                         <<"tag4">> => <<"tagv4">>,
                         <<"tag5">> => <<"tagv5">>,
                         <<"tag6">> => <<"tagv6">>,
                         <<"tag7">> => <<"tagv7">>,
                         <<"tag8">> => <<"tagv8">>,
                         <<"tag9">> => rand_string(8)},
                   timestamp => StartTs + Num}
              end,
              lists:seq(1, N)).

bench_write(N, StartMs, BatchSize, Client, BenchmarkEncoding) ->
    bench_write(N, StartMs, BatchSize, Client, BenchmarkEncoding, 0).

bench_write(0, _StartMs, _BatchSize, _Client, _BenchmarkEncoding, Written) ->
    Written;
bench_write(N, StartMs, BatchSize, Client, BenchmarkEncoding, Written) ->
    Rows =
        case BenchmarkEncoding of
            true ->
                Metric = <<"bench_metrics">>,
                Points = bench_points(StartMs - N, BatchSize),
                _Request = greptimedb_encoder:insert_requests(Client, [{Metric, Points}]),
                length(Points);
            false ->
                {ok, #{response := {affected_rows, #{value := AffectedRows}}}} =
                    greptimedb:write(Client,
                                     <<"bench_metrics">>,
                                     bench_points(1687814974000 - N, BatchSize)),
                AffectedRows
        end,

    NewWritten = Written + Rows,
    bench_write(N - 1, StartMs, BatchSize, Client, BenchmarkEncoding, NewWritten).

join([P | Ps]) ->
    receive
        {P, Result} ->
            [Result | join(Ps)]
    end;
join([]) ->
    [].

t_bench_perf(_) ->
    Options =
        [{endpoints, [{http, "localhost", 4001}]},
         {pool, greptimedb_client_pool},
         {pool_size, 8},
         {pool_type, random},
         {timeunit, ms},
         {auth, {basic, #{username => <<"greptime_user">>, password => <<"greptime_pwd">>}}}],

    {ok, Client} = greptimedb:start_client(Options),
    true = greptimedb:is_alive(Client),
    BatchSize = 100,
    Num = 1000,
    Profile = false,
    BenchmarkEncoding = false,
    Concurrency = 3,
    {MegaSecs, Secs, _MicroSecs} = erlang:timestamp(),
    StartMs = (MegaSecs * 1000000 + Secs) * 1000,

    %% warmup
    bench_write(1000, StartMs, BatchSize, Client, BenchmarkEncoding),
    ct:print("Warmed up, start to benchmark writing..."),
    %% benchmark
    T1 = erlang:monotonic_time(),
    Rows =
        case Profile of
            true ->
                ct:print("Enable eprof..."),
                eprof:start(),
                eprof:log("/tmp/eprof.result"),
                {ok, Ret} =
                    eprof:profile(fun() ->
                                     bench_write(Num, StartMs, BatchSize, Client, BenchmarkEncoding)
                                  end),
                eprof:analyze(),
                eprof:stop(),
                Ret;
            false ->
                Parent = self(),
                Pids =
                    lists:map(fun(C) ->
                                 spawn(fun() ->
                                          Written =
                                              bench_write(Num,
                                                          StartMs - C * Num * BatchSize,
                                                          BatchSize,
                                                          Client,
                                                          BenchmarkEncoding),
                                          Parent ! {self(), Written}
                                       end)
                              end,
                              lists:seq(1, Concurrency)),
                lists:sum(join(Pids))
        end,

    T2 = erlang:monotonic_time(),
    Time = erlang:convert_time_unit(T2 - T1, native, seconds),
    TPS = Rows / Time,
    %% print the result
    ct:print("Finish benchmark, concurrency: ~p, cost: ~p seconds, rows: ~p, TPS: ~p~n",
             [Concurrency, Time, Rows, TPS]),
    greptimedb:stop_client(Client),
    ok.


async_write(Client, StartMs) ->
    Ref = make_ref(),
    TestPid = self(),
    ResultCallback = {fun(Reply) -> TestPid ! {{Ref, reply}, Reply} end, []},

    Metric = <<"async_metrics">>,
    Points = bench_points(StartMs, 10),

    ok = greptimedb:async_write_batch(Client, [{Metric, Points}], ResultCallback),

    Ref.

t_async_write_batch(_) ->
    Options =
        [{endpoints, [{http, "localhost", 4001}]},
         {pool, greptimedb_client_pool2},
         {pool_size, 8},
         {pool_type, random},
         {auth, {basic, #{username => <<"greptime_user">>, password => <<"greptime_pwd">>}}}],

    {ok, Client} = greptimedb:start_client(Options),
    true = greptimedb:is_alive(Client),

    StartMs = 1690874475279,

    Ref1 = async_write(Client, StartMs),
    Ref2 = async_write(Client, StartMs + 10),
    Ref3 = async_write(Client, StartMs + 20),
    receive
        {{Ref1, reply}, Reply} ->
            ct:print("Reply1 ~w~n", [Reply]);
        {{Ref2, reply}, Reply} ->
            ct:print("Reply2 ~w~n", [Reply]);
        {{Ref3, reply}, Reply} ->
            ct:print("Reply3 ~w~n", [Reply])
    end,
    greptimedb:stop_client(Client),
    ok.
