// 1. Инициализируем Replica Set
try {
  rs.initiate({
    _id: "rs0",
    members: [
      { _id: 0, host: "c2-mongo-1:27017", priority: 2 },
      { _id: 1, host: "c2-mongo-2:27017", priority: 1 },
      { _id: 2, host: "c2-mongo-3:27017", priority: 1 }
    ]
  });
} catch(e) {
  print("Replica set уже инициализирован или в процессе");
}

print("Ожидание назначения Primary...");
while (!rs.isMaster().ismaster) {
  sleep(1000);
}

// 2. Создаем root администратора (работает Localhost Exception)
let adminDB = db.getSiblingDB("admin");
try {
  adminDB.createUser({
    user: "rootAdmin",
    pwd: "rootPassword123",
    roles: [ { role: "root", db: "admin" } ]
  });
} catch(e) {
  print("rootAdmin уже существует");
}

// Авторизуемся под rootAdmin
adminDB.auth("rootAdmin", "rootPassword123");

// 3. Создаем пользователей по заданию
try {
  adminDB.createUser({
    user: "local_user",
    pwd: "local_pass",
    roles: [
      { role: "readWrite", db: "db1" }
    ]
  });
} catch(e) {
  print("local_user уже существует");
}

try {
  adminDB.createUser({
    user: "cross_user",
    pwd: "cross_pass",
    roles: [
      { role: "readWrite", db: "db1" },
      { role: "read", db: "db2" }
    ]
  });
} catch(e) {
  print("cross_user уже существует");
}

// 4. Наполняем db1 документами
let db1 = db.getSiblingDB("db1");
if (db1.sensor_data.countDocuments() === 0) {
  db1.sensor_data.insertMany([
    { device_id: "dev_" + Math.floor(Math.random() * 1000), temp: (Math.random() * 30 + 10).toFixed(2), timestamp: new Date() },
    { device_id: "dev_" + Math.floor(Math.random() * 1000), temp: (Math.random() * 30 + 10).toFixed(2), timestamp: new Date() }
  ]);
}

// 5. Наполняем db2 документами
let db2 = db.getSiblingDB("db2");
if (db2.user_events.countDocuments() === 0) {
  db2.user_events.insertMany([
    { session_id: "sess_" + Math.random().toString(36).substring(7), action: "LOGIN", status: "SUCCESS" },
    { session_id: "sess_" + Math.random().toString(36).substring(7), action: "PURCHASE", amount: Math.floor(Math.random() * 500) }
  ]);
}

print("=== НАСТРОЙКА КЛАСТЕРА И ПОЛЬЗОВАТЕЛЕЙ УСПЕШНО ЗАВЕРШЕНА ===");