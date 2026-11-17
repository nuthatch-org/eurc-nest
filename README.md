# EURC on your own box

A [nuthatch](https://github.com/nuthatch-org/nuthatch) nest over Circle's EURC on Ethereum
(`0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c`), from its deployment at block 14,807,233. Every
transfer, mint, burn and freeze is a SQL table on your machine, and supply, holders and the MiCA
Art 22 figures are views over them. Any figure can be bundled with the identity of the data it was
read from, and someone else can re-execute it to the same bytes from the public mirror.

**What it is not.** Not KYT, not sanctions screening, and no third-party risk data: nothing here
leaves your machine or comes from anyone but the chain. It is a deterministic annotation layer, not
legal or regulatory advice. Which addresses belong to whom is an input you supply; the label set in
this repository is illustrative.

## Supply, checked against Circle

Circle's reports since 2023 give one EURC total across every approved chain, so a single chain's
figure cannot be matched to them. The December 2022 EUROC report is the exception, because Ethereum
was then the only chain. It states 24,905,662 EUROC in circulation at 2022-12-31 23:59 PT.

At that time, which `/at` places at block 16,308,594, this nest gives:

| total supply | frozen | outstanding |
|---|---|---|
| 24,905,662.05 | 0 | 24,905,662.05 |

Minted less burned is the same, 99,202,806.35 less 74,297,144.30, and `totalSupply` by `eth_call`
agrees at the first and last blocks before the next event. The report rounds to the token. The 134
blacklisted accounts at that block hold nothing, matching its zero access-denied tokens.

At 2026-09-30 23:59:59 UTC, block 26,093,723, EURC on Ethereum stood at 303,636,786.016376. Circle's
September 2026 report gives 412,549,121 across nine chains; the difference is the other eight.

## MiCA Art 22, Q3 2026

The four figures Art 22(1) asks of an issuer each quarter, with each deduction of the EBA's RTS
(Commission Delegated Regulation (EU) 2025/298) as its own view. EURC is in euros, so for EURC
these figures are illustrative; the views are the same over any FiatToken contract.

| Art 22(1) | Value | View |
|---|---|---|
| (a) holders | 26,278 | `fiat_token_v2_2_holder_count` |
| (b) value issued | 303,636,786.016376 | `fiat_token_v2_2_outstanding` |
| (c) transactions per day | 3,072.06, EUR 76,249,658.74 | `art22_quarter_transactions` |
| (d) means of exchange per day | 189.58, EUR 13,603,678.68 | `art22_quarter_means_of_exchange` |

(a) and (b) are read at the quarter's last second; (c) and (d) average every calendar day in it.
The labels are `labels-illustrative.csv`: Circle's 16 public addresses as `issuer` and 284
exchange addresses as `custodial`, from [eth-labels](https://github.com/dawsbot/eth-labels) at
d9b21ae (MIT, `LICENSE-eth-labels`). They carry no `area:` labels, so all of (d) is `unassigned`.
`views/` documents what each label means and which RTS article each deduction implements.

## Run it

From the public mirror, which downloads the sealed history and checks every file against its hash,
then follows the chain from where the mirror ends:

```sh
git clone https://github.com/nuthatch-org/eurc-nest && cd eurc-nest
nuthatch seed --from https://pub-bc282d5016f242a783a6c28cbcd4401a.r2.dev
nuthatch dev --rpc https://your-mainnet-rpc
```

Or index it yourself from block 14,807,233 with `nuthatch dev --rpc ...` and no `seed`. Either way
the sealed segments are content-addressed, so both hold the same bytes. Then:

```sh
nuthatch labels import labels-illustrative.csv
curl -s "http://127.0.0.1:8288/sql?at_time=1672559999&q=SELECT%20*%20FROM%20fiat_token_v2_2_outstanding"
```

## Re-execute a figure

An evidence bundle carries one answer as of a sealed block: the chain, the nest's NID and registry
hash, the statement, the rows, a hash of the rows in canonical order, and the hash of the label set
it read, if any. `evidence verify` asks a nest of the same NID the same statement at the same block
and says match, or names the field that differs.

The December 2022 figure above is attached to this repository's
[first release](https://github.com/nuthatch-org/eurc-nest/releases/tag/v1) as `dec-2022.json`,
made on the nest that publishes the mirror. To check it you need no RPC, only the mirror:

```sh
git clone https://github.com/nuthatch-org/eurc-nest && cd eurc-nest
nuthatch seed --from https://pub-bc282d5016f242a783a6c28cbcd4401a.r2.dev
nuthatch labels import labels-illustrative.csv
nuthatch serve &
nuthatch evidence verify dec-2022.json --url http://127.0.0.1:8288
```

It prints `match: 1 row(s) at block 16308594 reproduce`. A bundle whose rows were altered, or one
made on a nest with another NID, prints `MISMATCH` and the field that differs. The seed took 6
minutes 40 for 13,998 segments (183 MB), each checked against its hash on arrival. `serve` does
not re-hash them afterwards, so check a copy you have kept a while with `nuthatch dev`, which
does at startup.

To bundle a figure of your own, ask a running nest for it as of a sealed block:

```sh
nuthatch evidence make --at-time 1672559999 \
  "SELECT total_supply, frozen, outstanding FROM fiat_token_v2_2_outstanding" --out dec-2022.json
```

`--key` signs it with a key from `nuthatch pack keygen`, and `verify --pubkey` then checks the
signature against a key you were given. Unsigned, a bundle proves only that the answer is
reproducible, not who made it.

## Checking it against the chain

`check-at.sh` and `check-balances.sh` compare the nest with `eth_call` and block headers at random
times and blocks. They read an RPC URL from `~/eurc-nest/.rpc` and expect the nest at `127.0.0.1:8470`, so adjust both.
