#!/bin/sh
echo "[APP-POSTGRES] Запуск генератора логов транзакций..."
apk add --no-cache curl > /dev/null 2>&1

LEVELS="INFO INFO INFO WARN ERROR"
ACTIONS="ORDER_CREATED PAYMENT_PROCESSED INVENTORY_CHECKED DB_SLOW_QUERY CONNECTION_TIMEOUT"

while true; do
  # Случайный выбор уровня лога и действия
  LVL=$(echo $LEVELS | awk -v r=$((RANDOM % 5 + 1)) '{print $r}')
  ACT=$(echo $ACTIONS | awk -v r=$((RANDOM % 5 + 1)) '{print $r}')
  LATENCY=$((RANDOM % 120 + 5))
  ORDER_ID="ORD-$((RANDOM % 90000 + 10000))"

  # Пишем строку в саму базу
  PGPASSWORD="0000" psql -h localhost -U admin -d db1 -c "INSERT INTO orders (order_number, amount) VALUES ('$ORDER_ID', $LATENCY);" > /dev/null 2>&1

  # Формируем JSON-лог
  MSG="Executed database transaction for $ORDER_ID [action=$ACT]"
  if [ "$LVL" = "ERROR" ]; then
    MSG="Transaction failed for $ORDER_ID: connection pool exhaustion"
    LATENCY=$((LATENCY + 500))
  fi

  PAYLOAD="{\"cluster\": \"cluster-1-postgres\", \"service\": \"order-service\", \"log_level\": \"$LVL\", \"event_action\": \"$ACT\", \"execution_time_ms\": $LATENCY, \"message\": \"$MSG\"}"

  curl -s -X POST http://c4-logstash:5000 -H "Content-Type: application/json" -d "$PAYLOAD" > /dev/null 2>&1
  sleep 4
done