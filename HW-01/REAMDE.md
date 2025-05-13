### Создаем ВМ в Яндекс облаке, добавляем свой ключ и подключаемся
```
ssh -i ~/.ssh/yc vgaranin@51.250.121.18
```

### Установка и настройка Postgres:
```
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql && sudo apt install unzip && sudo apt -y install mc


root@compute-vm-2-2-10-ssd-1747110640170:~# pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
17  main    5432 online postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log

nano /etc/postgresql/17/main/postgresql.conf 
listen_addresses = '*'

su postgres -c 'psql'

nano /etc/postgresql/17/main/pg_hba.conf 
hostssl all             all        0.0.0.0/0               scram-sha-256

su postgres -c 'psql'
\password
\d

systemctl restart postgresql@17-main

psql -U postgres -d postgres -h 51.250.121.18
```

# уровни изоляции транзакций
### Подключаемся, отключаем автокоммит, создаем таблицу для тестов

#\set AUTOCOMMIT OFF

#### 1
```
postgres=# create table shipments(id serial, product_name text, quantity int, destination text);
CREATE TABLE
postgres=*# insert into shipments(product_name, quantity, destination) values('bananas', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('coffee', 500, 'USA');
commit;
INSERT 0 1
INSERT 0 1
COMMIT

show transaction isolation level;
transaction_isolation 
+-----------------------
 read committed
```
### В первой сессии добавляем новую запись
```
insert into shipments(product_name, quantity, destination) values('sugar', 300, 'Asia');
```

#### Во второй сессии проверяем строки
```
postgres=# select * from shipments;
 id | product_name | quantity | destination 
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
(2 rows)
```
Новых данных нет, так как в первой сессии транзакция не была завершена.

#### Выполняем commit в первой сессии
```
commit;
```
#### Проверяем данные во второй сессии
```
postgres=*# select * from shipments;
 id | product_name | quantity | destination 
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
(3 rows)
```
Новые данные появились, потому что транзакция во второй сессии была открыта позже первой, и при завершении транзакции в первой сессии изменения стали доступны для второй сессии (при уне ровизоляции "read commited)

## set transaction isolation level repeatable read;
На обеих сессиях выполняем
```
set transaction isolation level repeatable read;
show transaction isolation level;
 transaction_isolation 
+-----------------------
 repeatable read
```
#### В первой сессии добавляем новую строку
insert into shipments(product_name, quantity, destination) values('bananas', 2000, 'Africa');

#### Проверяем данные во второй сессии
```
postgres=# select * from shipments;
 id | product_name | quantity | destination 
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
(3 rows)
```
Новой строки не видно, потому что при "repeatable read" при открытии второй транзакции ей доступны данные такого снимка данных, который был на момент открытия транзакции.

#### В первой сессии делаем commit
```
commit;
```
#### Проверяем данные во второй сессии
```
postgres=# select * from shipments;
 id | product_name | quantity | destination 
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
(3 rows)
```

Данных нет, потому что, так как было описано выше, при открытии второй транзакции ей доступны данные такого снимка данных, который был на момент открытия транзакции, вне зависимости от того был commit более ранней транзакции, или нет


#### Выполняем commit во второй сессии и проверяем данные
```
postgres=# select * from shipments;
 id | product_name | quantity | destination 
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
  5 | bananas      |     2000 | Africa
(4 rows)
```
Данные появились, потому что после завершения транзакции во второй сессии нам стал доступен свежий снимок данных и мы можем увидеть все изменения.