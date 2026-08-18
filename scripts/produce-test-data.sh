#!/usr/bin/env bash
#
# produce-test-data.sh
#
# Produce random test data into one or more Kafka topics via `kubectl exec`
# into a kcat pod, using the same generation approach as:
#
#   cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n <N> | kcat -b <broker> -t <topic> -P
#
# Topics can come from (in priority order):
#   1) An explicit topic list file (-f), e.g. the created-topics.txt produced
#      by create-topics.sh
#   2) A single topic (-t) with no %d placeholder
#   3) A generated set of names using a printf-style pattern + count (-t/-n),
#      matching create-topics.sh's naming
#
# All topics are handled inside a single kubectl exec session; with -j > 1,
# topics are produced in parallel (N topics at a time) inside the pod.
#
# Usage:
#   ./produce-test-data.sh [options]
#
# Options:
#   -f TOPICS_FILE       File with one topic name per line. If omitted and
#                        'created-topics.txt' exists in cwd, it is used
#                        automatically. Overrides -t/-n/-s generation.
#   -t NAME_PATTERN       Single topic name, or printf pattern with %d
#                         (default: "test-topic-%d")
#   -n NUM_TOPICS         Number of topics to generate from pattern (default: 1000)
#                         Ignored if -f resolves to a file, or if -t has no %d.
#   -s START_INDEX        Starting index for %d generation      (default: 0)
#   -m MESSAGES           Messages to produce per topic           (default: 10000)
#   -w MESSAGE_SIZE        Message size in bytes (fold width)      (default: 128)
#   -b BOOTSTRAP_SERVER    Broker address, as seen from inside pod (default: kafka.source:9092)
#   -P POD                 kcat pod name                           (default: kcat)
#   -N NAMESPACE           Kubernetes namespace (optional)
#   -j PARALLEL            Topics to produce concurrently          (default: 1)
#   -h                     Show this help
#
# Examples:
#   ./produce-test-data.sh
#   ./produce-test-data.sh -f created-topics.txt -m 50000 -j 8
#   ./produce-test-data.sh -t test-topic -m 6000000 -w 128
#
set -euo pipefail

TOPICS_FILE=""
NAME_PATTERN="test-topic-%d"
NUM_TOPICS=1000
START_INDEX=0
MESSAGES=10000
MESSAGE_SIZE=128
BOOTSTRAP_SERVER="kafka.source:9092"
POD="kcat"
NAMESPACE=""
PARALLEL=1

usage() {
  sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
}

while getopts "f:t:n:s:m:w:b:P:N:j:h" opt; do
  case "$opt" in
    f) TOPICS_FILE=$OPTARG ;;
    t) NAME_PATTERN=$OPTARG ;;
    n) NUM_TOPICS=$OPTARG ;;
    s) START_INDEX=$OPTARG ;;
    m) MESSAGES=$OPTARG ;;
    w) MESSAGE_SIZE=$OPTARG ;;
    b) BOOTSTRAP_SERVER=$OPTARG ;;
    P) POD=$OPTARG ;;
    N) NAMESPACE=$OPTARG ;;
    j) PARALLEL=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

for v in NUM_TOPICS START_INDEX MESSAGES MESSAGE_SIZE PARALLEL; do
  val="${!v}"
  if ! [[ "$val" =~ ^[0-9]+$ ]]; then
    echo "Error: $v must be a non-negative integer (got '$val')" >&2
    exit 1
  fi
done

NS_FLAG=()
if [[ -n "$NAMESPACE" ]]; then
  NS_FLAG=(-n "$NAMESPACE")
fi

# Resolve the topic list.
TOPICS=()

if [[ -z "$TOPICS_FILE" && -f "created-topics.txt" ]]; then
  TOPICS_FILE="created-topics.txt"
fi

if [[ -n "$TOPICS_FILE" ]]; then
  if [[ ! -f "$TOPICS_FILE" ]]; then
    echo "Error: topics file '$TOPICS_FILE' not found" >&2
    exit 1
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] && TOPICS+=("$line")
  done < "$TOPICS_FILE"
  echo "Loaded ${#TOPICS[@]} topic(s) from $TOPICS_FILE"
elif [[ "$NAME_PATTERN" != *%d* ]]; then
  TOPICS=("$NAME_PATTERN")
  echo "Using single topic: $NAME_PATTERN"
else
  END_INDEX=$((START_INDEX + NUM_TOPICS - 1))
  for i in $(seq "$START_INDEX" "$END_INDEX"); do
    TOPICS+=("$(printf "$NAME_PATTERN" "$i")")
  done
  echo "Generated ${#TOPICS[@]} topic name(s) from pattern '$NAME_PATTERN'"
fi

if [[ "${#TOPICS[@]}" -eq 0 ]]; then
  echo "Error: no topics resolved" >&2
  exit 1
fi

echo "Producing $MESSAGES message(s) of $MESSAGE_SIZE bytes each to ${#TOPICS[@]} topic(s)"
echo "  pod:       $POD${NAMESPACE:+ (namespace: $NAMESPACE)}"
echo "  broker:    $BOOTSTRAP_SERVER"
echo "  parallel:  $PARALLEL"
echo ""

# Build a quoted bash array literal for the remote script.
TOPICS_LITERAL=""
for t in "${TOPICS[@]}"; do
  TOPICS_LITERAL+=$(printf '%q ' "$t")
done

REMOTE_SCRIPT=$(cat <<EOF
topics=($TOPICS_LITERAL)

produce_one() {
  topic="\$1"
  echo ">>> [\$topic] producing $MESSAGES messages..."
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $MESSAGE_SIZE | head -n $MESSAGES \\
    | kcat -b '$BOOTSTRAP_SERVER' -t "\$topic" -P
  echo ">>> [\$topic] done."
}

running=0
for topic in "\${topics[@]}"; do
  produce_one "\$topic" &
  running=\$((running + 1))
  if [[ "\$running" -ge $PARALLEL ]]; then
    wait -n
    running=\$((running - 1))
  fi
done
wait
echo "All topics produced."
EOF
)

kubectl exec "${NS_FLAG[@]}" -i "$POD" -- bash -c "$REMOTE_SCRIPT"

echo ""
echo "Done. Produced $MESSAGES message(s) to ${#TOPICS[@]} topic(s)."
