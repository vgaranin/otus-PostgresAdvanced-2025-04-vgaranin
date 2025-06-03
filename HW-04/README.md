### 1 В Яндекс облаке создаем 3 виртуальные машины для etcd, 3 виртуальные машины для Patroni и одну для HAProxy
### 2 Установка и настройка кластера  patroni-postgres:
#### Устанавливаем пакеты postgresql
```
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql && sudo apt install unzip && sudo apt -y install mc
```

#### Останавливаем postgresql на всех нодах, настраиваем конфигурацию, на будущих репликах чистим раздел
```
systemctl stop postgresql@17-main

nano /etc/postgresql/17/main/postgresql.conf

listen_addresses = '*'
wal_keep_size = 1GB

nano /etc/postgresql/17/main/pg_hba.conf

host    all             all             0.0.0.0/0            scram-sha-256
host    replication     all             0.0.0.0/0            scram-sha-256
```
Устанавливаем патрони

### Устанавливаем etcd
```
cd /tmp
wget https://github.com/etcd-io/etcd/releases/download/v3.5.5/etcd-v3.5.5-linux-amd64.tar.gz
tar xzvf etcd-v3.5.5-linux-amd64.tar.gz
sudo mv /tmp/etcd-v3.5.5-linux-amd64/etcd* /usr/local/bin/
sudo groupadd --system etcd
sudo useradd -s /sbin/nologin --system -g etcd etcd
mkdir /opt/etcd
mkdir /etc/etcd
mkdir /var/lib/etcd
chown -R etcd:etcd /opt/etcd /var/lib/etcd /etc/etcd
chmod -R 700 /opt/etcd/ /var/lib/etcd /etc/etcd

nano /etc/etcd/etcd.conf

# Текст конфига для:

ETCD_NAME="etcd1"
ETCD_LISTEN_CLIENT_URLS="http://10.128.0.12:2379,http://127.0.0.1:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://10.128.0.12:2379"
ETCD_LISTEN_PEER_URLS="http://10.128.0.12:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.128.0.12:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-postgres-cluster"
ETCD_INITIAL_CLUSTER="etcd1=http://10.128.0.12:2380,etcd2=http://10.128.0.22:2380,etcd3=http://10.128.0.7:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_ELECTION_TIMEOUT="10000"
ETCD_HEARTBEAT_INTERVAL="2000"
ETCD_INITIAL_ELECTION_TICK_ADVANCE="false"
ETCD_ENABLE_V2="true"

# Текст конфига для etcd2:
ETCD_NAME="etcd2"
ETCD_LISTEN_CLIENT_URLS="http://10.128.0.22:2379,http://127.0.0.1:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://10.128.0.22:2379"
ETCD_LISTEN_PEER_URLS="http://10.128.0.22:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.128.0.22:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-postgres-cluster"
ETCD_INITIAL_CLUSTER="etcd1=http://10.128.0.12:2380,etcd2=http://10.128.0.22:2380,etcd3=http://10.128.0.7:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_ELECTION_TIMEOUT="10000"
ETCD_HEARTBEAT_INTERVAL="2000"
ETCD_INITIAL_ELECTION_TICK_ADVANCE="false"
ETCD_ENABLE_V2="true"

# Текст конфига для etcd3:
ETCD_NAME="etcd3"
ETCD_LISTEN_CLIENT_URLS="http://10.128.0.7:2379,http://127.0.0.1:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://10.128.0.7:2379"
ETCD_LISTEN_PEER_URLS="http://10.128.0.7:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.128.0.7:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-postgres-cluster"
ETCD_INITIAL_CLUSTER="etcd1=http://10.128.0.12:2380,etcd2=http://10.128.0.22:2380,etcd3=http://10.128.0.7:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_ELECTION_TIMEOUT="10000"
ETCD_HEARTBEAT_INTERVAL="2000"
ETCD_INITIAL_ELECTION_TICK_ADVANCE="false"
ETCD_ENABLE_V2="true"
```

#### Далее на каждой ноде делаем etcd службой (конфиг одинаковый):
```
nano /etc/systemd/system/etcd.service
# Текст конфига:
[Unit]
Description=Etcd Server
Documentation=https://github.com/etcd-io/etcd
After=network.target
After=network-online.target
Wants=network-online.target
  
[Service]
User=etcd
Type=notify
#WorkingDirectory=/var/lib/etcd/
WorkingDirectory=/opt/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
User=etcd
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/local/bin/etcd"
Restart=on-failure
LimitNOFILE=65536
IOSchedulingClass=realtime
IOSchedulingPriority=0
Nice=-20
 
[Install]
WantedBy=multi-user.target
```

#### Далее настраиваем автозапуск службы etcd и ее запускаем:
```
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
```
#### Проверяем
```
root@etcd1:/tmp# ETCDCTL_API=2 etcdctl member list
3c0f2eb245e8a215: name=etcd3 peerURLs=http://10.128.0.7:2380 clientURLs=http://10.128.0.7:2379 isLeader=true
58ce3665ad3c25ca: name=etcd1 peerURLs=http://10.128.0.12:2380 clientURLs=http://10.128.0.12:2379 isLeader=false
73c242124262cace: name=etcd2 peerURLs=http://10.128.0.22:2380 clientURLs= isLeader=false

root@etcd1:/tmp# etcdctl endpoint health --cluster -w table
+-------------------------+--------+------------+-------+
|        ENDPOINT         | HEALTH |    TOOK    | ERROR |
+-------------------------+--------+------------+-------+
|  http://10.128.0.7:2379 |   true | 2.838574ms |       |
| http://10.128.0.22:2379 |   true | 2.397512ms |       |
| http://10.128.0.12:2379 |   true | 2.365909ms |       |
+-------------------------+--------+------------+-------+
root@etcd1:/tmp# 

```
### Установка Patroni
#### Устанавливаем пакеты для работы с Python:
```
apt -y install python3 python3-pip python3-dev python3-psycopg2 libpq-dev
# Через PIP ставим пакеты Python:
pip3 install psycopg2 --break-system-packages
pip3 install psycopg2-binary --break-system-packages
pip3 install patroni --break-system-packages
pip3 install python-etcd --break-system-packages

# Создаем каталог конфигов Patroni:
mkdir /etc/patroni/
# Создаем файл конфигурации Patroni:

nano /etc/patroni/patroni.yml
Текст patroni.yml для первой ноды (pg1):
scope: postgres-cluster # одинаковое значение на всех узлах
name: pg1 # разное значение на всех узлах
namespace: /service/ # одинаковое значение на всех узлах

restapi:
  listen: 10.128.0.8:8008 # разное значение на всех узлах
  connect_address: 10.128.0.8:8008 # разное значение на всех узлах
  authentication:
    username: patroni
    password: 'password'

etcd:
  hosts: 10.128.0.12:2379, 10.128.0.22:2379, 10.128.0.7:2379 # список всех узлов, на которых установлен etcd

bootstrap:
  method: initdb
  dcs:
    ttl: 60
    loop_wait: 10
    retry_timeout: 27
    maximum_lag_on_failover: 2048576
    master_start_timeout: 300
    synchronous_mode: true
    synchronous_mode_strict: false
    synchronous_node_count: 1
    # standby_cluster:
      # host: 127.0.0.1
      # port: 1111
      # primary_slot_name: patroni
    postgresql:
      use_pg_rewind: false
      use_slots: true
      parameters:
        max_connections: 100

  initdb:  # List options to be passed on to initdb
    - encoding: UTF8
    - locale: en_US.UTF-8
    - data-checksums

  pg_hba:  # должен содержать адреса ВСЕХ машин, используемых в кластере
    - host all all 0.0.0.0/0 scram-sha-256
    - host replication replicator scram-sha-256

postgresql:
  listen: 10.128.0.8,127.0.0.1:5432 # разное значение на всех узлах
  connect_address: 10.128.0.8:5432 # разное значение на всех узлах
  use_unix_socket: true
  data_dir: /var/lib/postgresql/17/main
  bin_dir: /usr/lib/postgresql/17/bin
  config_dir: /etc/postgresql/17/main
  pgpass: /var/lib/postgresql/.pgpass_patroni
  authentication:
    replication:
      username: replicator
      password: password
    superuser:
      username: postgres
      password: password
  parameters:
    unix_socket_directories: /var/run/postgresql
    stats_temp_directory: /var/lib/pgsql_stats_tmp

  remove_data_directory_on_rewind_failure: false
  remove_data_directory_on_diverged_timelines: false

#  callbacks:
#    on_start:
#    on_stop:
#    on_restart:
#    on_reload:
#    on_role_change:

  create_replica_methods:
    - basebackup
  basebackup:
    max-rate: '100M'
    checkpoint: 'fast'

watchdog:
  mode: off  # Allowed values: off, automatic, required
  device: /dev/watchdog
  safety_margin: 5

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false

  # specify a node to replicate from (cascading replication)
#  replicatefrom: (node name)

Для второй ноды (pg02):

scope: postgres-cluster # одинаковое значение на всех узлах
name: pg02 # разное значение на всех узлах
namespace: /service/ # одинаковое значение на всех узлах

restapi:
  listen: 10.128.0.35:8008 # разное значение на всех узлах
  connect_address: 10.128.0.35:8008 # разное значение на всех узлах
  authentication:
    username: patroni
    password: 'password'

etcd:
  hosts: 10.128.0.12:2379, 10.128.0.22:2379, 10.128.0.7:2379 # список всех узлов, на которых установлен etcd

bootstrap:
  method: initdb
  dcs:
    ttl: 60
    loop_wait: 10
    retry_timeout: 27
    maximum_lag_on_failover: 2048576
    master_start_timeout: 300
    synchronous_mode: true
    synchronous_mode_strict: false
    synchronous_node_count: 1
    # standby_cluster:
      # host: 127.0.0.1
      # port: 1111
      # primary_slot_name: patroni
    postgresql:
      use_pg_rewind: false
      use_slots: true
      parameters:
        max_connections: 100

  initdb:  # List options to be passed on to initdb
    - encoding: UTF8
    - locale: en_US.UTF-8
    - data-checksums

  pg_hba:  # должен содержать адреса ВСЕХ машин, используемых в кластере
    - host all all 0.0.0.0/0 scram-sha-256
    - host replication replicator scram-sha-256

postgresql:
  listen: 10.128.0.35,127.0.0.1:5432 # разное значение на всех узлах
  connect_address: 10.128.0.35:5432 # разное значение на всех узлах
  use_unix_socket: true
  data_dir: /var/lib/postgresql/17/main
  bin_dir: /usr/lib/postgresql/17/bin
  config_dir: /etc/postgresql/17/main
  pgpass: /var/lib/postgresql/.pgpass_patroni
  authentication:
    replication:
      username: replicator
      password: password
    superuser:
      username: postgres
      password: password
  parameters:
    unix_socket_directories: /var/run/postgresql
    stats_temp_directory: /var/lib/pgsql_stats_tmp

  remove_data_directory_on_rewind_failure: false
  remove_data_directory_on_diverged_timelines: false

#  callbacks:
#    on_start:
#    on_stop:
#    on_restart:
#    on_reload:
#    on_role_change:

  create_replica_methods:
    - basebackup
  basebackup:
    max-rate: '100M'
    checkpoint: 'fast'

watchdog:
  mode: off  # Allowed values: off, automatic, required
  device: /dev/watchdog
  safety_margin: 5

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false

  # specify a node to replicate from (cascading replication)
#  replicatefrom: (node name)
На третьей ноде (pg03):

scope: postgres-cluster # одинаковое значение на всех узлах
name: pg03 # разное значение на всех узлах
namespace: /service/ # одинаковое значение на всех узлах

restapi:
  listen: 10.128.0.16:8008 # разное значение на всех узлах
  connect_address: 10.128.0.16:8008 # разное значение на всех узлах
  authentication:
    username: patroni
    password: 'password'

etcd:
  hosts: 10.128.0.12:2379, 10.128.0.22:2379, 10.128.0.7:2379 # список всех узлов, на которых установлен etcd

bootstrap:
  method: initdb
  dcs:
    ttl: 60
    loop_wait: 10
    retry_timeout: 27
    maximum_lag_on_failover: 2048576
    master_start_timeout: 300
    synchronous_mode: true
    synchronous_mode_strict: false
    synchronous_node_count: 1
    # standby_cluster:
      # host: 127.0.0.1
      # port: 1111
      # primary_slot_name: patroni
    postgresql:
      use_pg_rewind: false
      use_slots: true
      parameters:
        max_connections: 100

  initdb:  # List options to be passed on to initdb
    - encoding: UTF8
    - locale: en_US.UTF-8
    - data-checksums

  pg_hba:  # должен содержать адреса ВСЕХ машин, используемых в кластере
    - host all all 0.0.0.0/0 scram-sha-256
    - host replication replicator scram-sha-256

postgresql:
  listen: 10.128.0.16,127.0.0.1:5432 # разное значение на всех узлах
  connect_address: 10.128.0.16:5432 # разное значение на всех узлах
  use_unix_socket: true
  data_dir: /var/lib/postgresql/17/main
  bin_dir: /usr/lib/postgresql/17/bin
  config_dir: /etc/postgresql/17/main
  pgpass: /var/lib/postgresql/.pgpass_patroni
  authentication:
    replication:
      username: replicator
      password: password
    superuser:
      username: postgres
      password: password
  parameters:
    unix_socket_directories: /var/run/postgresql
    stats_temp_directory: /var/lib/pgsql_stats_tmp

  remove_data_directory_on_rewind_failure: false
  remove_data_directory_on_diverged_timelines: false

#  callbacks:
#    on_start:
#    on_stop:
#    on_restart:
#    on_reload:
#    on_role_change:

  create_replica_methods:
    - basebackup
  basebackup:
    max-rate: '100M'
    checkpoint: 'fast'

watchdog:
  mode: off  # Allowed values: off, automatic, required
  device: /dev/watchdog
  safety_margin: 5

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false

  # specify a node to replicate from (cascading replication)
#  replicatefrom: (node name)
```

#### Далее — назначаем права на каждой ноде:
```
chown postgres:postgres -R /etc/patroni
chmod 700 /etc/patroni
mkdir /var/lib/pgsql_stats_tmp
chown postgres:postgres /var/lib/pgsql_stats_tmp
```

#### Определяем Patroni как службу (на всех трех нодах одинаково):
```
nano /etc/systemd/system/patroni.service

[Unit]
Description=High availability PostgreSQL Cluster
After=syslog.target network.target

[Service]
Type=simple
User=postgres
Group=postgres

# Read in configuration file if it exists, otherwise proceed
EnvironmentFile=-/etc/patroni_env.conf

# Start the patroni process
ExecStart=/usr/local/bin/patroni /etc/patroni/patroni.yml

# Send HUP to reload from patroni.yml
ExecReload=/bin/kill -s HUP $MAINPID

# only kill the patroni process, not it's children, so it will gracefully stop postgres
KillMode=process

# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=60

# Do not restart the service if it crashes, we want to manually inspect database on failure
Restart=no

[Install]
WantedBy=multi-user.target
```
Переводим Patroni в автозапуск, запускаем и проверяем:
```
systemctl daemon-reload
systemctl enable patroni
systemctl start patroni
systemctl status patroni
Просмотреть состояние кластера можно командой
```
#### Проверяем
```
root@pg1:/var/lib/postgresql/17# patronictl -c /etc/patroni/patroni.yml list
+ Cluster: postgres-cluster (7510532703728824409) +----+-----------+
| Member | Host        | Role         | State     | TL | Lag in MB |
+--------+-------------+--------------+-----------+----+-----------+
| pg02   | 10.128.0.35 | Sync Standby | streaming |  1 |         0 |
| pg03   | 10.128.0.16 | Replica      | streaming |  1 |         0 |
| pg1    | 10.128.0.8  | Leader       | running   |  1 |           |
+--------+-------------+--------------+-----------+----+-----------+
```

### Установка HAProxy
Производится на компьютере HA. Выполняется от пользователя root
```
# Устанавливаем HAProxy:
apt -y install haproxy
# Сохраняем исходный файл конфигурации:
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.origin
# Создаем новый файл конфигурации:
nano /etc/haproxy/haproxy.cfg

global

        maxconn 10000
        log     127.0.0.1 local2

defaults
        log global
        mode tcp
        retries 2
        timeout client 30m
        timeout connect 4s
        timeout server 30m
        timeout check 5s

listen stats
    mode http
    bind *:7000
    stats enable
    stats uri /

listen postgres
    bind *:7432
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server node1 10.128.0.8:5432 maxconn 100 check port 8008
    server node2 10.128.0.16:5432 maxconn 100 check port 8008
    server node3 10.128.0.35:5432 maxconn 100 check port 8008
Далее перезагружаем HAProxy:
sudo systemctl restart haproxy
и проверяем работоспособность:
sudo systemctl status haproxy
```

#### заходим на мастер, создаем пользователя для подключения
```
create role test with login password 'password';

Для проверки можно подключиться через psql на IP-адрес HAProxy к порту 7432.

psql -U test -h 158.160.101.30 -p 7432 -d postgres
Password for user test: 
psql (14.18 (Homebrew), server 17.5 (Ubuntu 17.5-1.pgdg24.04+1))
WARNING: psql major version 14, server major version 17.
         Some psql features might not work.
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

postgres=> 
```

### 4 Выключаем сервер мастера, чтобы удостовериться в работе  failover'a
```
root@pg2:~# patronictl -c /etc/patroni/patroni.yml list
+ Cluster: postgres-cluster (7510532703728824409) +----+-----------+
| Member | Host        | Role         | State     | TL | Lag in MB |
+--------+-------------+--------------+-----------+----+-----------+
| pg02   | 10.128.0.35 | Leader       | running   |  2 |           |
| pg03   | 10.128.0.16 | Sync Standby | streaming |  2 |         0 |
+--------+-------------+--------------+-----------+----+-----------+
```
#### Включаем обратно и проверяем, что узел подключился
```
root@pg1:~# patronictl -c /etc/patroni/patroni.yml list
+ Cluster: postgres-cluster (7510532703728824409) +----+-----------+
| Member | Host        | Role         | State     | TL | Lag in MB |
+--------+-------------+--------------+-----------+----+-----------+
| pg02   | 10.128.0.35 | Leader       | running   |  3 |           |
| pg03   | 10.128.0.16 | Sync Standby | streaming |  3 |         0 |
| pg1    | 10.128.0.8  | Replica      | running   |  2 |         0 |
+--------+-------------+--------------+-----------+----+-----------+
```

### 5 Настраиваем бэкапы

#### Устанавливаем и настраиваем wal-g. 
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

mkdir /var/log/wal-g
chown postgres:postgres /var/log/wal-g
touch /var/log/wal-g/wal_g_archive_command.log
chown postgres:postgres /var/log/wal-g/wal_g_archive_command.log

# Настраиваем архивирование журналов на одной из реплик (в рамках данной задачи)

touch /etc/postgresql/17/main/conf.d/backup.conf
chown postgres:postgres /etc/postgresql/17/main/conf.d/backup.conf 


nano /etc/postgresql/17/main/conf.d/backup.conf
archive_mode = always
archive_command = 'wal-g --config=/etc/wal-g/.config.json wal-push \"%p\" >> /var/log/wal-g/wal_g_archive_command.log 2>&1'

#Применяем настройки, проверяем
systemctl restart patroni

su postgres -c 'psql'
\x
select * from pg_settings where name in ('archive_mode', 'archive_command');
-[ RECORD 1 ]---+------------------------------------------------------------------------------------------------------
name            | archive_command
setting         | wal-g --config=/etc/wal-g/.config.json wal-push "%p" >> /var/log/wal-g/wal_g_archive_command.log 2>&1
unit            | 
category        | Write-Ahead Log / Archiving
short_desc      | Sets the shell command that will be called to archive a WAL file.
extra_desc      | This is used only if "archive_library" is not set.
context         | sighup
vartype         | string
source          | configuration file
min_val         | 
max_val         | 
enumvals        | 
boot_val        | 
reset_val       | wal-g --config=/etc/wal-g/.config.json wal-push "%p" >> /var/log/wal-g/wal_g_archive_command.log 2>&1
sourcefile      | /etc/postgresql/17/main/conf.d/backup.conf
sourceline      | 2
pending_restart | f
-[ RECORD 2 ]---+------------------------------------------------------------------------------------------------------
name            | archive_mode
setting         | always
unit            | 
category        | Write-Ahead Log / Archiving
short_desc      | Allows archiving of WAL files using "archive_command".
extra_desc      | 
context         | postmaster
vartype         | enum
source          | configuration file
min_val         | 
max_val         | 
enumvals        | {always,on,off}
boot_val        | off
reset_val       | always
sourcefile      | /etc/postgresql/17/main/conf.d/backup.conf
sourceline      | 1
pending_restart | f
```
#### Снимаем бэкап и проверяем
```
su postgres -c 'wal-g --config=/etc/wal-g/.config.json backup-push /var/lib/postgresql/17/main'
su postgres -c 'wal-g --config=/etc/wal-g/.config.json backup-list'

INFO: 2025/06/03 04:21:59.857065 List backups from storages: [default]
backup_name                   modified             wal_file_name            storage_name
base_000000030000000000000007 2025-06-03T04:21:40Z 000000030000000000000007 default
root@pg1:~# 
```
#### Проверяем архивирование журналов
```
На мастере выполняем
postgres=# select pg_switch_wal();
На реплике проверяем
root@pg1:/etc/postgresql/17/main# su postgres -c 'wal-g --config=/etc/wal-g/.config.json wal-show'
+-----+------------+-----------------+--------------------------+--------------------------+---------------+----------------+--------+---------------+
| TLI | PARENT TLI | SWITCHPOINT LSN | START SEGMENT            | END SEGMENT              | SEGMENT RANGE | SEGMENTS COUNT | STATUS | BACKUPS COUNT |
+-----+------------+-----------------+--------------------------+--------------------------+---------------+----------------+--------+---------------+
|   3 |          0 |             0/0 | 000000030000000000000007 | 000000030000000000000007 |             1 |              1 | OK     |             1 |
+-----+------------+-----------------+--------------------------+--------------------------+---------------+----------------+--------+---------------+
root@pg1:/etc/postgresql/17/main# 
```
