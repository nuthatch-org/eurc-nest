#!/usr/bin/env bash
# #2941 against the chain: for N random times, /at's two blocks carry the timestamps it claims and
# bracket the time, and no EURC log lies strictly between them, so the state at the time is the state
# at `block`.
set -euo pipefail
R=$(cat ~/eurc-nest/.rpc)
API=http://127.0.0.1:8470
A=0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c
N=${1:-100}
C=$(mktemp); trap 'rm -f "$C"' EXIT

rpc() {
  echo >> "$C"
  curl -s -m 60 "$R" -H 'content-type: application/json' -d "$1"
}
ts() {
  local h
  h=$(rpc "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBlockByNumber\",\"params\":[\"$(printf 0x%x "$1")\",false]}" | jq -r .result.timestamp)
  echo $((h))
}
# Logs at the address strictly inside (a, b), in the RPC's 10,000-block ranges.
between() {
  local from=$(($1 + 1)) to=$(($2 - 1)) n=0 end
  while [ "$from" -le "$to" ]; do
    end=$((from + 9999 < to ? from + 9999 : to))
    n=$((n + $(rpc "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getLogs\",\"params\":[{\"address\":\"$A\",\"fromBlock\":\"$(printf 0x%x "$from")\",\"toBlock\":\"$(printf 0x%x "$end")\"}]}" | jq '[.result[] | select(.topics[0] != "0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b" and .topics[0] != "0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f")] | length')))
    from=$((end + 1))
  done
  echo "$n"
}

lo=$(ts 14807233)
hi=$(curl -s "$API/sql?q=SELECT%20max(block_timestamp)%20AS%20t%20FROM%20fiat_token_v2_2__transfer" | jq .rows[0].t)
bad=0 exact=0 final=0 refused=0
for i in $(seq 1 "$N"); do
  t=$((lo + (RANDOM * 32768 + RANDOM) % (hi - lo)))
  j=$(curl -s "$API/at?time=$t")
  b=$(echo "$j" | jq .block)
  if [ "$b" = "null" ]; then
    refused=$((refused + 1))
    echo "refused at $t: $(echo "$j" | jq -r .error)"
    continue
  fi
  nb=$(echo "$j" | jq .next_block)
  bt=$(echo "$j" | jq .block_timestamp)
  nbt=$(echo "$j" | jq .next_block_timestamp)
  [ "$(echo "$j" | jq .exact)" = true ] && exact=$((exact + 1))
  [ "$(echo "$j" | jq .final)" = true ] && final=$((final + 1))
  cbt=$(ts "$b")
  cnbt=$(ts "$nb")
  inside=$(between "$b" "$nb")
  [ "$i" = 1 ] && echo "sample: t=$t block=$b ($bt, chain $cbt) next=$nb ($nbt, chain $cnbt) logs between=$inside"
  if [ "$cbt" != "$bt" ] || [ "$cnbt" != "$nbt" ] || [ "$bt" -gt "$t" ] || [ "$nbt" -le "$t" ] || [ "$inside" != 0 ]; then
    bad=$((bad + 1))
    echo "MISMATCH t=$t block=$b ($bt, chain $cbt) next=$nb ($nbt, chain $cnbt) logs between=$inside"
  fi
done
echo "times=$N bad=$bad exact=$exact final=$final refused=$refused rpc_calls=$(wc -l < "$C" | tr -d " ")"
