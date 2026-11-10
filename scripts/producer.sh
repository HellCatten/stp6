#!/bin/sh
TOPIC_NAME=$1
SOURCE_NAME=$2

echo "[PRODUCER] Ожидание создания топика $TOPIC_NAME..."
until /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic "$TOPIC_NAME" > /dev/null 2>&1; do
  sleep 3
done

echo "[PRODUCER] Запуск генератора сообщений в $TOPIC_NAME..."

while true; do
  VAL=$(awk 'BEGIN{srand(); print int(rand()*1000)}')
  TS=$(date +%s)
  MSG="{\"source\": \"$SOURCE_NAME\", \"value\": $VAL, \"timestamp\": $TS}"
  
  echo "$MSG" | /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC_NAME" > /dev/null 2>&1
    
  sleep 5
done