# Работа с горизонтально масштабируемым кластером

standalone postgresql

#### Устанавливаем postgresql на ВМ в yandex cloud и загружаем dataset https://postgrespro.ru/education/demodb
```
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql && sudo apt install unzip && sudo apt -y install mc

На время загрузки ставим следующие параметры

listen_addresses = '*'
shared_buffers = 512MB 
effective_cache_size = 2GB
transaction_isolation = 'read uncommitted'
default_transaction_isolation = 'read uncommitted'
wal_level = minimal
max_wal_senders = 0
max_wal_size = '10 GB'
min_wal_size = '512 MB'
fsync = off
full_page_writes=off
checkpoint_timeout = '15 min'
checkpoint_completion_target = 0.9
wal_compression = off
synchronous_commit = off
max_worker_processes = 4
max_parallel_workers_per_gather = 4
max_parallel_maintenance_workers = 4
max_parallel_workers = 4
parallel_leader_participation = on
autovacuum = off
work_mem = '38 MB'
maintenance_work_mem = '409 MB'
effective_io_concurrency = 200
random_page_cost = 1.2

host all all 0.0.0.0/0 scram-sha-256

# загружаем данные из датасета

time psql -h 51.250.64.77 -U postgres -f demo-20250901-2y.sql

real    76m45,623s

# Общий объем БД составил 11GB

убираем параметры, перезагружаем postgres
transaction_isolation = 'read uncommitted'
default_transaction_isolation = 'read uncommitted'
autovacuum = off


demo=# select count(*) from bookings;
  count   
----------
 9706656
(1 row)

Time: 221591.577 ms (03:41.592)

demo=# SELECT
    status,
    count(*) as count,
    min(scheduled_departure) as min_scheduled_departure,
    max(scheduled_departure) as max_scheduled_departure
FROM flights
GROUP BY status
ORDER BY min_scheduled_departure;
  status   | count  | min_scheduled_departure | max_scheduled_departure 
-----------+--------+-------------------------+-------------------------
 Arrived   | 124095 | 2025-10-01 00:00:00+00  | 2027-08-31 23:10:00+00
 Cancelled |    702 | 2025-10-01 12:25:00+00  | 2027-10-29 08:00:00+00
 Departed  |     21 | 2027-08-31 14:40:00+00  | 2027-08-31 23:40:00+00
 Boarding  |      5 | 2027-08-31 23:55:00+00  | 2027-09-01 00:25:00+00
 On Time   |    173 | 2027-09-01 00:30:00+00  | 2027-09-01 23:50:00+00
 Delayed   |     10 | 2027-09-01 04:35:00+00  | 2027-09-01 18:40:00+00
 Scheduled |  10565 | 2027-09-02 00:00:00+00  | 2027-10-30 23:55:00+00
(7 rows)

Time: 53.275 ms
```


#### Разворачиваем CockroachDB в облаке

Поднимаем 3 ВМ и устанавливаем CockroachDB
```
scp -i ~/.ssh/yc cocroach.tgz ubuntu@89.169.146.244:/home/ubuntu/cocroach.tgz
scp -i ~/.ssh/yc cocroach.tgz ubuntu@89.169.128.148:/home/ubuntu/cocroach.tgz
scp -i ~/.ssh/yc cocroach.tgz ubuntu@51.250.87.29:/home/ubuntu/cocroach.tgz

sudo tar -xzvf cocroach.tgz
sudo mv cockroach-v21.1.6.linux-amd64 /opt/cockroach

генерируем сертификаты на первой ноде и переносим их на остальные ноды
cd /opt/cocroach
sudo ./cockroach cert create-ca --certs-dir=certs --ca-key=my-safe-directory/ca.key
sudo ./cockroach cert create-node localhost cdb1 cdb2 cdb3 --certs-dir=certs --ca-key=my-safe-directory/ca.key --overwrite
sudo ./cockroach cert create-client root --certs-dir=certs --ca-key=my-safe-directory/ca.key

cp -R certs /home/ubuntu/
cd /home/ubuntu
  tar -czf certs.tar.gz certs/
chown ubuntu:ubuntu certs.tar.gz
scp -i ~/.ssh/yc ubuntu@89.169.146.244:/home/ubuntu/certs.tar.gz certs.tar.gz

scp -i ~/.ssh/yc certs.tar.gz ubuntu@89.169.128.148:/home/ubuntu/certs.tar.gz
scp -i ~/.ssh/yc certs.tar.gz ubuntu@51.250.87.29:/home/ubuntu/certs.tar.gz


tar -xzf certs.tar.gz 
cd /home/ubuntu/certs
sudo chown root:root ./*
sudo mv ./* /opt/cockroach/certs



sudo /opt/cockroach/cockroach cert list --certs-dir=certs
Certificate directory: certs
  Usage  | Certificate File |    Key File     |  Expires   |                   Notes                   | Error
---------+------------------+-----------------+------------+-------------------------------------------+--------
  CA     | ca.crt           |                 | 2035/10/17 | num certs: 1                              |
  Node   | node.crt         | node.key        | 2030/10/13 | addresses: localhost,cdb-01,cdb-02,cdb-03 |
  Client | client.root.crt  | client.root.key | 2030/10/13 | user: root                                |
(3 rows)

Добавляем ноды в /etc/hosts по типу
10.128.0.21 cdb1
10.128.0.4 cdb2
10.128.0.4 cdb3
Запускаем ноды кластера

ssh ubuntu@89.169.146.244 'sudo /opt/cockroach/cockroach start --certs-dir=/opt/cockroach/certs --advertise-addr=cdb1 --join=cdb1,cdb2,cdb3 --cache=.25 --max-sql-memory=.25 --background'
ssh ubuntu@51.250.87.29  'sudo /opt/cockroach/cockroach start --certs-dir=/opt/cockroach/certs --advertise-addr=cdb2 --join=cdb1,cdb2,cdb3 --cache=.25 --max-sql-memory=.25 --background'
ssh ubuntu@89.169.128.148  'sudo /opt/cockroach/cockroach start --certs-dir=/opt/cockroach/certs --advertise-addr=cdb3 --join=cdb1,cdb2,cdb3 --cache=.25 --max-sql-memory=.25 --background'


# Инициализируем кластер
cd /opt/cocroach
sudo ./cockroach init --certs-dir=certs --host=cdb1

Проверяем
./cockroach node status --certs-dir=certs
  id |  address   | sql_address |  build  |         started_at         |         updated_at         | locality | is_available | is_live
-----+------------+-------------+---------+----------------------------+----------------------------+----------+--------------+----------
   1 | cdb1:26257 | cdb1:26257  | v21.1.6 | 2025-10-09 04:02:24.731902 | 2025-10-09 04:12:00.809864 |          | true         | true
   2 | cdb2:26257 | cdb2:26257  | v21.1.6 | 2025-10-09 04:11:52.114332 | 2025-10-09 04:12:01.147941 |          | true         | true
   3 | cdb3:26257 | cdb3:26257  | v21.1.6 | 2025-10-09 04:11:59.821508 | 2025-10-09 04:11:59.907348 |          | true         | true
(3 rows)

Создаем таблицы

./cockroach sql --certs-dir=certs

-- Удаляем неподдерживаемые команды и расширения

SET CLUSTER SETTING sql.defaults.vectorize = 'on';

-- Создаем схему
CREATE SCHEMA IF NOT EXISTS bookings;

-- Таблицы (без ссылок на функции)
CREATE TABLE bookings.airplanes_data (
    airplane_code STRING(3) NOT NULL,
    model JSONB NOT NULL,
    range INT8 NOT NULL,
    speed INT8 NOT NULL,
    CONSTRAINT airplanes_data_pkey PRIMARY KEY (airplane_code),
    CONSTRAINT airplanes_data_range_check CHECK (range > 0),
    CONSTRAINT airplanes_data_speed_check CHECK (speed > 0)
);

CREATE TABLE bookings.airports_data (
    airport_code STRING(3) NOT NULL,
    airport_name JSONB NOT NULL,
    city JSONB NOT NULL,
    country JSONB NOT NULL,
    coordinates STRING,
    timezone STRING NOT NULL,
    CONSTRAINT airports_data_pkey PRIMARY KEY (airport_code)
);

CREATE TABLE bookings.bookings (
    book_ref STRING(6) NOT NULL,
    book_date TIMESTAMPTZ NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    CONSTRAINT bookings_pkey PRIMARY KEY (book_ref)
);

CREATE TABLE bookings.flights (
    flight_id INT8 NOT NULL DEFAULT unique_rowid(),
    route_no STRING NOT NULL,
    status STRING NOT NULL,
    scheduled_departure TIMESTAMPTZ NOT NULL,
    scheduled_arrival TIMESTAMPTZ NOT NULL,
    actual_departure TIMESTAMPTZ NULL,
    actual_arrival TIMESTAMPTZ NULL,
    CONSTRAINT flights_pkey PRIMARY KEY (flight_id),
    CONSTRAINT flights_route_no_scheduled_departure_key UNIQUE (route_no, scheduled_departure),
    CONSTRAINT flight_status_check CHECK (status IN ('Scheduled', 'On Time', 'Delayed', 'Boarding', 'Departed', 'Arrived', 'Cancelled'))
);

CREATE TABLE bookings.routes (
    route_no STRING NOT NULL,
    validity_start TIMESTAMPTZ NOT NULL,
    validity_end TIMESTAMPTZ NOT NULL,
    departure_airport STRING(3) NOT NULL,
    arrival_airport STRING(3) NOT NULL,
    airplane_code STRING(3) NOT NULL,
    days_of_week INT8[] NOT NULL,
    scheduled_time TIME NOT NULL,
    duration INTERVAL NOT NULL,
    CONSTRAINT routes_pkey PRIMARY KEY (route_no, validity_start)
);

CREATE TABLE bookings.seats (
    airplane_code STRING(3) NOT NULL,
    seat_no STRING NOT NULL,
    fare_conditions STRING NOT NULL,
    CONSTRAINT seats_pkey PRIMARY KEY (airplane_code, seat_no),
    CONSTRAINT seat_fare_conditions_check CHECK (fare_conditions IN ('Economy', 'Comfort', 'Business'))
);

CREATE TABLE bookings.tickets (
    ticket_no STRING NOT NULL,
    book_ref STRING(6) NOT NULL,
    passenger_id STRING NOT NULL,
    passenger_name STRING NOT NULL,
    outbound BOOL NOT NULL,
    CONSTRAINT tickets_pkey PRIMARY KEY (ticket_no),
    CONSTRAINT tickets_book_ref_passenger_id_outbound_key UNIQUE (book_ref, passenger_id, outbound)
);

CREATE TABLE bookings.segments (
    ticket_no STRING NOT NULL,
    flight_id INT8 NOT NULL,
    fare_conditions STRING NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    CONSTRAINT segments_pkey PRIMARY KEY (ticket_no, flight_id),
    CONSTRAINT segments_fare_conditions_check CHECK (fare_conditions IN ('Economy', 'Comfort', 'Business')),
    CONSTRAINT segments_price_check CHECK (price >= 0)
);

CREATE TABLE bookings.boarding_passes (
    ticket_no STRING NOT NULL,
    flight_id INT8 NOT NULL,
    seat_no STRING NOT NULL,
    boarding_no INT8 NULL,
    boarding_time TIMESTAMPTZ NULL,
    CONSTRAINT boarding_passes_pkey PRIMARY KEY (ticket_no, flight_id),
    CONSTRAINT boarding_passes_flight_id_boarding_no_key UNIQUE (flight_id, boarding_no),
    CONSTRAINT boarding_passes_flight_id_seat_no_key UNIQUE (flight_id, seat_no)
);

-- Вьюхи с хардкодированным языком (вместо функций)
CREATE VIEW bookings.airplanes AS
    SELECT airplane_code,
           jsonb_extract_path(model, 'en') AS model,  -- Хардкод 'en' вместо bookings.lang()
           range,
           speed
    FROM bookings.airplanes_data;

CREATE VIEW bookings.airports AS
    SELECT airport_code,
           jsonb_extract_path(airport_name, 'en') AS airport_name,
           jsonb_extract_path(city, 'en') AS city,
           jsonb_extract_path(country, 'en') AS country,
           coordinates,
           timezone
    FROM bookings.airports_data;

-- Внешние ключи
ALTER TABLE bookings.routes 
    ADD CONSTRAINT routes_airplane_code_fkey 
    FOREIGN KEY (airplane_code) REFERENCES bookings.airplanes_data(airplane_code);

ALTER TABLE bookings.routes 
    ADD CONSTRAINT routes_arrival_airport_fkey 
    FOREIGN KEY (arrival_airport) REFERENCES bookings.airports_data(airport_code);

ALTER TABLE bookings.routes 
    ADD CONSTRAINT routes_departure_airport_fkey 
    FOREIGN KEY (departure_airport) REFERENCES bookings.airports_data(airport_code);

ALTER TABLE bookings.seats 
    ADD CONSTRAINT seats_airplane_code_fkey 
    FOREIGN KEY (airplane_code) REFERENCES bookings.airplanes_data(airplane_code);

ALTER TABLE bookings.segments 
    ADD CONSTRAINT segments_flight_id_fkey 
    FOREIGN KEY (flight_id) REFERENCES bookings.flights(flight_id);

ALTER TABLE bookings.segments 
    ADD CONSTRAINT segments_ticket_no_fkey 
    FOREIGN KEY (ticket_no) REFERENCES bookings.tickets(ticket_no);

ALTER TABLE bookings.tickets 
    ADD CONSTRAINT tickets_book_ref_fkey 
    FOREIGN KEY (book_ref) REFERENCES bookings.bookings(book_ref);

ALTER TABLE bookings.boarding_passes 
    ADD CONSTRAINT boarding_passes_ticket_no_flight_id_fkey 
    FOREIGN KEY (ticket_no, flight_id) REFERENCES bookings.segments(ticket_no, flight_id);

-- Индексы
CREATE INDEX segments_flight_id_idx ON bookings.segments (flight_id);
CREATE INDEX routes_departure_airport_idx ON bookings.routes (departure_airport);

переносим csv
tar -czf csv.tar.gz csv/
scp -i ~/.ssh/yc csv.tar.gz ubuntu@89.169.146.244:/home/ubuntu/csv.tar.gz

sudo mkdir -p /home/ubuntu/cockroach-data/extern
sudo mv /opt/cockroach/extern/*.csv /home/ubuntu/cockroach-data/extern
sudo chmod 644 /home/ubuntu/cockroach-data/extern/*.csv

```

После загрузки проверяем

select count(*) from bookings.bookings;
   count
-----------
  9706656
(1 row)

Time: 2.097s total (execution 2.097s / network 0.000s)


Весь код преобразования данных не стал вносить.

## Вывод:
Плюсы cocroachdb - более быстрое выполнение запросов.
Минусы - сложность переноса данных (не хватает типов данных, при переносе нужно преобразование)
Сложности - неддоступен в РФ, удалось установить только скачав бинарник через vpn.