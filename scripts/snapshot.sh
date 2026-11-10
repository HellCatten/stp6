#!/bin/sh
echo "[SNAPSHOTTER] Ожидание топиков для снапшота..."
until /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic topic-1 > /dev/null 2>&1 && \
      /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic topic-2 > /dev/null 2>&1; do
  sleep 3
done

echo "[SNAPSHOTTER] Топики обнаружены. Старт цикла сохранения каждые 30 секунд..."

while true; do
  /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic topic-1 \
    --from-beginning \
    --timeout-ms 3000 > /snapshots/topic-1.snapshot.log 2>/dev/null

  /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic topic-2 \
    --from-beginning \
    --timeout-ms 3000 > /snapshots/topic-2.snapshot.log 2>/dev/null

  echo "[SNAPSHOTTER] Снапшот топиков сохранен в $(date)"
  sleep 30
done