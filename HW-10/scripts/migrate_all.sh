#!/bin/bash
echo "=== Миграция bookings из PostgreSQL в ClickHouse ==="
echo "PostgreSQL: 10.10.0.11"
echo "ClickHouse: контейнер some-clickhouse-server"

# 1. Экспорт
echo "📤 1. Экспорт данных из PostgreSQL..."
chmod +x export_data.sh
./export_data.sh

# 2. Создание схемы
echo "🗃️  2. Создание схемы в ClickHouse..."
docker run -i --rm --network=container:some-clickhouse-server \
    --entrypoint clickhouse-client clickhouse/clickhouse-server \
    < create_schema.ch

# 3. Импорт
echo "📥 3. Импорт данных в ClickHouse..."
chmod +x import_data.sh
./import_data.sh

# 4. Пост-обработка
echo "⚙️  4. Пост-обработка данных..."
docker run -i --rm --network=container:some-clickhouse-server \
    --entrypoint clickhouse-client clickhouse/clickhouse-server \
    < post_processing.ch

echo "✅ Миграция завершена!"
echo "Для проверки выполните:"
echo "docker run -it --rm --network=container:some-clickhouse-server --entrypoint clickhouse-client clickhouse/clickhouse-server -q 'USE bookings; SHOW TABLES;'"