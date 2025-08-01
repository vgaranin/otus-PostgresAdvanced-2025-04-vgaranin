# Сравнение managed PostgreSQL VK cloud и Yandex Cloud

## VK Cloud
Минимальный сетап:
2 CPU 8 RAM 10GB ssd + внешний IP 
3873.2 в месяц

Сервис развернулся быстро, подключение прошло без проблем.

## YC
5 412,64 в месяц

Сервис разворачивался около 7 минут, были проблемы с подключением, так как endpoint долгое время не резолвился.


## Тестирование pgbench

Плейбук
```
---
- name: Run pgbench against remote PostgreSQL servers
  hosts: localhost
  connection: local
  vars:
    pgbench_targets:
      - name: vk
        host: 212.233.88.39
        port: 5432
        user: user
        password: ")7Z2GR4bLr72iN611"
        db: otus-test
      - name: yandex
        host: rc1a-7jek6k3qbgrl1n29.mdb.yandexcloud.net
        port: 6432
        user: user
        password: ")7Z2GR4bLr72iN611"
        db: user
    scale_factor: 100
    duration: 60
    clients: 10
    jobs: 2
    result_dir: "./results"
  tasks:

    - name: Ensure PostgreSQL 17 client and tools are installed
      become: true
      ansible.builtin.package:
        name:
          - postgresql-client-17
          - postgresql-17
        state: present

    - name: Create local results directory
      ansible.builtin.file:
        path: "{{ result_dir }}"
        state: directory
        mode: '0755'

    - name: Run pgbench for each target
      loop: "{{ pgbench_targets }}"
      loop_control:
        label: "{{ item.name }}"
      environment:
        PGPASSWORD: "{{ item.password }}"
        PATH: "/usr/lib/postgresql/17/bin:{{ ansible_env.PATH }}"
      ansible.builtin.shell: |
        echo "Initializing {{ item.name }}..."
        pgbench -i -s {{ scale_factor }} -h {{ item.host }} -p {{ item.port }} -U {{ item.user }} {{ item.db }}

        echo "Benchmarking {{ item.name }}..."
        pgbench -c {{ clients }} -j {{ jobs }} -T {{ duration }} \
          -h {{ item.host }} -p {{ item.port }} -U {{ item.user }} {{ item.db }} \
          > {{ result_dir }}/pgbench_{{ item.name }}.log 2>&1

```
Результаты

VK
```
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 100
query mode: simple
number of clients: 10
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 408
number of failed transactions: 0 (0.000%)
latency average = 1377.149 ms
initial connection time = 4985.000 ms
tps = 7.261378 (without initial connection time)
```

YC
```
pgbench (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 100
query mode: simple
number of clients: 10
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 389
number of failed transactions: 0 (0.000%)
latency average = 1384.458 ms
initial connection time = 7411.892 ms
tps = 7.223041 (without initial connection time)
```
Результаты:
Цена: при одинаковых характеристиках VK дешевле
latency: VK отвечает быстрее
удобство: VK разворачивается быстрее, подключение происходит без проблем