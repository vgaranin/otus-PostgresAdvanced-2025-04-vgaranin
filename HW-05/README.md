### В Яндекс облаке создаем 3 виртуальные машины
#### Устанавливаем пакеты postgresql для мастера и реплики
```
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql && sudo apt install unzip && sudo apt -y install mc
```
#### Настраиваем мастер
```
nano /etc/postgresql/17/main/postgresql.conf
listen_addresses = '*'

nano /etc/postgresql/17/main/pg_hba.conf

hostssl replication replicator 0.0.0.0/0 scram-sha-256

systemctl restart postgresql@17-main

 create role replicator with replication login password 'password';
```

#### На ВМ с репликой устанавливаем wal-g, настраиваем и разворачиваем реплику.

Так как ОС на ВМ Ubuntu 24.04, а на гитхабе есть готовые бинарники максимум для 22.04, собираем самостоятельно. В рамках задачи бэкапы будем снимать локально
```
# Install latest Go compiler
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt update
sudo apt install golang-go

# Install lib dependencies
sudo apt install libbrotli-dev liblzo2-dev libsodium-dev curl cmake brotli

# Fetch project and build
git clone https://github.com/wal-g/wal-g $(go env GOPATH)/src/github.com/wal-g/wal-g

cd $(go env GOPATH)/src/github.com/wal-g/wal-g

# optional exports
export USE_BROTLI=1


make deps
make pg_build
main/pg/wal-g --version
mv main/pg/wal-g /usr/bin/wal-g

mkdir /etc/wal-g

cat > /etc/wal-g/.config.json << EOF
{
    "WALG_FILE_PREFIX": "/tmp/backup",
    "WALG_DELTA_MAX_STEPS": "0",
    "PGDATA": "/var/lib/posetgresql/17/main",
    "PGHOST": "localhost"
}
EOF

mkdir /tmp/backup
chown postgres:postgres /tmp/backup
mkdir /var/log/wal-g
chown postgres:postgres /var/log/wal-g
touch /var/log/wal-g/wal_g_archive_command.log
chown postgres:postgres /var/log/wal-g/wal_g_archive_command.log
```
### Настраиваем архивирование журналов на одной из реплик (в рамках данной задачи)
```
touch /etc/postgresql/17/main/conf.d/backup.conf
chown postgres:postgres /etc/postgresql/17/main/conf.d/backup.conf 


nano /etc/postgresql/17/main/conf.d/backup.conf
archive_mode = always
archive_command = 'wal-g --config=/etc/wal-g/.config.json wal-push \"%p\" >> /var/log/wal-g/wal_g_archive_command.log 2>&1'

nano /etc/postgresql/17/main/postgresql.conf
listen_addresses = '*'

nano /etc/postgresql/17/main/pg_hba.conf
host all all 127.0.0.1/32 trust 

rm -rf /var/lib/postgresql/17/main

su postgres -c 'pg_basebackup -U replicator -h 10.128.0.7 -c fast -Xs -v -R -D /var/lib/postgresql/17/main' && systemctl start postgresql@17-main
```

#### Проверяем
```
postgres=# \x
Expanded display is on.
postgres=# select * from pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
pid              | 10012
usesysid         | 16388
usename          | replicator
application_name | 17/main
client_addr      | 10.128.0.4
client_hostname  | 
client_port      | 51164
backend_start    | 2025-06-21 09:22:00.838694+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/3000060
write_lsn        | 0/3000060
flush_lsn        | 0/3000060
replay_lsn       | 0/3000060
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2025-06-21 09:23:00.869177+00
```
#### Заходим в postgres и создаем таблицу с данными (берем из предыдущего урока)
```
su postgres -c 'psql'
create table shipments(id serial, product_name text, quantity int, destination text);
insert into shipments(product_name, quantity, destination) values('bananas', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('bananas', 1500, 'Asia');
insert into shipments(product_name, quantity, destination) values('bananas', 2000, 'Africa');
insert into shipments(product_name, quantity, destination) values('coffee', 500, 'USA');
insert into shipments(product_name, quantity, destination) values('coffee', 700, 'Canada');
insert into shipments(product_name, quantity, destination) values('coffee', 300, 'Japan');
insert into shipments(product_name, quantity, destination) values('sugar', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('sugar', 800, 'Asia');
insert into shipments(product_name, quantity, destination) values('sugar', 600, 'Africa');
insert into shipments(product_name, quantity, destination) values('sugar', 400, 'USA');
```

Так как изменений немного, принудительно вызовем checkpoint и сменим wal файл на мастере
```
checkpoint;
select pg_switch_wal();
```
снимаем бэкап с реплики
```
su postgres -c 'wal-g --config=/etc/wal-g/.config.json backup-push /var/lib/postgresql/17/main'

su postgres -c 'wal-g --config=/etc/wal-g/.config.json backup-list'
```

 копируем настройки кластера и меняем параметры для запуска развернутого бэкапа
```
cp -r /etc/postgresql/17/main /etc/postgresql/17/main2

rm /etc/postgresql/17/main2/conf.d/backup.conf

nano /etc/postgresql/17/main2/postgresql.conf
data_directory = '/var/lib/postgresql/17/main2'  
port = 5433
restore_command = 'wal-g --config=/etc/wal-g/.config.json wal-fetch \"%p\"'
recovery_target = 'immediate'
```
Разворачиваем бэкап в другую директорию, рядом с работающей репликой
```
su postgres -c 'wal-g --config=/etc/wal-g/.config.json backup-fetch /var/lib/postgresql/17/main2 LATEST'
su postgres -c 'touch /var/lib/postgresql/17/main2/recovery.signal'
```
запускаем, проверяем
```
systemctl start postgresql@17-main2

root@postgres3:/var/lib/postgresql/17# pg_isready -p 5433
/var/run/postgresql:5433 - accepting connections

postgres=# select * from shipments;
 id | product_name | quantity | destination 
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | bananas      |     1500 | Asia
  3 | bananas      |     2000 | Africa
  4 | coffee       |      500 | USA
  5 | coffee       |      700 | Canada
  6 | coffee       |      300 | Japan
  7 | sugar        |     1000 | Europe
  8 | sugar        |      800 | Asia
  9 | sugar        |      600 | Africa
 10 | sugar        |      400 | USA
(10 rows)
```
Бэкап восстановлен.