#!/usr/bin/env bash
#
# create-topics.sh
#
# Bulk-create Kafka topics on a CFK (Confluent for Kubernetes) cluster by
# running kafka-topics inside the broker pod via `kubectl exec`.
#
# All topics are created in a single kubectl exec session (one remote loop)
# rather than one kubectl exec per topic, which is dramatically faster for
# large counts.
#
# Usage:
#   ./create-topics.sh [options]
#
# Options:
#   -n NUM_TOPICS        Number of topics to create        (default: 500)
#   -p PARTITIONS        Partitions per topic               (default: 6)
#   -r REPLICATION       Replication factor                 (default: 3)
#   -t NAME_PATTERN      printf-style name pattern, %d = index (default: "test-topic-%d")
#                        Index starts at 0 unless -s is given.
#   -s START_INDEX       Starting index for %d              (default: 0)
#   -P POD               Pod name to exec into              (default: kafka-0)
#   -N NAMESPACE         Kubernetes namespace (optional)
#   -b BOOTSTRAP_SERVER  Bootstrap server, as seen from      (default: localhost:9092)
#                        inside the pod
#   -o OUTPUT_FILE       File to write created topic names  (default: created-topics.txt)
#   -h                   Show this help
#
# Examples:
#   ./create-topics.sh
#   ./create-topics.sh -n 500 -p 12 -r 3 -t "load-test-%d"
#   ./create-topics.sh -P kafka-0 -N kafka -b kafka.source:9092
#
set -euo pipefail

NUM_TOPICS=500
PARTITIONS=6
REPLICATION_FACTOR=3
NAME_PATTERN="test-topic-%d"
START_INDEX=0
POD="kafka-0"
NAMESPACE=""
BOOTSTRAP_SERVER="localhost:9092"
OUTPUT_FILE="created-topics.txt"

usage() {
  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

while getopts "n:p:r:t:s:P:N:b:o:h" opt; do
  case "$opt" in
    n) NUM_TOPICS=$OPTARG ;;
    p) PARTITIONS=$OPTARG ;;
    r) REPLICATION_FACTOR=$OPTARG ;;
    t) NAME_PATTERN=$OPTARG ;;
    s) START_INDEX=$OPTARG ;;
    P) POD=$OPTARG ;;
    N) NAMESPACE=$OPTARG ;;
    b) BOOTSTRAP_SERVER=$OPTARG ;;
    o) OUTPUT_FILE=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# basic validation
for v in NUM_TOPICS PARTITIONS REPLICATION_FACTOR START_INDEX; do
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

END_INDEX=$((START_INDEX + NUM_TOPICS - 1))

echo "Creating $NUM_TOPICS topics on pod '$POD'${NAMESPACE:+ (namespace: $NAMESPACE)}"
echo "  pattern:     $NAME_PATTERN"
echo "  indices:     $START_INDEX..$END_INDEX"
echo "  partitions:  $PARTITIONS"
echo "  replication: $REPLICATION_FACTOR"
echo "  bootstrap:   $BOOTSTRAP_SERVER"
echo ""

# Build the remote script that runs entirely inside the pod.
REMOTE_SCRIPT=$(cat <<EOF
fail=0
for i in \$(seq $START_INDEX $END_INDEX); do
  topic=\$(printf '$NAME_PATTERN' "\$i")
  if kafka-topics --bootstrap-server '$BOOTSTRAP_SERVER' \
      --create --if-not-exists \
      --topic "\$topic" \
      --partitions $PARTITIONS \
      --replication-factor $REPLICATION_FACTOR \
      > /tmp/.topic_create_log 2>&1; then
    echo "\$topic"
  else
    echo "FAILED: \$topic" >&2
    cat /tmp/.topic_create_log >&2
    fail=1
  fi
done
exit \$fail
EOF
)

set +e
kubectl exec "${NS_FLAG[@]}" "$POD" -- bash -c "$REMOTE_SCRIPT" | tee "$OUTPUT_FILE"
RC=${PIPESTATUS[0]}
set -e

echo ""
CREATED=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
echo "Done. $CREATED topic(s) confirmed created. List saved to: $OUTPUT_FILE"

if [[ "$RC" -ne 0 ]]; then
  echo "Note: one or more topics failed to create; see stderr output above." >&2
  exit 1
fi
