## Тестирование pgbench
### Имеется ВМ CPU-2 RAM-2GB SSD-10GB
### Установка и настройка Postgres:
```
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql && sudo apt install unzip && sudo apt -y install mc

# pg_lsclusters 
Ver Cluster Port Status Owner    Data directory              Log file
17  main    5432 online postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log

```
### Создаем тестовую базу и генерируем данные для теста
```
create database test;


su postgres -c 'pgbench -i --scale=40 --foreign-keys -h localhost -p 5432 -U postgres test'
dropping old tables...
NOTICE:  table "pgbench_accounts" does not exist, skipping
NOTICE:  table "pgbench_branches" does not exist, skipping
NOTICE:  table "pgbench_history" does not exist, skipping
NOTICE:  table "pgbench_tellers" does not exist, skipping
creating tables...
generating data (client-side)...
vacuuming...                                                                                 
creating primary keys...
creating foreign keys...
done in 92.22 s (drop tables 0.00 s, create tables 0.02 s, client-side generate 56.28 s, vacuum 0.19 s, primary keys 27.04 s, foreign keys 8.68 s).
```
### Создаем скрипт для тестирования и директорию для логов
```
mkdir /var/lib/postgresql/test_result

nano pgbench.sh 
#!/bin/bash
clients="1 10 20 50 100"
t=600
dir=/var/lib/postgresql/test_result
mkdir -p $dir
for c in $clients; do
echo "pgbench_${c}_${t}.txt"
echo "start test: "`date +"%Y.%m.%d_%H:%M:%S"` >> "${dir}/pgbench_${c}.txt"
pgbench -h -U postgres localhost -p 5432 test -c $c -j $c -T $t >> "${dir}/pgbench_${c}.txt"
echo "stop test: "`date +"%Y.%m.%d_%H:%M:%S"` >> "${dir}/pgbench_${c}.txt"
done

chmod +x pgbench.sh
```

### Запускаем с настройками postgresql по-умолчанию
```
# cat pgbench_1.txt
start test: 2025.07.24_03:57:18
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 1
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 93252
number of failed transactions: 0 (0.000%)
latency average = 6.434 ms
initial connection time = 5.948 ms
tps = 155.421497 (without initial connection time)
stop test: 2025.07.24_04:07:18

# cat pgbench_10.txt

pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 10
number of threads: 10
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 288596
number of failed transactions: 0 (0.000%)
latency average = 20.790 ms
initial connection time = 30.438 ms
tps = 481.008079 (without initial connection time)
stop test: 2025.07.24_04:17:19

# cat pgbench_20.txt

start test: 2025.07.24_04:17:19
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 20
number of threads: 20
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 372353
number of failed transactions: 0 (0.000%)
latency average = 32.226 ms
initial connection time = 60.177 ms
tps = 620.618997 (without initial connection time)
stop test: 2025.07.24_04:27:19

# cat pgbench_50.txt

pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 50
number of threads: 50
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 415033
number of failed transactions: 0 (0.000%)
latency average = 72.294 ms
initial connection time = 154.824 ms
tps = 691.624100 (without initial connection time)
stop test: 2025.07.24_04:37:20

# cat pgbench_100.txt

start test: 2025.07.24_04:37:20
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 100
number of threads: 100
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 400367
number of failed transactions: 0 (0.000%)
latency average = 149.986 ms
initial connection time = 433.523 ms
tps = 666.726831 (without initial connection time)
stop test: 2025.07.24_04:47:21
```

### Тюним:
```
shared_buffers = 256MB (было 128)
effective_cache_size = 1512MB
work_mem = 10MB
effective_io_concurrency = 200
random_page_cost = 1.1

# Применяем
systemctl restart postgresql@17-main

#Запускаем тест снова, смотрим результат

cat pgbench_1.txt 

start test: 2025.07.24_05:06:07
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 1
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 98449
number of failed transactions: 0 (0.000%)
latency average = 6.095 ms
initial connection time = 7.155 ms
tps = 164.069238 (without initial connection time)
stop test: 2025.07.24_05:16:07

cat pgbench_10.txt

start test: 2025.07.24_05:16:07
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 10
number of threads: 10
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 355900
number of failed transactions: 0 (0.000%)
latency average = 16.859 ms
initial connection time = 31.029 ms
tps = 593.164626 (without initial connection time)
stop test: 2025.07.24_05:26:07


cat pgbench_20.txt 
start test: 2025.07.24_05:26:07
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 20
number of threads: 20
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 407167
number of failed transactions: 0 (0.000%)
latency average = 29.482 ms
initial connection time = 58.406 ms
tps = 678.385571 (without initial connection time)
stop test: 2025.07.24_05:36:08

cat pgbench_50.txt 
start test: 2025.07.24_05:36:08
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 50
number of threads: 50
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 435366
number of failed transactions: 0 (0.000%)
latency average = 68.943 ms
initial connection time = 147.402 ms
tps = 725.235240 (without initial connection time)
stop test: 2025.07.24_05:46:09

cat pgbench_100.txt 

start test: 2025.07.24_05:46:09
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 100
number of threads: 100
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 429604
number of failed transactions: 0 (0.000%)
latency average = 139.657 ms
initial connection time = 305.905 ms
tps = 716.042261 (without initial connection time)
stop test: 2025.07.24_05:56:10
```

### Меняем настройки для увеличения производительности в ущерб стабильности
```
synchronous_commit = off 
effective_io_concurrency = 300
wal_level = minimal
seq_page_cost = 0.5
random_page_cost = 0.6
parallel_setup_cost = 10.0
default_statistics_target = 1000
max_wal_senders = 0

# Применяем и проверяем

cat pgbench_1.txt

start test: 2025.07.24_06:22:33
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 1
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 666979
number of failed transactions: 0 (0.000%)
latency average = 0.901 ms
initial connection time = 8.109 ms
tps = 1109.989057 (without initial connection time)
stop test: 2025.07.24_06:32:34


cat pgbench_10.txt

start test: 2025.07.24_06:32:34
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 10
number of threads: 10
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 702188
number of failed transactions: 0 (0.000%)
latency average = 8.550 ms
initial connection time = 31.352 ms
tps = 1169.558058 (without initial connection time)
stop test: 2025.07.24_06:42:35

cat pgbench_20.txt

start test: 2025.07.24_06:42:35
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 20
number of threads: 20
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 641882
number of failed transactions: 0 (0.000%)
latency average = 18.821 ms
initial connection time = 85.703 ms
tps = 1062.664036 (without initial connection time)
stop test: 2025.07.24_06:52:39

cat pgbench_50.txt

start test: 2025.07.24_06:52:39
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 50
number of threads: 50
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 586313
number of failed transactions: 0 (0.000%)
latency average = 51.171 ms
initial connection time = 152.299 ms
tps = 977.117709 (without initial connection time)
stop test: 2025.07.24_07:02:40

cat pgbench_100.txt


start test: 2025.07.24_07:02:40
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 40
query mode: simple
number of clients: 100
number of threads: 100
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 553806
number of failed transactions: 0 (0.000%)
latency average = 108.380 ms
initial connection time = 291.287 ms
tps = 922.681023 (without initial connection time)
stop test: 2025.07.24_07:12:41
```

### Из этого делаем выводы:
1. Самое большое количество tps при третьем типе настроек в 10 потоков (с учетом текущих ресурсов)
2. Самое оптимальное количество потоков на всех типах настроек (в среднем) - 50
3. Прирост производительности при третьем типе настроек - самый значительный
