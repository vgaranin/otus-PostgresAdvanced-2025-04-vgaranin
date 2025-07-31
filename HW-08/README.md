# Managed service for PostgreSQL YC

Устанавливаем cli согласно официальной документации

curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
...
yc init

Создаем кластер
```
yc managed-postgresql cluster create \
   --name my-postgresql-otus \
   --environment production \
   --network-id enp6bhqu3vs78358662p \
   --resource-preset s2.micro \
   --host zone-id=ru-central1-a,subnet-id=e9b6add2d1qm9ksdo8aa,assign-public-ip \
   --disk-type network-ssd \
   --disk-size 10 \
   --user name=user,password=user1user1 \
   --database name=user,owner=user \
   --postgresql-version 17 --async

```

Подключаемся, проверяем
```
mkdir -p ~/.postgresql && \
wget "https://storage.yandexcloud.net/cloud-certs/CA.pem" \
    --output-document ~/.postgresql/root.crt && \
chmod 0600 ~/.postgresql/root.crt

psql "host=rc1a-lsf3kqr6k80j7la4.mdb.yandexcloud.net \
    port=6432 \
    sslmode=verify-full \
    dbname=user \
    user=user \
    target_session_attrs=read-write"

user=> SELECT version();
                                                                     version                                                                     
-------------------------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 17.5 (Ubuntu 17.5-201-yandex.59510.7fea32f73d) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0, 64-bit
(1 строка)

user=> 
```