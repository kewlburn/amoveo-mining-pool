-module(mining_pool_server).
-behaviour(gen_server).
-export([start_link/0,code_change/3,handle_call/3,handle_cast/2,handle_info/2,init/1,terminate/2,
        start_cron/0, problem/0, receive_work/2]).
-define(FullNode, "http://localhost:8081/").
-record(data, {hash, nonce, diff, time})
-define(RefreshPeriod, 20).%in seonds. How often we get a new problem from the node to work on.
init(ok) -> {ok, new_problem_internal()}.
start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).
code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_, _) -> io:format("died!"), ok.
handle_info(_, X) -> {noreply, X}.
handle_cast(new_problem_cron, Y) -> 
    N = time_now()
    T = Y#data.time,
    X = if 
            (N-T) > ?RefreshPeriod -> 
                new_problem_internal();
            true ->
                Y
        end,
    {noreply, X};
handle_cast(_, X) -> {noreply, X}.
handle_call(problem, _From, X) -> {reply, X, X};
handle_call(new_problem, _From, Y) -> 
    X = new_problem_internal(),
    {reply, X, X};
handle_call(_, _From, X) -> {reply, X, X}.
time_now() ->
    element(2, now()).
new_problem_internal() ->
    Data = {mining_data},
    R = talk_helper(Data, ?FullNode, 10),
    
    {F, S, Third} = unpack_mining_data(R),
    #data{hash = F, nonce = S, diff = Third, time = time_now()}.
problem() -> gen_server:call(?MODULE, problem).
new_problem() -> gen_server:call(?MODULE, new_problem).
start_cron() ->
    %This checks every 0.1 seconds, to see if it is time to get a new problem.
    %We get a new problem every ?RefreshPeriod.
    gen_server:cast(?MODULE, new_problem_cron),
    timer:sleep(100),
    start_cron().
receive_work(Nonce, Pubkey) ->
    D = problem(),
    H = D#data.hash,
    Nonce = D#data.nonce,
    Diff = D#data.diff.
    Y = <<Hash/binary, Diff:16, Nonce:256>>,
    I = pow:hash2integer(hash:doit(Y)),
    %if the work is good enough, give some money to pubkey.
    if 
        I > Diff -> found_block(<<Nonce:256>>),
                    Msg = {spend, Pubkey, 300000000},
                    talk_helper(Msg, ?FullNode, 10),
                    "found work";
        true -> "invalid work"
    end.
request_new_problem() ->
found_block(<<Nonce:256>>) ->
    BinNonce = base64:encode(<<Nonce:256>>),
    Data = {mining_data, <<Nonce:256>>},
    talk_helper(Data, ?FullNode, 40),%spend 8 seconds checking 5 times per second if we can start mining again.
    new_problem(),
    ok.
    
talk_helper2(Data, Peer) ->
    httpc:request(post, {Peer, [], "application/octet-stream", iolist_to_binary(packer:pack(Data))}, [{timeout, 3000}], []).
talk_helper(Data, Peer, N) ->
    if 
        N == 0 -> 
            io:fwrite("cannot connect to server"),
            1=2;
        true -> 
            case talk_helper2(Data, Peer) of
                {ok, {_Status, _Headers, []}} ->
                    timer:sleep(200),
                    talk_helper(Data, Peer, N - 1);
                {ok, {_, _, R}} -> R;
                _ -> io:fwrite("\nYou need to turn on and sync your Amoveo node before you can mine. You can get it here: https://github.com/zack-bitcoin/amoveo \n"),
                     1=2
            end
    end.
unpack_mining_data([Hash, Nonce, Difficulty]) ->
    {Hash, Nonce, Difficulty}.
