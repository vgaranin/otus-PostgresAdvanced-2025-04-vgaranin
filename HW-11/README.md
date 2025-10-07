# Работа с кластером высокой доступности
Кластер postgresql + patroni + etcd + haproxy используя postgres-operator


#### Клонируем репозиторий
```
git clone https://github.com/zalando/postgres-operator.git
cd postgres-operator
```

### Устанавливаем через helm chart из локальной директории
```
helm install postgres-operator ./charts/postgres-operator \
  --namespace postgres-operator \
  --create-namespace \
  --set configKubernetes.spilo_runasuser=101 \
  --set configKubernetes.spilo_runasgroup=103 \
  --set configKubernetes.spilo_fsgroup=103
```
Создаем postgres-cluster.yaml


# Применяем конфигурацию кластера
```
kubectl apply -f postgres-cluster.yaml
```
# Мониторим запуск
```
kubectl get pods -n postgres-operator -l application=spilo -w
```
Применяем настройки haproxy и проверяем
```
kubectl apply -f haproxy-config.yaml

kubectl get pods -n postgres-operator 
NAME                                          READY   STATUS    RESTARTS   AGE
acid-minimal-cluster-0                        1/1     Running   0          8m55s
acid-minimal-cluster-1                        1/1     Running   0          7m59s
acid-minimal-cluster-2                        1/1     Running   0          7m58s
acid-minimal-cluster-pooler-bcf55bcc8-rvpj6   1/1     Running   0          5m
acid-minimal-cluster-pooler-bcf55bcc8-xvmjj   1/1     Running   0          5m
haproxy-6fcd5d5f48-49n68                      1/1     Running   0          38s
haproxy-6fcd5d5f48-srm8x                      1/1     Running   0          38s
postgres-operator-54f5f68dbc-rm55k            1/1     Running   0          14m
```

#### Определяем текущего лидера
```
LEADER_POD=$(kubectl exec -n postgres-operator acid-minimal-cluster-0 -- patronictl list -f json | jq -r '.[] | select(.Role == "Leader") | .Member')

echo "Current leader: $LEADER_POD"
Current leader: acid-minimal-cluster-0
```
#### Останавливаем под лидера
```
kubectl delete pod -n postgres-operator $LEADER_POD
```
#### Мониторим процесс failover
```
kubectl exec -n postgres-operator acid-minimal-cluster-1 -- patronictl list

+ Cluster: acid-minimal-cluster (7558315705387241535) -------+----+-----------+
| Member                 | Host        | Role    | State     | TL | Lag in MB |
+------------------------+-------------+---------+-----------+----+-----------+
| acid-minimal-cluster-0 | 10.244.0.28 | Replica | streaming |  2 |         0 |
| acid-minimal-cluster-1 | 10.244.0.22 | Replica | streaming |  2 |         0 |
| acid-minimal-cluster-2 | 10.244.0.23 | Leader  | running   |  2 |           |
+------------------------+-------------+---------+-----------+----+-----------+
```

#### Подключаемся по haproxy
```
kubectl port-forward -n postgres-operator svc/haproxy-service 5432:5432

kubectl get secret -n postgres-operator postgres.acid-minimal-cluster.credentials.postgresql.acid.zalan.do -o 'jsonpath={.data.password}' | base64 -d

psql -h localhost -U postgres
psql (18.0 (Ubuntu 18.0-1.pgdg24.04+3), сервер 15.10 (Ubuntu 15.10-1.pgdg22.04+1))
Введите "help", чтобы получить справку.

postgres=# 
```