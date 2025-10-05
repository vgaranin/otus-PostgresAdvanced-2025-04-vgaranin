# Сравнение PostgreSQL с Clickhouse

Для сравнения с postgresql выбрал clickhouse, т.к. он набирает популярность в качестве инструмента для хранения данных для аналитики.
В качестве тестового набора данных взял демонстрационную базу
https://postgrespro.ru/education/demodb

Тестирование произведено на ПК с postgresql и clickhouse standalone, развернутых в docker

В postgres был загружен через sql скрипт. Время загрузки ~ 1,5мин
Загрузка в clickhouse заняла около 30 секунд (через copy)

После замера времени выполнения запросов на postgres была произведена загрузка данных в clickhouse. Основной проблемой была несовместимость типов данных, поэтому было необходимо преобразовыывть данные (например, типы дат)

По результатам сравнительного анлиза одинаковых запросов было выявлено, что c select запросами clickhouse справляется быстрее, данные хранятся компактней. Но у него есть недостатки в виде меньшего количества типов данных "из коробки" и необходимости преобразования данных при миграции.

Так же 

Ниже немного статистики запросов, на основе которых были сделаны выводы выше:


### Postgresql - размер и запросы
```
postgres=# select pg_size_pretty(pg_database_size('demo'));
 pg_size_pretty 
----------------
 11 GB
(1 строка)

select count(*) from tickets where outbound = 't';
  count   
----------
 13558220
(1 строка)

Время: 423,714 мс

SELECT
    s.airplane_code,
    string_agg (s.fare_conditions || '(' || s.num || ')', ', ') as fare_conditions
FROM (
        SELECT airplane_code, fare_conditions, count(*)::text as num
        FROM seats
        GROUP BY airplane_code, fare_conditions
     ) s
GROUP BY s.airplane_code
ORDER BY s.airplane_code;
 airplane_code |             fare_conditions             
---------------+-----------------------------------------
 32N           | Business(28), Economy(138)
 339           | Business(29), Economy(224), Comfort(28)
 351           | Economy(281), Business(44)
 77W           | Economy(326), Business(30), Comfort(48)
 789           | Economy(188), Business(48), Comfort(21)
 7M7           | Business(16), Economy(144)
 CR7           | Business(6), Economy(52), Comfort(12)
 E70           | Business(6), Economy(72)
(8 строк)

Время: 10,134 мс

SELECT
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
(7 строк)

Время: 27,522 мс

explain SELECT
    status,
    count(*) as count,
    min(scheduled_departure) as min_scheduled_departure,
    max(scheduled_departure) as max_scheduled_departure
FROM flights
GROUP BY status
ORDER BY min_scheduled_departure;
                                              QUERY PLAN                                              
------------------------------------------------------------------------------------------------------
 Sort  (cost=4035.99..4036.01 rows=6 width=32)
   Sort Key: (min(scheduled_departure))
   ->  Finalize GroupAggregate  (cost=4035.10..4035.91 rows=6 width=32)
         Group Key: status
         ->  Gather Merge  (cost=4035.10..4035.79 rows=6 width=32)
               Workers Planned: 1
               ->  Sort  (cost=3035.09..3035.11 rows=6 width=32)
                     Sort Key: status
                     ->  Partial HashAggregate  (cost=3034.96..3035.02 rows=6 width=32)
                           Group Key: status
                           ->  Parallel Seq Scan on flights  (cost=0.00..2237.48 rows=79748 width=16)
(11 строк)

```
### Clickhouse - размер и запросы

```
подключаемся и проверяем
docker run -it --rm --network=container:some-clickhouse-server --entrypoint clickhouse-client clickhouse/clickhouse-server

SELECT
    database,
    formatReadableSize(sum(bytes)) AS size,
    sum(rows) AS rows,
    count() AS tables
FROM system.parts
WHERE (database = 'bookings') AND active
GROUP BY database

Query id: 7aded3b9-8a22-49a7-8e97-92ff73575022

   ┌─database─┬─size─────┬──────rows─┬─tables─┐
1. │ bookings │ 3.38 GiB │ 205805937 │     38 │
   └──────────┴──────────┴───────────┴────────┘

1 row in set. Elapsed: 0.002 sec. 



Query id: 23e8bb91-affd-415e-9914-06dd6b0c4560

   ┌─status────┬──count─┬─min_scheduled_departure────┬─max_scheduled_departure────┐
1. │ Arrived   │ 248190 │ 2025-10-01 00:00:00.000000 │ 2027-08-31 23:10:00.000000 │
2. │ Cancelled │   1404 │ 2025-10-01 12:25:00.000000 │ 2027-10-29 08:00:00.000000 │
3. │ Departed  │     42 │ 2027-08-31 14:40:00.000000 │ 2027-08-31 23:40:00.000000 │
4. │ Boarding  │     10 │ 2027-08-31 23:55:00.000000 │ 2027-09-01 00:25:00.000000 │
5. │ On Time   │    346 │ 2027-09-01 00:30:00.000000 │ 2027-09-01 23:50:00.000000 │
6. │ Delayed   │     20 │ 2027-09-01 04:35:00.000000 │ 2027-09-01 18:40:00.000000 │
7. │ Scheduled │  21130 │ 2027-09-02 00:00:00.000000 │ 2027-10-30 23:55:00.000000 │
   └───────────┴────────┴────────────────────────────┴────────────────────────────┘

7 rows in set. Elapsed: 0.009 sec. Processed 271.14 thousand rows, 13.33 MB (31.65 million rows/s., 1.56 GB/s.)
Peak memory usage: 599.52 KiB.

SELECT count(*)
FROM tickets
WHERE outbound = '1'

Query id: 6d028eb4-b344-44d9-9b16-89b7936bb358

   ┌──count()─┐
1. │ 27116440 │ -- 27.12 million
   └──────────┘

1 row in set. Elapsed: 0.009 sec. Processed 42.19 million rows, 42.19 MB (4.48 billion rows/s., 4.48 GB/s.)
Peak memory usage: 219.46 KiB.

EXPLAIN
SELECT
    status,
    count(*) AS count,
    min(scheduled_departure) AS min_scheduled_departure,
    max(scheduled_departure) AS max_scheduled_departure
FROM flights
GROUP BY status
ORDER BY min_scheduled_departure ASC

Query id: 31ea0d86-0d6b-4eb6-85d6-551340a19b3d

   ┌─explain────────────────────────────────────────────────────────────────────────────┐
1. │ Expression (Project names)                                                         │
2. │   Sorting (Sorting for ORDER BY)                                                   │
3. │     Expression ((Before ORDER BY + Projection))                                    │
4. │       Aggregating                                                                  │
5. │         Expression ((Before GROUP BY + Change column names to column identifiers)) │
6. │           ReadFromMergeTree (bookings.flights)                                     │
   └────────────────────────────────────────────────────────────────────────────────────┘

6 rows in set. Elapsed: 0.001 sec. 
```