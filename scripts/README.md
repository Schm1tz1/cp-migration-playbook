# Kafka/CFK Load Test Scripts

Three scripts for spinning up a Kafka test workload on a CFK (Confluent for
Kubernetes) cluster: bulk topic creation, bulk consumer group creation, and
test data production. Each script runs its work inside a **single**
`kubectl exec` session (a loop executed remotely in the pod) rather than one
`kubectl exec` per item, so they stay fast even at 1000+ topics/groups.

## Contents

| Script | Purpose |
|---|---|
| `create-topics.sh` | Creates a batch of topics on the Kafka broker pod |
| `create-consumer-groups.sh` | Creates a batch of consumer groups and sets their offsets to **latest** across a set of topics |
| `produce-test-data.sh` | Produces random test messages into topics via `kcat` |

## Prerequisites

- `kubectl` configured with access to the target cluster/namespace
- A running Kafka broker pod (default assumed name: `kafka-0`) with
  `kafka-topics` and `kafka-consumer-groups` on its `PATH`
- A running `kcat` pod (default assumed name: `kcat`) with `kcat` installed
- Bash on your local machine (the scripts use arrays, `getopts`, `wait -n`)

Run all scripts from the same working directory — they share state via
`created-topics.txt`.

## Typical workflow

```bash
# 1. Create 1000 topics (test-topic-0 .. test-topic-999), 6 partitions each
./create-topics.sh -N kafka -P kafka-0 -b localhost:9092
# -> writes created-topics.txt

# 2. Create 100 consumer groups, assigned to every topic in created-topics.txt,
#    offsets committed at latest
./create-consumer-groups.sh -N kafka -P kafka-0 -b localhost:9092 -j 10
# -> writes created-consumer-groups.txt

# 3. Produce 100k test messages into every topic in created-topics.txt
./produce-test-data.sh -N kcat -P kcat -b kafka.source:9092 -m 100000 -j 8
```

All three scripts default to the same naming pattern (`test-topic-%d`) and
topic count (1000), and `produce-test-data.sh` / `create-consumer-groups.sh`
both auto-load `created-topics.txt` if it exists in the current directory —
so running them back-to-back with no arguments keeps everything in sync.

## Script details

### `create-topics.sh`

Creates topics via `kafka-topics --create --if-not-exists` inside the broker
pod.

| Flag | Meaning | Default |
|---|---|---|
| `-n` | Number of topics | `1000` |
| `-p` | Partitions per topic | `6` |
| `-r` | Replication factor | `3` |
| `-t` | Name pattern (`%d` = index) | `test-topic-%d` |
| `-s` | Starting index | `0` |
| `-P` | Broker pod name | `kafka-0` |
| `-N` | Namespace | *(none)* |
| `-b` | Bootstrap server (as seen from inside the pod) | `localhost:9092` |
| `-o` | Output file for created topic names | `created-topics.txt` |

Output: prints and saves each created topic name, one per line; failures go
to stderr and the script exits non-zero if anything failed.

### `create-consumer-groups.sh`

Creates consumer groups and commits their offsets to **latest** for a set of
topics, via `kafka-consumer-groups --reset-offsets --to-latest --execute`.
This creates the group and points it at the current end of each
topic/partition in one step — no real consumer needs to run. Groups must not
have active members at the time this runs.

| Flag | Meaning | Default |
|---|---|---|
| `-g` | Number of consumer groups | `100` |
| `-t` | Group name pattern (`%d` = index) | `test-group-%d` |
| `-s` | Starting index for group `%d` | `0` |
| `-f` | Topics file (one topic per line) | auto: `created-topics.txt` if present |
| `-T` | Topic name/pattern, used only if no topics file resolves | `test-topic-%d` |
| `-n` | Number of topics to generate from `-T` | `1000` |
| `-x` | Starting index for topic `%d` generation | `0` |
| `-P` | Broker pod name | `kafka-0` |
| `-N` | Namespace | *(none)* |
| `-b` | Bootstrap server (as seen from inside the pod) | `localhost:9092` |
| `-j` | Groups processed concurrently | `1` |
| `-o` | Output file for created group names | `created-consumer-groups.txt` |

Output: prints and saves each successfully created group name; failures go
to stderr and the script exits non-zero if anything failed.

### `produce-test-data.sh`

Produces random alphanumeric test messages into topics via:

```bash
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w <size> | head -n <count> | kcat -b <broker> -t <topic> -P
```

| Flag | Meaning | Default |
|---|---|---|
| `-f` | Topics file (one topic per line) | auto: `created-topics.txt` if present |
| `-t` | Single topic name, or pattern with `%d` (used if no topics file resolves) | `test-topic-%d` |
| `-n` | Number of topics to generate from `-t` | `1000` |
| `-s` | Starting index for topic `%d` generation | `0` |
| `-m` | Messages produced per topic | `100000` |
| `-w` | Message size in bytes (fold width) | `128` |
| `-b` | Bootstrap server (as seen from inside the pod) | `kafka.source:9092` |
| `-P` | kcat pod name | `kcat` |
| `-N` | Namespace | *(none)* |
| `-j` | Topics produced concurrently | `1` |

## Notes & caveats

- **Resource sizing**: 1000 topics × 6 partitions × RF 3 is 18,000 partition
  replicas. Check your cluster's broker count and any per-namespace quotas
  before running large defaults; scale down `-n`/`-p`/`-r` for a first pass.
- **Parallelism (`-j`)**: increases throughput for `create-consumer-groups.sh`
  and `produce-test-data.sh` but also increases concurrent load on the
  broker(s) — tune based on cluster capacity.
- **Consumer group offsets**: `--reset-offsets --execute` requires the group
  to have no active members at run time. If a group name is reused by a
  live consumer elsewhere, it will fail for that group only.
- **Idempotency**: `create-topics.sh` uses `--if-not-exists`, so re-running
  it is safe. Re-running `create-consumer-groups.sh` re-commits offsets to
  latest (harmless for idle groups). Re-running `produce-test-data.sh`
  simply appends more messages.
- All generated/consumed indices are zero-based by default; use `-s`/`-x`
  to offset ranges if you need to extend an existing batch without
  overlapping names.
  