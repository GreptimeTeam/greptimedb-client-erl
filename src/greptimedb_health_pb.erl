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

-module(greptimedb_health_pb).

-export([encode_msg/2, encode_msg/3]).
-export([decode_msg/2, decode_msg/3]).
-export([merge_msgs/3, merge_msgs/4]).
-export([verify_msg/2, verify_msg/3]).
-export([get_msg_defs/0]).
-export([get_msg_names/0]).
-export([get_group_names/0]).
-export([get_msg_or_group_names/0]).
-export([get_enum_names/0]).
-export([find_msg_def/1, fetch_msg_def/1]).
-export([find_enum_def/1, fetch_enum_def/1]).
-export([enum_symbol_by_value/2, enum_value_by_symbol/2]).
-export([get_service_names/0]).
-export([get_service_def/1]).
-export([get_rpc_names/1]).
-export([find_rpc_def/2, fetch_rpc_def/2]).
-export([fqbin_to_service_name/1]).
-export([service_name_to_fqbin/1]).
-export([fqbins_to_service_and_rpc_name/2]).
-export([service_and_rpc_name_to_fqbins/2]).
-export([fqbin_to_msg_name/1]).
-export([msg_name_to_fqbin/1]).
-export([fqbin_to_enum_name/1]).
-export([enum_name_to_fqbin/1]).
-export([get_package_name/0]).
-export([uses_packages/0]).
-export([source_basename/0]).
-export([get_all_source_basenames/0]).
-export([get_all_proto_names/0]).
-export([get_msg_containment/1]).
-export([get_pkg_containment/1]).
-export([get_service_containment/1]).
-export([get_rpc_containment/1]).
-export([get_enum_containment/1]).
-export([get_proto_by_msg_name_as_fqbin/1]).
-export([get_proto_by_service_name_as_fqbin/1]).
-export([get_proto_by_enum_name_as_fqbin/1]).
-export([get_protos_by_pkg_name_as_fqbin/1]).
-export([gpb_version_as_string/0, gpb_version_as_list/0]).
-export([gpb_version_source/0]).


%% enumerated types

-export_type([]).

%% message types
-type health_check_request() ::
      #{
       }.

-type health_check_response() ::
      #{
       }.

-export_type(['health_check_request'/0, 'health_check_response'/0]).
-type '$msg_name'() :: health_check_request | health_check_response.
-type '$msg'() :: health_check_request() | health_check_response().
-export_type(['$msg_name'/0, '$msg'/0]).

-if(?OTP_RELEASE >= 24).
-dialyzer({no_underspecs, encode_msg/2}).
-endif.
-spec encode_msg('$msg'(), '$msg_name'()) -> <<>>.
encode_msg(Msg, MsgName) when is_atom(MsgName) -> encode_msg(Msg, MsgName, []).

-if(?OTP_RELEASE >= 24).
-dialyzer({no_underspecs, encode_msg/3}).
-endif.
-spec encode_msg('$msg'(), '$msg_name'(), list()) -> <<>>.
encode_msg(Msg, MsgName, Opts) ->
    case proplists:get_bool(verify, Opts) of
        true -> verify_msg(Msg, MsgName, Opts);
        false -> ok
    end,
    TrUserData = proplists:get_value(user_data, Opts),
    case MsgName of
        health_check_request -> encode_msg_health_check_request(id(Msg, TrUserData), TrUserData);
        health_check_response -> encode_msg_health_check_response(id(Msg, TrUserData), TrUserData)
    end.


encode_msg_health_check_request(_Msg, _TrUserData) -> <<>>.

encode_msg_health_check_response(_Msg, _TrUserData) -> <<>>.

-compile({nowarn_unused_function,e_type_sint/3}).
e_type_sint(Value, Bin, _TrUserData) when Value >= 0 -> e_varint(Value * 2, Bin);
e_type_sint(Value, Bin, _TrUserData) -> e_varint(Value * -2 - 1, Bin).

-compile({nowarn_unused_function,e_type_int32/3}).
e_type_int32(Value, Bin, _TrUserData) when 0 =< Value, Value =< 127 -> <<Bin/binary, Value>>;
e_type_int32(Value, Bin, _TrUserData) ->
    <<N:64/unsigned-native>> = <<Value:64/signed-native>>,
    e_varint(N, Bin).

-compile({nowarn_unused_function,e_type_int64/3}).
e_type_int64(Value, Bin, _TrUserData) when 0 =< Value, Value =< 127 -> <<Bin/binary, Value>>;
e_type_int64(Value, Bin, _TrUserData) ->
    <<N:64/unsigned-native>> = <<Value:64/signed-native>>,
    e_varint(N, Bin).

-compile({nowarn_unused_function,e_type_bool/3}).
e_type_bool(true, Bin, _TrUserData) -> <<Bin/binary, 1>>;
e_type_bool(false, Bin, _TrUserData) -> <<Bin/binary, 0>>;
e_type_bool(1, Bin, _TrUserData) -> <<Bin/binary, 1>>;
e_type_bool(0, Bin, _TrUserData) -> <<Bin/binary, 0>>.

-compile({nowarn_unused_function,e_type_string/3}).
e_type_string(S, Bin, _TrUserData) ->
    Utf8 = unicode:characters_to_binary(S),
    Bin2 = e_varint(byte_size(Utf8), Bin),
    <<Bin2/binary, Utf8/binary>>.

-compile({nowarn_unused_function,e_type_bytes/3}).
e_type_bytes(Bytes, Bin, _TrUserData) when is_binary(Bytes) ->
    Bin2 = e_varint(byte_size(Bytes), Bin),
    <<Bin2/binary, Bytes/binary>>;
e_type_bytes(Bytes, Bin, _TrUserData) when is_list(Bytes) ->
    BytesBin = iolist_to_binary(Bytes),
    Bin2 = e_varint(byte_size(BytesBin), Bin),
    <<Bin2/binary, BytesBin/binary>>.

-compile({nowarn_unused_function,e_type_fixed32/3}).
e_type_fixed32(Value, Bin, _TrUserData) -> <<Bin/binary, Value:32/little>>.

-compile({nowarn_unused_function,e_type_sfixed32/3}).
e_type_sfixed32(Value, Bin, _TrUserData) -> <<Bin/binary, Value:32/little-signed>>.

-compile({nowarn_unused_function,e_type_fixed64/3}).
e_type_fixed64(Value, Bin, _TrUserData) -> <<Bin/binary, Value:64/little>>.

-compile({nowarn_unused_function,e_type_sfixed64/3}).
e_type_sfixed64(Value, Bin, _TrUserData) -> <<Bin/binary, Value:64/little-signed>>.

-compile({nowarn_unused_function,e_type_float/3}).
e_type_float(V, Bin, _) when is_number(V) -> <<Bin/binary, V:32/little-float>>;
e_type_float(infinity, Bin, _) -> <<Bin/binary, 0:16, 128, 127>>;
e_type_float('-infinity', Bin, _) -> <<Bin/binary, 0:16, 128, 255>>;
e_type_float(nan, Bin, _) -> <<Bin/binary, 0:16, 192, 127>>.

-compile({nowarn_unused_function,e_type_double/3}).
e_type_double(V, Bin, _) when is_number(V) -> <<Bin/binary, V:64/little-float>>;
e_type_double(infinity, Bin, _) -> <<Bin/binary, 0:48, 240, 127>>;
e_type_double('-infinity', Bin, _) -> <<Bin/binary, 0:48, 240, 255>>;
e_type_double(nan, Bin, _) -> <<Bin/binary, 0:48, 248, 127>>.

-compile({nowarn_unused_function,e_unknown_elems/2}).
e_unknown_elems([Elem | Rest], Bin) ->
    BinR = case Elem of
               {varint, FNum, N} ->
                   BinF = e_varint(FNum bsl 3, Bin),
                   e_varint(N, BinF);
               {length_delimited, FNum, Data} ->
                   BinF = e_varint(FNum bsl 3 bor 2, Bin),
                   BinL = e_varint(byte_size(Data), BinF),
                   <<BinL/binary, Data/binary>>;
               {group, FNum, GroupFields} ->
                   Bin1 = e_varint(FNum bsl 3 bor 3, Bin),
                   Bin2 = e_unknown_elems(GroupFields, Bin1),
                   e_varint(FNum bsl 3 bor 4, Bin2);
               {fixed32, FNum, V} ->
                   BinF = e_varint(FNum bsl 3 bor 5, Bin),
                   <<BinF/binary, V:32/little>>;
               {fixed64, FNum, V} ->
                   BinF = e_varint(FNum bsl 3 bor 1, Bin),
                   <<BinF/binary, V:64/little>>
           end,
    e_unknown_elems(Rest, BinR);
e_unknown_elems([], Bin) -> Bin.

-compile({nowarn_unused_function,e_varint/3}).
e_varint(N, Bin, _TrUserData) -> e_varint(N, Bin).

-compile({nowarn_unused_function,e_varint/2}).
e_varint(N, Bin) when N =< 127 -> <<Bin/binary, N>>;
e_varint(N, Bin) ->
    Bin2 = <<Bin/binary, (N band 127 bor 128)>>,
    e_varint(N bsr 7, Bin2).


decode_msg(Bin, MsgName) when is_binary(Bin) -> decode_msg(Bin, MsgName, []).

decode_msg(Bin, MsgName, Opts) when is_binary(Bin) ->
    TrUserData = proplists:get_value(user_data, Opts),
    decode_msg_1_catch(Bin, MsgName, TrUserData).

-ifdef('OTP_RELEASE').
decode_msg_1_catch(Bin, MsgName, TrUserData) ->
    try decode_msg_2_doit(MsgName, Bin, TrUserData)
    catch
        error:{gpb_error,_}=Reason:StackTrace ->
            erlang:raise(error, Reason, StackTrace);
        Class:Reason:StackTrace -> error({gpb_error,{decoding_failure, {Bin, MsgName, {Class, Reason, StackTrace}}}})
    end.
-else.
decode_msg_1_catch(Bin, MsgName, TrUserData) ->
    try decode_msg_2_doit(MsgName, Bin, TrUserData)
    catch
        error:{gpb_error,_}=Reason ->
            erlang:raise(error, Reason,
                         erlang:get_stacktrace());
        Class:Reason ->
            StackTrace = erlang:get_stacktrace(),
            error({gpb_error,{decoding_failure, {Bin, MsgName, {Class, Reason, StackTrace}}}})
    end.
-endif.

decode_msg_2_doit(health_check_request, Bin, TrUserData) -> id(decode_msg_health_check_request(Bin, TrUserData), TrUserData);
decode_msg_2_doit(health_check_response, Bin, TrUserData) -> id(decode_msg_health_check_response(Bin, TrUserData), TrUserData).



decode_msg_health_check_request(Bin, TrUserData) -> dfp_read_field_def_health_check_request(Bin, 0, 0, 0, TrUserData).

dfp_read_field_def_health_check_request(<<>>, 0, 0, _, _) -> #{};
dfp_read_field_def_health_check_request(Other, Z1, Z2, F, TrUserData) -> dg_read_field_def_health_check_request(Other, Z1, Z2, F, TrUserData).

dg_read_field_def_health_check_request(<<1:1, X:7, Rest/binary>>, N, Acc, F, TrUserData) when N < 32 - 7 -> dg_read_field_def_health_check_request(Rest, N + 7, X bsl N + Acc, F, TrUserData);
dg_read_field_def_health_check_request(<<0:1, X:7, Rest/binary>>, N, Acc, _, TrUserData) ->
    Key = X bsl N + Acc,
    case Key band 7 of
        0 -> skip_varint_health_check_request(Rest, 0, 0, Key bsr 3, TrUserData);
        1 -> skip_64_health_check_request(Rest, 0, 0, Key bsr 3, TrUserData);
        2 -> skip_length_delimited_health_check_request(Rest, 0, 0, Key bsr 3, TrUserData);
        3 -> skip_group_health_check_request(Rest, 0, 0, Key bsr 3, TrUserData);
        5 -> skip_32_health_check_request(Rest, 0, 0, Key bsr 3, TrUserData)
    end;
dg_read_field_def_health_check_request(<<>>, 0, 0, _, _) -> #{}.

skip_varint_health_check_request(<<1:1, _:7, Rest/binary>>, Z1, Z2, F, TrUserData) -> skip_varint_health_check_request(Rest, Z1, Z2, F, TrUserData);
skip_varint_health_check_request(<<0:1, _:7, Rest/binary>>, Z1, Z2, F, TrUserData) -> dfp_read_field_def_health_check_request(Rest, Z1, Z2, F, TrUserData).

skip_length_delimited_health_check_request(<<1:1, X:7, Rest/binary>>, N, Acc, F, TrUserData) when N < 57 -> skip_length_delimited_health_check_request(Rest, N + 7, X bsl N + Acc, F, TrUserData);
skip_length_delimited_health_check_request(<<0:1, X:7, Rest/binary>>, N, Acc, F, TrUserData) ->
    Length = X bsl N + Acc,
    <<_:Length/binary, Rest2/binary>> = Rest,
    dfp_read_field_def_health_check_request(Rest2, 0, 0, F, TrUserData).

skip_group_health_check_request(Bin, _, Z2, FNum, TrUserData) ->
    {_, Rest} = read_group(Bin, FNum),
    dfp_read_field_def_health_check_request(Rest, 0, Z2, FNum, TrUserData).

skip_32_health_check_request(<<_:32, Rest/binary>>, Z1, Z2, F, TrUserData) -> dfp_read_field_def_health_check_request(Rest, Z1, Z2, F, TrUserData).

skip_64_health_check_request(<<_:64, Rest/binary>>, Z1, Z2, F, TrUserData) -> dfp_read_field_def_health_check_request(Rest, Z1, Z2, F, TrUserData).

decode_msg_health_check_response(Bin, TrUserData) -> dfp_read_field_def_health_check_response(Bin, 0, 0, 0, TrUserData).

dfp_read_field_def_health_check_response(<<>>, 0, 0, _, _) -> #{};
dfp_read_field_def_health_check_response(Other, Z1, Z2, F, TrUserData) -> dg_read_field_def_health_check_response(Other, Z1, Z2, F, TrUserData).

dg_read_field_def_health_check_response(<<1:1, X:7, Rest/binary>>, N, Acc, F, TrUserData) when N < 32 - 7 -> dg_read_field_def_health_check_response(Rest, N + 7, X bsl N + Acc, F, TrUserData);
dg_read_field_def_health_check_response(<<0:1, X:7, Rest/binary>>, N, Acc, _, TrUserData) ->
    Key = X bsl N + Acc,
    case Key band 7 of
        0 -> skip_varint_health_check_response(Rest, 0, 0, Key bsr 3, TrUserData);
        1 -> skip_64_health_check_response(Rest, 0, 0, Key bsr 3, TrUserData);
        2 -> skip_length_delimited_health_check_response(Rest, 0, 0, Key bsr 3, TrUserData);
        3 -> skip_group_health_check_response(Rest, 0, 0, Key bsr 3, TrUserData);
        5 -> skip_32_health_check_response(Rest, 0, 0, Key bsr 3, TrUserData)
    end;
dg_read_field_def_health_check_response(<<>>, 0, 0, _, _) -> #{}.

skip_varint_health_check_response(<<1:1, _:7, Rest/binary>>, Z1, Z2, F, TrUserData) -> skip_varint_health_check_response(Rest, Z1, Z2, F, TrUserData);
skip_varint_health_check_response(<<0:1, _:7, Rest/binary>>, Z1, Z2, F, TrUserData) -> dfp_read_field_def_health_check_response(Rest, Z1, Z2, F, TrUserData).

skip_length_delimited_health_check_response(<<1:1, X:7, Rest/binary>>, N, Acc, F, TrUserData) when N < 57 -> skip_length_delimited_health_check_response(Rest, N + 7, X bsl N + Acc, F, TrUserData);
skip_length_delimited_health_check_response(<<0:1, X:7, Rest/binary>>, N, Acc, F, TrUserData) ->
    Length = X bsl N + Acc,
    <<_:Length/binary, Rest2/binary>> = Rest,
    dfp_read_field_def_health_check_response(Rest2, 0, 0, F, TrUserData).

skip_group_health_check_response(Bin, _, Z2, FNum, TrUserData) ->
    {_, Rest} = read_group(Bin, FNum),
    dfp_read_field_def_health_check_response(Rest, 0, Z2, FNum, TrUserData).

skip_32_health_check_response(<<_:32, Rest/binary>>, Z1, Z2, F, TrUserData) -> dfp_read_field_def_health_check_response(Rest, Z1, Z2, F, TrUserData).

skip_64_health_check_response(<<_:64, Rest/binary>>, Z1, Z2, F, TrUserData) -> dfp_read_field_def_health_check_response(Rest, Z1, Z2, F, TrUserData).

read_group(Bin, FieldNum) ->
    {NumBytes, EndTagLen} = read_gr_b(Bin, 0, 0, 0, 0, FieldNum),
    <<Group:NumBytes/binary, _:EndTagLen/binary, Rest/binary>> = Bin,
    {Group, Rest}.

%% Like skipping over fields, but record the total length,
%% Each field is <(FieldNum bsl 3) bor FieldType> ++ <FieldValue>
%% Record the length because varints may be non-optimally encoded.
%%
%% Groups can be nested, but assume the same FieldNum cannot be nested
%% because group field numbers are shared with the rest of the fields
%% numbers. Thus we can search just for an group-end with the same
%% field number.
%%
%% (The only time the same group field number could occur would
%% be in a nested sub message, but then it would be inside a
%% length-delimited entry, which we skip-read by length.)
read_gr_b(<<1:1, X:7, Tl/binary>>, N, Acc, NumBytes, TagLen, FieldNum)
  when N < (32-7) ->
    read_gr_b(Tl, N+7, X bsl N + Acc, NumBytes, TagLen+1, FieldNum);
read_gr_b(<<0:1, X:7, Tl/binary>>, N, Acc, NumBytes, TagLen,
          FieldNum) ->
    Key = X bsl N + Acc,
    TagLen1 = TagLen + 1,
    case {Key bsr 3, Key band 7} of
        {FieldNum, 4} -> % 4 = group_end
            {NumBytes, TagLen1};
        {_, 0} -> % 0 = varint
            read_gr_vi(Tl, 0, NumBytes + TagLen1, FieldNum);
        {_, 1} -> % 1 = bits64
            <<_:64, Tl2/binary>> = Tl,
            read_gr_b(Tl2, 0, 0, NumBytes + TagLen1 + 8, 0, FieldNum);
        {_, 2} -> % 2 = length_delimited
            read_gr_ld(Tl, 0, 0, NumBytes + TagLen1, FieldNum);
        {_, 3} -> % 3 = group_start
            read_gr_b(Tl, 0, 0, NumBytes + TagLen1, 0, FieldNum);
        {_, 4} -> % 4 = group_end
            read_gr_b(Tl, 0, 0, NumBytes + TagLen1, 0, FieldNum);
        {_, 5} -> % 5 = bits32
            <<_:32, Tl2/binary>> = Tl,
            read_gr_b(Tl2, 0, 0, NumBytes + TagLen1 + 4, 0, FieldNum)
    end.

read_gr_vi(<<1:1, _:7, Tl/binary>>, N, NumBytes, FieldNum)
  when N < (64-7) ->
    read_gr_vi(Tl, N+7, NumBytes+1, FieldNum);
read_gr_vi(<<0:1, _:7, Tl/binary>>, _, NumBytes, FieldNum) ->
    read_gr_b(Tl, 0, 0, NumBytes+1, 0, FieldNum).

read_gr_ld(<<1:1, X:7, Tl/binary>>, N, Acc, NumBytes, FieldNum)
  when N < (64-7) ->
    read_gr_ld(Tl, N+7, X bsl N + Acc, NumBytes+1, FieldNum);
read_gr_ld(<<0:1, X:7, Tl/binary>>, N, Acc, NumBytes, FieldNum) ->
    Len = X bsl N + Acc,
    NumBytes1 = NumBytes + 1,
    <<_:Len/binary, Tl2/binary>> = Tl,
    read_gr_b(Tl2, 0, 0, NumBytes1 + Len, 0, FieldNum).

merge_msgs(Prev, New, MsgName) when is_atom(MsgName) -> merge_msgs(Prev, New, MsgName, []).

merge_msgs(Prev, New, MsgName, Opts) ->
    TrUserData = proplists:get_value(user_data, Opts),
    case MsgName of
        health_check_request -> merge_msg_health_check_request(Prev, New, TrUserData);
        health_check_response -> merge_msg_health_check_response(Prev, New, TrUserData)
    end.

-compile({nowarn_unused_function,merge_msg_health_check_request/3}).
merge_msg_health_check_request(_Prev, New, _TrUserData) -> New.

-compile({nowarn_unused_function,merge_msg_health_check_response/3}).
merge_msg_health_check_response(_Prev, New, _TrUserData) -> New.


verify_msg(Msg, MsgName) when is_atom(MsgName) -> verify_msg(Msg, MsgName, []).

verify_msg(Msg, MsgName, Opts) ->
    TrUserData = proplists:get_value(user_data, Opts),
    case MsgName of
        health_check_request -> v_msg_health_check_request(Msg, [MsgName], TrUserData);
        health_check_response -> v_msg_health_check_response(Msg, [MsgName], TrUserData);
        _ -> mk_type_error(not_a_known_message, Msg, [])
    end.


-compile({nowarn_unused_function,v_msg_health_check_request/3}).
-dialyzer({nowarn_function,v_msg_health_check_request/3}).
v_msg_health_check_request(#{} = M, Path, _) ->
    lists:foreach(fun (OtherKey) -> mk_type_error({extraneous_key, OtherKey}, M, Path) end, maps:keys(M)),
    ok;
v_msg_health_check_request(M, Path, _TrUserData) when is_map(M) -> mk_type_error({missing_fields, [] -- maps:keys(M), health_check_request}, M, Path);
v_msg_health_check_request(X, Path, _TrUserData) -> mk_type_error({expected_msg, health_check_request}, X, Path).

-compile({nowarn_unused_function,v_msg_health_check_response/3}).
-dialyzer({nowarn_function,v_msg_health_check_response/3}).
v_msg_health_check_response(#{} = M, Path, _) ->
    lists:foreach(fun (OtherKey) -> mk_type_error({extraneous_key, OtherKey}, M, Path) end, maps:keys(M)),
    ok;
v_msg_health_check_response(M, Path, _TrUserData) when is_map(M) -> mk_type_error({missing_fields, [] -- maps:keys(M), health_check_response}, M, Path);
v_msg_health_check_response(X, Path, _TrUserData) -> mk_type_error({expected_msg, health_check_response}, X, Path).

-compile({nowarn_unused_function,mk_type_error/3}).
-spec mk_type_error(_, _, list()) -> no_return().
mk_type_error(Error, ValueSeen, Path) ->
    Path2 = prettify_path(Path),
    erlang:error({gpb_type_error, {Error, [{value, ValueSeen}, {path, Path2}]}}).


-compile({nowarn_unused_function,prettify_path/1}).
-dialyzer({nowarn_function,prettify_path/1}).
prettify_path([]) -> top_level;
prettify_path(PathR) -> lists:append(lists:join(".", lists:map(fun atom_to_list/1, lists:reverse(PathR)))).


-compile({nowarn_unused_function,id/2}).
-compile({inline,id/2}).
id(X, _TrUserData) -> X.

-compile({nowarn_unused_function,v_ok/3}).
-compile({inline,v_ok/3}).
v_ok(_Value, _Path, _TrUserData) -> ok.

-compile({nowarn_unused_function,m_overwrite/3}).
-compile({inline,m_overwrite/3}).
m_overwrite(_Prev, New, _TrUserData) -> New.

-compile({nowarn_unused_function,cons/3}).
-compile({inline,cons/3}).
cons(Elem, Acc, _TrUserData) -> [Elem | Acc].

-compile({nowarn_unused_function,lists_reverse/2}).
-compile({inline,lists_reverse/2}).
'lists_reverse'(L, _TrUserData) -> lists:reverse(L).
-compile({nowarn_unused_function,'erlang_++'/3}).
-compile({inline,'erlang_++'/3}).
'erlang_++'(A, B, _TrUserData) -> A ++ B.


get_msg_defs() -> [{{msg, health_check_request}, []}, {{msg, health_check_response}, []}].


get_msg_names() -> [health_check_request, health_check_response].


get_group_names() -> [].


get_msg_or_group_names() -> [health_check_request, health_check_response].


get_enum_names() -> [].


fetch_msg_def(MsgName) ->
    case find_msg_def(MsgName) of
        Fs when is_list(Fs) -> Fs;
        error -> erlang:error({no_such_msg, MsgName})
    end.


-spec fetch_enum_def(_) -> no_return().
fetch_enum_def(EnumName) -> erlang:error({no_such_enum, EnumName}).


find_msg_def(health_check_request) -> [];
find_msg_def(health_check_response) -> [];
find_msg_def(_) -> error.


find_enum_def(_) -> error.


-spec enum_symbol_by_value(_, _) -> no_return().
enum_symbol_by_value(E, V) -> erlang:error({no_enum_defs, E, V}).


-spec enum_value_by_symbol(_, _) -> no_return().
enum_value_by_symbol(E, V) -> erlang:error({no_enum_defs, E, V}).



get_service_names() -> ['greptime.v1.HealthCheck'].


get_service_def('greptime.v1.HealthCheck') -> {{service, 'greptime.v1.HealthCheck'}, [#{name => 'HealthCheck', input => health_check_request, output => health_check_response, input_stream => false, output_stream => false, opts => []}]};
get_service_def(_) -> error.


get_rpc_names('greptime.v1.HealthCheck') -> ['HealthCheck'];
get_rpc_names(_) -> error.


find_rpc_def('greptime.v1.HealthCheck', RpcName) -> 'find_rpc_def_greptime.v1.HealthCheck'(RpcName);
find_rpc_def(_, _) -> error.


'find_rpc_def_greptime.v1.HealthCheck'('HealthCheck') -> #{name => 'HealthCheck', input => health_check_request, output => health_check_response, input_stream => false, output_stream => false, opts => []};
'find_rpc_def_greptime.v1.HealthCheck'(_) -> error.


fetch_rpc_def(ServiceName, RpcName) ->
    case find_rpc_def(ServiceName, RpcName) of
        Def when is_map(Def) -> Def;
        error -> erlang:error({no_such_rpc, ServiceName, RpcName})
    end.


%% Convert a a fully qualified (ie with package name) service name
%% as a binary to a service name as an atom.
fqbin_to_service_name(<<"greptime.v1.HealthCheck">>) -> 'greptime.v1.HealthCheck';
fqbin_to_service_name(X) -> error({gpb_error, {badservice, X}}).


%% Convert a service name as an atom to a fully qualified
%% (ie with package name) name as a binary.
service_name_to_fqbin('greptime.v1.HealthCheck') -> <<"greptime.v1.HealthCheck">>;
service_name_to_fqbin(X) -> error({gpb_error, {badservice, X}}).


%% Convert a a fully qualified (ie with package name) service name
%% and an rpc name, both as binaries to a service name and an rpc
%% name, as atoms.
fqbins_to_service_and_rpc_name(<<"greptime.v1.HealthCheck">>, <<"HealthCheck">>) -> {'greptime.v1.HealthCheck', 'HealthCheck'};
fqbins_to_service_and_rpc_name(S, R) -> error({gpb_error, {badservice_or_rpc, {S, R}}}).


%% Convert a service name and an rpc name, both as atoms,
%% to a fully qualified (ie with package name) service name and
%% an rpc name as binaries.
service_and_rpc_name_to_fqbins('greptime.v1.HealthCheck', 'HealthCheck') -> {<<"greptime.v1.HealthCheck">>, <<"HealthCheck">>};
service_and_rpc_name_to_fqbins(S, R) -> error({gpb_error, {badservice_or_rpc, {S, R}}}).


fqbin_to_msg_name(<<"greptime.v1.HealthCheckRequest">>) -> health_check_request;
fqbin_to_msg_name(<<"greptime.v1.HealthCheckResponse">>) -> health_check_response;
fqbin_to_msg_name(E) -> error({gpb_error, {badmsg, E}}).


msg_name_to_fqbin(health_check_request) -> <<"greptime.v1.HealthCheckRequest">>;
msg_name_to_fqbin(health_check_response) -> <<"greptime.v1.HealthCheckResponse">>;
msg_name_to_fqbin(E) -> error({gpb_error, {badmsg, E}}).


-spec fqbin_to_enum_name(_) -> no_return().
fqbin_to_enum_name(E) -> error({gpb_error, {badenum, E}}).


-spec enum_name_to_fqbin(_) -> no_return().
enum_name_to_fqbin(E) -> error({gpb_error, {badenum, E}}).


get_package_name() -> 'greptime.v1'.


%% Whether or not the message names
%% are prepended with package name or not.
uses_packages() -> true.


source_basename() -> "health.proto".


%% Retrieve all proto file names, also imported ones.
%% The order is top-down. The first element is always the main
%% source file. The files are returned with extension,
%% see get_all_proto_names/0 for a version that returns
%% the basenames sans extension
get_all_source_basenames() -> ["health.proto"].


%% Retrieve all proto file names, also imported ones.
%% The order is top-down. The first element is always the main
%% source file. The files are returned sans .proto extension,
%% to make it easier to use them with the various get_xyz_containment
%% functions.
get_all_proto_names() -> ["health"].


get_msg_containment("health") -> [health_check_request, health_check_response];
get_msg_containment(P) -> error({gpb_error, {badproto, P}}).


get_pkg_containment("health") -> 'greptime.v1';
get_pkg_containment(P) -> error({gpb_error, {badproto, P}}).


get_service_containment("health") -> ['greptime.v1.HealthCheck'];
get_service_containment(P) -> error({gpb_error, {badproto, P}}).


get_rpc_containment("health") -> [{'greptime.v1.HealthCheck', 'HealthCheck'}];
get_rpc_containment(P) -> error({gpb_error, {badproto, P}}).


get_enum_containment("health") -> [];
get_enum_containment(P) -> error({gpb_error, {badproto, P}}).


get_proto_by_msg_name_as_fqbin(<<"greptime.v1.HealthCheckRequest">>) -> "health";
get_proto_by_msg_name_as_fqbin(<<"greptime.v1.HealthCheckResponse">>) -> "health";
get_proto_by_msg_name_as_fqbin(E) -> error({gpb_error, {badmsg, E}}).


get_proto_by_service_name_as_fqbin(<<"greptime.v1.HealthCheck">>) -> "health";
get_proto_by_service_name_as_fqbin(E) -> error({gpb_error, {badservice, E}}).


-spec get_proto_by_enum_name_as_fqbin(_) -> no_return().
get_proto_by_enum_name_as_fqbin(E) -> error({gpb_error, {badenum, E}}).


get_protos_by_pkg_name_as_fqbin(<<"greptime.v1">>) -> ["health"];
get_protos_by_pkg_name_as_fqbin(E) -> error({gpb_error, {badpkg, E}}).



gpb_version_as_string() ->
    "4.20.0".

gpb_version_as_list() ->
    [4,20,0].

gpb_version_source() ->
    "file".
