#!/usr/bin/env bash
#
# create-consumer-groups.sh
#
# Bulk-create Kafka consumer groups on a CFK cluster and assign each of them
# to a set of topics with offsets committed at the latest (end) offset, via
# `kubectl exec` into the broker pod.
#
# This works by running:
#   kafka-consumer-groups --bootstrap-server <b> --group <g> \
#     --topic <t1> --topic <t2> ... --reset-offsets --to-latest --execute
#
# `--reset-offsets --to-latest --execute` commits offsets for a group even if
# it has never had active members, which both creates the group and points it
# at the latest offset for every listed topic/partition in one step. Groups
# must not have live/active consumers while this runs.
#
# Topics are resolved the same way as produce-test-data.sh:
#   1) An explicit topic list file (-f), e.g. created-topics.txt
#   2) A single topic (-T) with no %d placeholder
#   3) A generated set of names from a printf-style pattern + count (-T/-n)
#
# All groups are processed inside a single kubectl exec session; with -j > 1,
# groups are processed in parallel (N groups at a time) inside the pod.
#
# Usage:
#   ./create-consumer-groups.sh [options]
#
# Options:
#   -g NUM_GROUPS        Number of consumer groups to create   (default: 100)
#   -t NAME_PATTERN      printf-style group name pattern, %d = (default: "test-group-%d")
#                        index. Index starts at 0 unless -s given.
#   -s START_INDEX       Starting index for group %d           (default: 0)
#   -f TOPICS_FILE       File with one topic name per line. If omitted and
#                        'created-topics.txt' exists in cwd, it is used
#                        automatically.
#   -T TOPIC_PATTERN     Single topic name, or printf pattern with %d, used
#                        only if -f resolves to nothing            (default: "test-topic-%d")
#   -n NUM_TOPICS        Number of topics to generate from -T pattern
#                        (default: 1000). Ignored if a topics file is used,
#                        or if -T has no %d.
#   -x TOPIC_START_INDEX Starting index for topic %d generation    (default: 0)
#   -P POD                kafka broker pod to exec into            (default: kafka-0)
#   -N NAMESPACE           Kubernetes namespace (optional)
#   -b BOOTSTRAP_SERVER    Bootstrap server, as seen from inside    (default: localhost:9092)
#                          the pod
#   -j PARALLEL            Groups to process concurrently          (default: 1)
#   -o OUTPUT_FILE         File to write created group names        (default: created-consumer-groups.txt)
#   -h                     Show this help
#
# Examples:
#   ./create-consumer-groups.sh
#   ./create-consumer-groups.sh -g 50 -t "load-group-%d" -f created-topics.txt
#   ./create-consumer-groups.sh -g 200 -j 10 -P kafka-0 -N kafka -b kafka.source:9092
#
set -euo pipefail

NUM_GROUPS=100
NAME_PATTERN="test-group-%d"
START_INDEX=0
TOPICS_FILE=""
TOPIC_PATTERN="test-topic-%d"
NUM_TOPICS=1000
TOPIC_START_INDEX=0
POD="kafka-0"
NAMESPACE=""
BOOTSTRAP_SERVER="localhost:9092"
PARALLEL=1
OUTPUT_FILE="created-consumer-groups.txt"

usage() {
  sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
}

while getopts "g:t:s:f:T:n:x:P:N:b:j:o:h" opt; do
  case "$opt" in
    g) NUM_GROUPS=$OPTARG ;;
    t) NAME_PATTERN=$OPTARG ;;
    s) START_INDEX=$OPTARG ;;
    f) TOPICS_FILE=$OPTARG ;;
    T) TOPIC_PATTERN=$OPTARG ;;
    n) NUM_TOPICS=$OPTARG ;;
    x) TOPIC_START_INDEX=$OPTARG ;;
    P) POD=$OPTARG ;;
    N) NAMESPACE=$OPTARG ;;
    b) BOOTSTRAP_SERVER=$OPTARG ;;
    j) PARALLEL=$OPTARG ;;
    o) OUTPUT_FILE=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

for v in NUM_GROUPS START_INDEX NUM_TOPICS TOPIC_START_INDEX PARALLEL; do
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

# --- Resolve topic list (same convention as produce-test-data.sh) ---
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
elif [[ "$TOPIC_PATTERN" != *%d* ]]; then
  TOPICS=("$TOPIC_PATTERN")
  echo "Using single topic: $TOPIC_PATTERN"
else
  END_TOPIC_INDEX=$((TOPIC_START_INDEX + NUM_TOPICS - 1))
  for i in $(seq "$TOPIC_START_INDEX" "$END_TOPIC_INDEX"); do
    TOPICS+=("$(printf "$TOPIC_PATTERN" "$i")")
  done
  echo "Generated ${#TOPICS[@]} topic name(s) from pattern '$TOPIC_PATTERN'"
fi

if [[ "${#TOPICS[@]}" -eq 0 ]]; then
  echo "Error: no topics resolved" >&2
  exit 1
fi

# --- Resolve group list ---
GROUP_NAMES=()
END_GROUP_INDEX=$((START_INDEX + NUM_GROUPS - 1))
for i in $(seq "$START_INDEX" "$END_GROUP_INDEX"); do
  GROUP_NAMES+=("$(printf "$NAME_PATTERN" "$i")")
done

echo "Creating ${#GROUP_NAMES[@]} consumer group(s) on pod '$POD'${NAMESPACE:+ (namespace: $NAMESPACE)}"
echo "  group pattern: $NAME_PATTERN"
echo "  topics:        ${#TOPICS[@]}"
echo "  bootstrap:     $BOOTSTRAP_SERVER"
echo "  parallel:      $PARALLEL"
echo "  offset reset:  latest"
echo ""

# Build quoted bash array literals for the remote script.
GROUPS_LITERAL=""
for g in "${GROUP_NAMES[@]}"; do
  GROUPS_LITERAL+=$(printf '%q ' "$g")
done

TOPICS_LITERAL=""
for t in "${TOPICS[@]}"; do
  TOPICS_LITERAL+=$(printf '%q ' "$t")
done

REMOTE_SCRIPT=$(cat <<EOF
groups=($GROUPS_LITERAL)
topics=($TOPICS_LITERAL)

topic_args=()
for t in "\${topics[@]}"; do
  topic_args+=(--topic "\$t")
done

assign_one() {
  group="\$1"
  if kafka-consumer-groups --bootstrap-server '$BOOTSTRAP_SERVER' \\
      --group "\$group" \\
      "\${topic_args[@]}" \\
      --reset-offsets --to-latest --execute \\
      > /tmp/.cg_\${group//\//_}.log 2>&1; then
    echo "\$group"
  else
    echo "FAILED: \$group" >&2
    cat /tmp/.cg_\${group//\//_}.log >&2
  fi
}

running=0
for group in "\${groups[@]}"; do
  assign_one "\$group" &
  running=\$((running + 1))
  if [[ "\$running" -ge $PARALLEL ]]; then
    wait -n
    running=\$((running - 1))
  fi
done
wait
EOF
)

set +e
kubectl exec "${NS_FLAG[@]}" -i "$POD" -- bash -c "$REMOTE_SCRIPT" | tee "$OUTPUT_FILE"
RC=${PIPESTATUS[0]}
set -e

echo ""
CREATED=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
echo "Done. $CREATED consumer group(s) confirmed created and set to latest offset across ${#TOPICS[@]} topic(s)."
echo "List saved to: $OUTPUT_FILE"

if [[ "$RC" -ne 0 ]]; then
  echo "Note: one or more groups failed; see stderr output above." >&2
  exit 1
fi
