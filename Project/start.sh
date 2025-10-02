#!/bin/bash

echo "Starting HAProxy..."
# Запускаем HAProxy в фоне
haproxy -f /usr/local/etc/haproxy/haproxy.cfg -db

echo "Starting Keepalived..."
# Запускаем Keepalived на переднем плане
exec keepalived -n -f /etc/keepalived/keepalived.conf