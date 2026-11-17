#!/usr/bin/env bash
# #2942 against the chain: at B random blocks, /sql with at_block gives the same totalSupply and the
# same balanceOf for K addresses seen by then as eth_call at that block. EURC amounts fit in 63 bits.
set -euo pipefail
R=$(cat ~/eurc-nest/.rpc)
API=http://127.0.0.1:8470
A=0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c
B=${1:-50}
K=${2:-10}
T=fiat_token_v2_2__transfer
Z=0x0000000000000000000000000000000000000000
C=$(mktemp); trap 'rm -f "$C"' EXIT

call() { # data, block -> decimal
  echo >> "$C"
  local h
  h=$(curl -s -m 60 "$R" -H 'content-type: application/json' -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_call\",\"params\":[{\"to\":\"$A\",\"data\":\"$1\"},\"$(printf 0x%x "$2")\"]}" | jq -r .result)
  echo $((16#${h#0x}))
}
sql() { # statement, block -> first row
  curl -s -G "$API/sql" --data-urlencode "q=$1" --data-urlencode "at_block=$2" | jq -c '.rows[0] // .error'
}
sum_where() { echo "(SELECT coalesce(sum(CAST(value AS HUGEINT)), 0) FROM $T WHERE $1)"; }

first=14807233
sealed=$(curl -s "$API/ready" | jq '.sealed_through // empty')
last=${sealed:-$(curl -s "$API/sql?q=SELECT%20max(block_number)%20AS%20b%20FROM%20$T" | jq .rows[0].b)}
bad=0 checked=0
for i in $(seq 1 "$B"); do
  n=$((first + (RANDOM * 32768 + RANDOM) % (last - first)))
  want=$(sql "SELECT CAST($(sum_where "\"from\" = '$Z'") - $(sum_where "\"to\" = '$Z'") AS VARCHAR) AS s" "$n" | jq -r .s)
  got=$(call 0x18160ddd "$n")
  checked=$((checked + 1))
  [ "$i" = 1 ] && echo "sample: supply at $n nest=$want chain=$got"
  [ "$want" = "$got" ] || { bad=$((bad + 1)); echo "SUPPLY block=$n nest=$want chain=$got"; }
  seen=$(sql "SELECT count(*) AS c FROM $T" "$n" | jq .c)
  [ "$seen" -gt 0 ] || continue
  for j in $(seq 1 "$K"); do
    off=$(((RANDOM * 32768 + RANDOM) % seen))
    who=$(curl -s -G "$API/sql" --data-urlencode "q=SELECT \"to\" AS a FROM $T ORDER BY _seq LIMIT 1 OFFSET $off" --data-urlencode "at_block=$n" | jq -r .rows[0].a)
    [ "$who" = "$Z" ] && continue
    want=$(sql "SELECT CAST($(sum_where "\"to\" = '$who'") - $(sum_where "\"from\" = '$who'") AS VARCHAR) AS b" "$n" | jq -r .b)
    got=$(call "0x70a08231000000000000000000000000${who#0x}" "$n")
    checked=$((checked + 1))
    [ "$want" = "$got" ] || { bad=$((bad + 1)); echo "BALANCE block=$n who=$who nest=$want chain=$got"; }
  done
done
echo "blocks=$B checked=$checked bad=$bad rpc_calls=$(wc -l < "$C" | tr -d " ")"
