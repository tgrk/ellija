%%%----------------------------------------------------------------------------
%%% @author Martin Wiso <martin@wiso.cz>
%%% @doc
%%% Helper for handling API responses
%%% @end
%%%----------------------------------------------------------------------------
-module(ellija_resp).

-include("ellija.hrl").
-include_lib("elli/include/elli.hrl").

%% API exports
-export([ options/1

        , ok/1
        , created/0
        , no_content/0
        , bad_request/0
        , bad_request/1
        , unauthorized/1
        , forbidden/0
        , not_found/0
        , conflict/0
        , internal_error/0

        , ok/2
        , created/1
        , no_content/1
        , bad_request/2
        , unauthorized/2
        , forbidden/1
        , not_found/1
        , conflict/1
        , internal_error/1

        , raw/3

        , to_json/1
        , is_json/1
        , has_header/3
        , header/1
        , header/2
        ]).

-define(JSON_CONTENT_TYPES, [
    <<"application/vnd.api+json">>
  , <<"application/json">>
  , <<"text/json">>
]).

%%====================================================================
%% API functions
%%====================================================================

-spec ok(tuple()) -> tuple().
ok(Response) ->
  ok([], Response).

-spec created() -> tuple().
created() ->
  created([]).

-spec no_content() -> tuple().
no_content() ->
  no_content([]).

-spec forbidden() -> tuple().
forbidden() ->
  forbidden([]).

-spec not_found() -> tuple().
not_found() ->
  not_found([]).

-spec conflict() -> tuple().
conflict() ->
  conflict([]).

-spec internal_error() -> tuple().
internal_error() ->
  internal_error().

-spec bad_request(map() | list()) -> tuple().
bad_request(Headers) when is_list(Headers) ->
  raw(400, Headers, <<"Bad uest">>);
bad_request(ErrorObject) when is_map(ErrorObject) ->
  bad_request([], ErrorObject).

-spec unauthorized(list() | map()) -> tuple().
unauthorized(Headers) when is_list(Headers) ->
  raw(401, Headers, <<"Unauthorized">>);
unauthorized(ErrorObject) when is_map(ErrorObject) ->
  unauthorized([], ErrorObject).

-spec bad_request() -> tuple().
bad_request() ->
  bad_request([]).

-spec ok(list(), tuple() | [map()]| map()) -> tuple().
ok(Headers, {ok, Response}) ->
  %TODO: location
  raw(200, Headers, Response);
ok(Headers, Response) ->
  %TODO: location
  raw(200, Headers, Response).

-spec created(list()) -> tuple().
created(Headers) ->
  %TODO: location
  raw(201, Headers, <<>>).

-spec no_content(list()) -> tuple().
no_content(Headers) ->
  raw(204, Headers, <<>>).

-spec bad_request(list(), map()) -> tuple().
bad_request(Headers, ErrorObject) ->
  raw(400, Headers, to_json(ErrorObject)).

-spec unauthorized(list(), map()) -> tuple().
unauthorized(Headers, ErrorObject) ->
  raw(401, Headers, to_json(ErrorObject)).

-spec forbidden(list()) -> tuple().
forbidden(Headers) ->
  raw(403, Headers, <<"Forbidden">>).

-spec not_found(list()) -> tuple().
not_found(Headers) ->
  raw(404, Headers, <<"Not Found">>).

-spec conflict(list()) -> tuple().
conflict(Headers) ->
  %TODO: location
  raw(409, Headers, <<"Conflict">>).

-spec internal_error(list()) -> tuple().
internal_error(Headers) ->
  raw(500, Headers, <<"Internal Server Error">>).

-spec options() -> tuple().
options() ->
  options(ellija_config:get(allowed_methods)).

-spec options(list()) -> tuple().
options(AllowedMethods) ->
  Headers =
    [ header(allow_origin)
     , {<<"Access-Control-Allow-Methods">>, format_methods(AllowedMethods)}
      , {<<"Access-Control-Allow-Headers">>, <<"Authorization, X-uested-With, Accept, Origin, "
            "Content-Type, Content-Encoding">>}
      , {<<"Access-Control-Allow-Credentials">>,
        <<"X-PINGOTHER">>}
    ],
  raw(200, Headers, <<>>).

-spec raw(pos_integer(), list(), map() | binary()) -> tuple().
raw(Code, [], Body) ->
  raw(Code, ellija_config:get(headers), Body);
raw(Code, Headers, Body) ->
  case is_json(Headers) of
    true ->
      {Code, Headers, to_json(Body)};
    false ->
      {Code, Headers, Body}
  end.

-spec to_json(any()) -> binary().
to_json([]) -> <<"[]">>;
to_json(<<>>) -> <<>>;
to_json(Struct) ->
  jiffy:encode(Struct).

-spec is_json(list()) -> boolean().
is_json(Headers1) ->
  Headers = normalize_headers(Headers1, []),
  case proplists:get_value(<<"content-type">>, Headers) of
    undefined ->
      false;
    Value ->
      lists:member(
        parse_significant_content_type(Value),
        ?JSON_CONTENT_TYPES
      )
  end.

-spec has_header(list(), binary(), binary()) -> boolean().
has_header(Headers1, Key, Value) ->
  Headers = normalize_headers(Headers1, []),
  case proplists:get_value(Key, Headers, <<>>) of
    <<>> ->
      false;
    HeaderValue ->
      case binary:match(HeaderValue, [Value]) of
        nomatch -> false;
        _Match  -> true
      end
  end.

-spec header(atom()) -> tuple().
header(allow_origin) ->
  header(allow_origin, <<"*">>);
header(content_type_jsonapi) ->
  header(content_type, <<"application/vnd.api+json; charset=utf-8">>).

-spec header(atom(), binary() | any()) -> tuple().
header(allow_credentials, Value) ->
  {<<"Access-Control-Allow-Credentials">>, ellija_utils:to_bin(Value)};
header(content_type, Value) ->
  {<<"Content-Type">>, ellija_utils:to_bin(Value)};
header(location, Uri) ->
  {<<"Location">>, Uri};
header(allow_origin, Value) ->
  {<<"Access-Control-Allow-Origin">>, ellija_utils:to_bin(Value)}.

%%====================================================================
%% Internal functions
%%====================================================================

format_methods(Methods) ->
  string:join([ellija_utils:to_list(M) || M <- Methods], ", ").

normalize_headers([], Acc) -> Acc;
normalize_headers([{K, V} | T], Acc) ->
  normalize_headers(T, [{string:lowercase(K), V} | Acc]).

parse_significant_content_type(Value) ->
  hd(string:split(Value, ";")).