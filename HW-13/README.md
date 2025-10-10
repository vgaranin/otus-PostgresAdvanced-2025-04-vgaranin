# YUGABYTEDB и postgresql
```
kubectl create namespace yugabyte

# Устанавливаем через Helm
helm repo add yugabytedb https://charts.yugabyte.com
helm repo update

helm install yb-test yugabytedb/yugabyte \
  --namespace yugabyte \
  --set resource.master.requests.cpu=0.5 \
  --set resource.master.requests.memory=1Gi \
  --set resource.tserver.requests.cpu=0.5 \
  --set resource.tserver.requests.memory=1Gi \
  --set replicas.master=1 \
  --set replicas.tserver=1 \
  --wait

# Проверяем

kubectl get svc -n yugabyte
NAME           READY   STATUS    RESTARTS   AGE
yb-master-0    3/3     Running   0          30m
yb-tserver-0   3/3     Running   0          30m

NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                                                AGE
yb-master-ui           LoadBalancer   10.97.248.57     <pending>     7000:31925/TCP                                                                         30m
yb-masters             ClusterIP      None             <none>        7000/TCP,7100/TCP,15433/TCP                                                            30m
yb-tserver-service     LoadBalancer   10.111.193.122   <pending>     6379:32250/TCP,9042:31023/TCP,5433:31357/TCP                                           30m
yb-tservers            ClusterIP      None             <none>        9000/TCP,12000/TCP,11000/TCP,13000/TCP,9100/TCP,6379/TCP,9042/TCP,5433/TCP,15433/TCP   30m
yugabyted-ui-service   LoadBalancer   10.109.235.90    <pending>     15433:30436/TCP                                                                        30m


# Создаем пользователя для подключения

kubectl exec -n yugabyte -it yb-tserver-0 -- ysqlsh -h yb-tserver-0.yb-tservers.yugabyte.svc.cluster.local -U yugabyte -c "CREATE USER admin WITH SUPERUSER PASSWORD 'admin123';"
Defaulted container "yb-tserver" out of: yb-tserver, yb-cleanup, yugabyted-ui
CREATE ROLE

# Пробрасываем порты для YSQL (PostgreSQL)
kubectl port-forward -n yugabyte svc/yb-tserver-service 5433:5433 &

# Пробрасываем порты для UI
kubectl port-forward -n yugabyte svc/yb-master-ui 7000:7000 &
kubectl port-forward -n yugabyte svc/yugabyted-ui-service 15433:15433 &

# Проверяем что порты слушают
netstat -tlnp | grep 5433
tcp        0      0 127.0.0.1:5433          0.0.0.0:*               LISTEN      56749/kubectl       
tcp        0      0 127.0.0.1:15433         0.0.0.0:*               LISTEN      56914/kubectl       

psql -h localhost -p 5433 -U admin -d yugabyte
Handling connection for 5433
psql (18.0 (Ubuntu 18.0-1.pgdg24.04+3), сервер 15.12-YB-2025.1.1.1-b0)
Введите "help", чтобы получить справку.

yugabyte=#
# загружаем датасет

psql -h localhost -p 5433 -U admin -d yugabyte -f demo-20250901-2y.sql
```

### Сравнение времени выполнения запросов:
#### postgresql
```
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
#### yugabyte
```
demo=# select count(*) from bookings;
  count  
---------
 9706657
(1 строка)

Время: 5687,728 мс (00:05,688)

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
(7 строк)

Время: 141,910 мс
```
### Вывод
Простой каунт на yugabyte выполнился быстрее, хотя запрос с группировкой конкретно на моем стенде выполнялся дольше. Предположу, что это связано с выделением недостаточного количества ресурсов нодам с yugabyte (у postgres было 2 ядра 4 GB RAM, у yugabyte было 0.5 ядра и 1GB RAM). И при этом count сработал быстрее.
Вывод: при сопоставимых ресурсах yugabyte больше подходит для аналитических запросов.