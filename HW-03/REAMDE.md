### Создаем ВМ в Яндекс облаке, добавляем свой ключ и подключаемся
```
ssh -i ~/.ssh/yc vgaranin@51.250.84.5
```

### Установка и настройка Postgres:
```
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql && sudo apt install unzip && sudo apt -y install mc
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


#### Через веб-интерфейс создаем дополнительный диск 1GB, подключаем его к ВМ, монтируем
```
mkdir /mnt/pg-data

root@compute-vm-2-2-10-ssd-1747659187297:~# lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda     252:0    0   10G  0 disk 
├─vda1  252:1    0  9.4G  0 part /
├─vda14 252:14   0    4M  0 part 
└─vda15 252:15   0  600M  0 part /boot/efi
vdb     252:16   0    1G  0 disk 

mkfs.ext4 /dev/vdb
mount /dev/vdb /mnt/pg-data

```
#### Проверяем
```
root@compute-vm-2-2-10-ssd-1747659187297:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            969M     0  969M   0% /dev
tmpfs           198M  1.1M  197M   1% /run
/dev/vda1       9.1G  2.1G  7.0G  24% /
tmpfs           986M  1.1M  985M   1% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           986M     0  986M   0% /sys/fs/cgroup
/dev/vda15      599M  6.1M  593M   2% /boot/efi
tmpfs           198M     0  198M   0% /run/user/1000
/dev/vdb        974M   24K  907M   1% /mnt/pg-data
root@compute-vm-2-2-10-ssd-1747659187297:~# 
```
#### Выключаем сервер postgres и переносим данные на внешний диск
```
systemctl stop postgresql@17-main.service 
mv /var/lib/postgresql/17/main /mnt/pg-data/17
chown -R postgres:postgres /mnt/pg-data

nano /etc/postgresql/17/main/postgresql.conf
#data_directory = '/var/lib/postgresql/17/main'
data_directory = '/mnt/pg-data/17'

systemctl start postgresql@17-main.service
```

### Проверяем
```
root@compute-vm-2-2-10-ssd-1747659187297:~# su postgres -c 'psql -c "show data_directory;"'
 data_directory  
+-----------------
 /mnt/pg-data/17
(1 row)

root@compute-vm-2-2-10-ssd-1747659187297:~# su postgres -c 'psql -c "select * from shipments;"'
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
