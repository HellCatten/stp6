#!/bin/sh

NODE_ID=$1
ROLE=$2

echo "[ENTRYPOINT] Старт ноды Kafka $NODE_ID (роль: $ROLE)..."

# 1. Генерация серверной конфигурации
cat <<EOF > /tmp/server.properties
node.id=$NODE_ID
process.roles=broker,controller
controller.quorum.voters=1@c3-kafka-1:9093,2@c3-kafka-2:9093,3@c3-kafka-3:9093
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093,SASL_PLAINTEXT://0.0.0.0:9094
advertised.listeners=PLAINTEXT://c3-kafka-$NODE_ID:9092,SASL_PLAINTEXT://c3-kafka-$NODE_ID:9094
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SASL_PLAINTEXT:SASL_PLAINTEXT
sasl.enabled.mechanisms=SCRAM-SHA-256
sasl.mechanism.inter.broker.protocol=PLAINTEXT
inter.broker.listener.name=PLAINTEXT
authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:admin;User:ANONYMOUS
group.initial.rebalance.delay.ms=0
log.dirs=/tmp/kraft-combined-logs
num.partitions=2
default.replication.factor=3
EOF

# 2. Форматирование хранилища KRaft
/opt/kafka/bin/kafka-storage.sh format -t '4L622nShTUiTwyCGdBZInc' -c /tmp/server.properties --ignore-formatted

# 3. Запуск сервера Kafka в фоне
/opt/kafka/bin/kafka-server-start.sh /tmp/server.properties &
KAFKA_PID=$!

echo "[ENTRYPOINT] Сервер Kafka запущен (PID: $KAFKA_PID)"

# 4. Выполнение фоновой роли
case "$ROLE" in
  init_producer)
    (
      echo "[INIT] Ожидание готовности кворума KRaft (3 узла)..."
      sleep 12
      until /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status 2>/dev/null | grep -q "CurrentVoters:.*\[1,2,3\]"; do
        sleep 2
      done

      echo "[INIT] Кворум подтвержден! Создание топиков..."
      /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --if-not-exists --topic topic-1 --partitions 2 --replication-factor 3
      /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --if-not-exists --topic topic-2 --partitions 2 --replication-factor 3

      echo "[INIT] Создание пользователей SCRAM-SHA-256..."
      /opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type users --entity-name local_consumer --add-config 'SCRAM-SHA-256=[password=local-secret]'
      /opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type users --entity-name cross_consumer --add-config 'SCRAM-SHA-256=[password=cross-secret]'

      echo "[INIT] Настройка списков ACL..."
      /opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:9092 --add --allow-principal User:local_consumer --operation Read --operation Describe --topic topic-1 --group '*'
      /opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:9092 --add --allow-principal User:cross_consumer --operation Read --operation Describe --topic topic-1 --topic topic-2 --group '*'

      echo "[INIT] Настройка кластера полностью завершена!"
      echo "[PRODUCER-1] Запуск генератора сообщений в topic-1..."
      while true; do
        VAL=$(awk 'BEGIN{srand(); print int(rand()*1000)}')
        TS=$(date +%s)
        echo "{\"source\": \"c3-kafka-1\", \"value\": $VAL, \"timestamp\": $TS}" | \
          /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic topic-1 >/dev/null 2>&1
        sleep 6
      done
    ) &
    ;;

  producer)
    (
      echo "[PRODUCER-2] Ожидание появления topic-2..."
      until /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic topic-2 >/dev/null 2>&1; do
        sleep 3
      done

      echo "[PRODUCER-2] Запуск генератора сообщений в topic-2..."
      while true; do
        VAL=$(awk 'BEGIN{srand(); print int(rand()*1000)}')
        TS=$(date +%s)
        echo "{\"source\": \"c3-kafka-2\", \"value\": $VAL, \"timestamp\": $TS}" | \
          /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic topic-2 >/dev/null 2>&1
        sleep 6
      done
    ) &
    ;;

  snapshot)
    (
      echo "[SNAPSHOTTER] Ожидание топиков для снапшотов..."
      until /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic topic-1 >/dev/null 2>&1 && \
            /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic topic-2 >/dev/null 2>&1; do
        sleep 3
      done

      echo "[SNAPSHOTTER] Топики обнаружены. Запуск цикла параллельного сохранения..."
      while true; do
        # Запускаем сохранение обоих топиков ПАРАЛЛЕЛЬНО
        /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic topic-1 --from-beginning --timeout-ms 4000 > /snapshots/topic-1.snapshot.log 2>/dev/null &
        /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic topic-2 --from-beginning --timeout-ms 4000 > /snapshots/topic-2.snapshot.log 2>/dev/null &
        wait
        
        echo "[SNAPSHOTTER] Снапшот обоих топиков успешно сохранен в $(date)"
        sleep 25
      done
    ) &
    ;;
esac

wait $KAFKA_PID