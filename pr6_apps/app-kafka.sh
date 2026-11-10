#!/bin/sh
echo "[APP-KAFKA] Запуск генератора логов Kafka..."
apk add --no-cache curl > /dev/null 2>&1

LEVELS="INFO INFO INFO WARN ERROR"
ACTIONS="MESSAGE_CONSUMED COMMIT_OFFSET REBALANCE_OK PARTITION_REVOKED BROKER_HEARTBEAT_TIMEOUT"

while true; do
  LVL=$(echo $LEVELS | awk -v r=$((RANDOM % 5 + 1)) '{print $r}')
  ACT=$(echo $ACTIONS | awk -v r=$((RANDOM % 5 + 1)) '{print $r}')
  LATENCY=$((RANDOM % 40 + 2))
  OFFSET=$((RANDOM % 5000 + 100))

  MSG="Consumed record at offset $OFFSET from topic-1"
  if [ "$LVL" = "ERROR" ]; then
    MSG="Coordinator rejected offset commit: Group rebalance in progress"
    LATENCY=$((LATENCY + 200))
  fi

  PAYLOAD="{\"cluster\": \"cluster-3-kafka\", \"service\": \"stream-consumer\", \"log_level\": \"$LVL\", \"event_action\": \"$ACT\", \"execution_time_ms\": $LATENCY, \"message\": \"$MSG\"}"

  curl -s -X POST http://c4-logstash:5000 -H "Content-Type: application/json" -d "$PAYLOAD" > /dev/null 2>&1
  sleep 4
done