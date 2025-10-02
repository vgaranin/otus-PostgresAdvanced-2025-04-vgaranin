# Отказоустойчивый кластер PostgreSQL
Что должно быть:
- Patroni
- PostgreSQL 17 версии
- etcd
- HAProxy
- KVM


#### Собираем образ patroni
```
cd Project/patroni
docker build -t patroni:17.6 .
```
#### Собираем haproxy+keepalived образ
```
cd ../
docker compose build
```
#### Создаем сеть
```
docker network create --subnet=10.10.0.0/24 otus-net
```

#### Создаем директории для данных patroni в текущей папке
```
mkdir -p data/postgres{1,2,3}
```
#### Устанавливаем владельца и права
```
sudo chown -R 999:999 data/postgres*
sudo chmod 700 data/postgres*
```

#### Проверяем права
```
ls -la data/   
```

Запускаем
```
docker compose up -d
```

### Подключение:
```
psql -h localhost -p 5001 -U postgres
```