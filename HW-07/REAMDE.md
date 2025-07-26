## PostgreSQL в k8s

### Формируем helm chart

```
values.yml

image:
  tag: 14.11.0-debian-11-r0

architecture: replication

replication:
  enabled: true
  synchronousCommit: "on"
  numSynchronousReplicas: 0

readReplicas:
  replicaCount: 2
  persistence:
    enabled: true
    storageClass: "standard"
    size: 1Gi

auth:
  existingSecret: my-postgres-secret
  secretKeys:
    adminPasswordKey: postgres-password
    usernameKey: postgres-user
    passwordKey: postgres-password
    replicationPasswordKey: replication-password
  database: postgres

primary:
  persistence:
    enabled: true
    storageClass: "standard"
    size: 1Gi
  service:
    type: ClusterIP
  podAnnotations:
    prometheus.io/scrape: "true"

volumePermissions:
  enabled: true

resources:
  requests:
    memory: 256Mi
    cpu: 250m
  limits:
    memory: 512Mi
    cpu: 500m

serviceAccount:
  create: true
```


Создаем серкет
```
kubectl create secret generic my-postgres-secret \
  --from-literal=postgres-password='password' \
  --from-literal=postgres-user='postgres' \
  --from-literal=postgres-database='postgres' \
  --from-literal=replication-password='passWord' \
  -n postgres
```
Проверяем
```
$ kubectl get secrets -n postgres
NAME                 TYPE     DATA   AGE
my-postgres-secret   Opaque   2      8s
```
Добавляем репозиторий Bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

Устанавливаем Helm-чарт с values.yaml
```
helm install my-postgres bitnami/postgresql -f values.yml -n postgres
```
 Проверяем
 
<img width="689" height="153" alt="image" src="https://github.com/user-attachments/assets/d0ff1b3e-d8d2-4788-9580-c731285a66f0" />


### Настраиваем порт форвардинг и подключаемся
```
kubectl port-forward --namespace postgres svc/my-postgres-postgresql-primary 5432:5432
```
<img width="1269" height="199" alt="image" src="https://github.com/user-attachments/assets/9e970601-dadd-4c96-a32a-019d0f942880" />

