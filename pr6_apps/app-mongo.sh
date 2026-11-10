#!/bin/sh
echo "[APP-MONGO] Запуск генератора логов NoSQL..."
apt-get update -qq && apt-get install -y -qq curl > /dev/null 2>&1

LEVELS="INFO INFO INFO WARN ERROR"
ACTIONS="DOC_INSERTED BATCH_SYNCED CACHE_MISS WRITE_QUORUM_WAIT REPLICA_LAG"

while true; do
  LVL=$(echo $LEVELS | awk -v r=$((RANDOM % 5 + 1)) '{print $r}')
  ACT=$(echo $ACTIONS | awk -v r=$((RANDOM % 5 + 1)) '{print $r}')
  LATENCY=$((RANDOM % 80 + 3))
  SESS_ID="sess_$((RANDOM % 9000 + 1000))"

  # Пишем документ в саму MongoDB
  mongosh -u rootAdmin -p rootPassword123 --authenticationDatabase admin db2 \
    --eval "db.user_events.insertOne({ session_id: '$SESS_ID', action: '$ACT', latency: $LATENCY, timestamp: new Date() })" > /dev/null 2>&1

  MSG="MongoDB event processed: $ACT on collection user_events"
  if [ "$LVL" = "ERROR" ]; then
    MSG="Write concern timeout: failed to achieve majority confirmation"
    LATENCY=$((LATENCY + 300))
  fi

  PAYLOAD="{\"cluster\": \"cluster-2-mongodb\", \"service\": \"iot-event-service\", \"log_level\": \"$LVL\", \"event_action\": \"$ACT\", \"execution_time_ms\": $LATENCY, \"message\": \"$MSG\"}"

  curl -s -X POST http://c4-logstash:5000 -H "Content-Type: application/json" -d "$PAYLOAD" > /dev/null 2>&1
  sleep 4
done