#!/bin/sh
echo "=== ОЖИДАНИЕ ГОТОВНОСТИ КВОРУМА KRAFT (3 УЗЛА) ==="

# Ждем, пока утилита кворума увидит всех 3 участников [1,2,3]
until /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status 2>/dev/null | grep -q "CurrentVoters:.*\[1,2,3\]"; do
  sleep 2
done

echo "=== КВОРУМ СОБРАН. СОЗДАНИЕ ТОПИКОВ (REPLICATION FACTOR = 3) ==="
/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --if-not-exists \
  --topic topic-1 --partitions 2 --replication-factor 3

/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --if-not-exists \
  --topic topic-2 --partitions 2 --replication-factor 3

echo "=== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ SCRAM-SHA-256 ==="
/opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --alter \
  --entity-type users --entity-name local_consumer \
  --add-config 'SCRAM-SHA-256=[password=local-secret]'

/opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --alter \
  --entity-type users --entity-name cross_consumer \
  --add-config 'SCRAM-SHA-256=[password=cross-secret]'

echo "=== НАСТРОЙКА СПИСКОВ ACL ==="
# local_consumer: доступ ТОЛЬКО к topic-1
/opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:9092 --add \
  --allow-principal User:local_consumer --operation Read --operation Describe \
  --topic topic-1 --group '*'

# cross_consumer: доступ к topic-1 И topic-2
/opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:9092 --add \
  --allow-principal User:cross_consumer --operation Read --operation Describe \
  --topic topic-1 --topic topic-2 --group '*'

echo "=== ИНИЦИАЛИЗАЦИЯ KAFKA ПОЛНОСТЬЮ ЗАВЕРШЕНА ==="