Отказоустойчивый кластер PostgreSQL
Что должно быть:
- Patroni
- PostgreSQL 17 версии
- etcd
- HAProxy
- KVM
- 

Собрал образ patroni
docker build -t patroni:17.6 .

docker network create --subnet=10.10.0.0/24 otus-net


# Создаем директории для данных patroni в текущей папке
mkdir -p data/postgres{1,2,3}

# Устанавливаем владельца и права
sudo chown -R 999:999 data/postgres*
sudo chmod 700 data/postgres*

# Проверяем права
ls -la data/   



Подключение:

psql -h 10.10.0.100 -p 5432 -U postgres


→ всегда мастер.

psql -h 10.10.0.100 -p 5433 -U postgres


→ баланс по репликам.

Проверка Patroni:

curl 10.10.0.11:8008


Проверка VIP:

docker exec keepalived1 ip addr show eth0

-----
# Проверим статус кластера через Patroni REST API
curl http://10.10.0.11:8008 | jq '{role, state, server_version}'

# Или через patronictl
docker exec patroni1 patronictl list

# Проверим все узлы
curl -s http://10.10.0.11:8008/cluster | jq .


patronictl -c /etc/patroni.yml list
+ Cluster: postgres-cluster (7556212381037924373) -+-------------+-----+------------+-----+
| Member   | Host       | Role    | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+----------+------------+---------+-----------+----+-------------+-----+------------+-----+
| patroni1 | 10.10.0.11 | Leader  | running   |  3 |             |     |            |     |
| patroni2 | 10.10.0.12 | Replica | streaming |  3 |   0/70337A0 |   0 |  0/70337A0 |   0 |
| patroni3 | 10.10.0.13 | Replica | streaming |  3 |   0/70337A0 |   0 |  0/70337A0 |   0 |
+----------+------------+---------+-----------+----+-------------+-----+------------+-----+