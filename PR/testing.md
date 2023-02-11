## Тестовая нагрузка.

```
sudo sysbench \
--db-driver=pgsql \
--table-size=10000 \
--tables=24 \
--threads=1 \
--pgsql-host=35.232.96.109 \
--pgsql-port=9001 \
--pgsql-user=devops \
--pgsql-password=51324ASdfQWer \
--pgsql-db=test1 /usr/share/sysbench/oltp_read_write.lua \
prepare
```

> Приведенная выше команда сгенерирует рабочую нагрузку OLTP из скрипта LUA  /usr/share/sysbench/oltp_read_write.lua с именем  с данными размером 10 000 строк в 24 таблиц в 1 рабочих потока на хосте (master).