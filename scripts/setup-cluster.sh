#!/bin/sh

echo "Ожидание доступности c2-mongo-1..."
until mongosh --host c2-mongo-1:27017 --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; do
  sleep 2
done

echo "Нода готова. Выполняем инициализацию через локальный сокет c2-mongo-1..."
mongosh --host c2-mongo-1:27017 /scripts/init-cluster.js

echo "Инициализация завершена."