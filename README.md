# Lesson 9
### Тема: Работа с журналами

* __Цель:__

  * уметь работать с журналами и контрольными точками
  * уметь настраивать параметры журналов

### Решение:
* __создаю GCE инстанс типа e2-medium__
```
damir@Damir:~$ gcloud beta compute instances create postgres-node-2 \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
--boot-disk-type=pd-ssd \
--tags=postgres \
--restart-on-failure
```

* __подключаемся к VM и устанавливаем Postgres 14 с дефолтными настройками__
```
damir@postgres-node-2:~$ sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-14
```
* __запускаю psql__
```
sudo -u postgres psql
```

* __Настройка выполнения контрольной точки.__
    * _____Настрайваю выполнения контрольной точки раз в 30 секунд._____
    ```
    postgres=# ALTER SYSTEM SET checkpoint_timeout = 30;
    ALTER SYSTEM
    ```

    * _____Включаю получения в журнале сообщений сервера информации о выполняемых контрольных точках и перезагружаю конфигурации_____
    ```
    postgres=# ALTER SYSTEM SET log_checkpoints = on;
    ALTER SYSTEM
    postgres=# SELECT pg_reload_conf();
    pg_reload_conf 
    ----------------
    t
    (1 row)

    postgres=#
   ```

   * _____Подготовка pgbench_____
  ```
  damir@postgres-node-2:~$ sudo -u postgres pgbench -i postgres
  dropping old tables...
  creating tables...
  generating data (client-side)...
  100000 of 100000 tuples (100%) done (elapsed 0.10 s, remaining 0.00 s)
  vacuuming...
  creating primary keys...
  done in 0.43 s (drop tables 0.01 s, create tables 0.01 s, client-side generate 0.24 s, vacuum 0.09 s, primary keys 0.08 s).

  ```

  - _____Запускаю нагрузку с помощью утилиты pgbench._____
  ```
  damir@postgres-node-2:~$ sudo -u postgres pgbench -P 30 -T 600
  pgbench (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
  starting vacuum...end.
  ...
  progress: 510.0 s, 574.4 tps, lat 1.740 ms stddev 0.408
  progress: 540.0 s, 634.9 tps, lat 1.574 ms stddev 0.254
  progress: 570.0 s, 593.9 tps, lat 1.683 ms stddev 0.234
  progress: 600.0 s, 586.3 tps, lat 1.705 ms stddev 0.220
  transaction type: <builtin: TPC-B (sort of)>
  scaling factor: 1
  query mode: simple
  number of clients: 1
  number of threads: 1
  duration: 600 s
  number of transactions actually processed: 346460
  latency average = 1.731 ms
  latency stddev = 0.500 ms
  initial connection time = 4.524 ms
  tps = 577.435837 (without initial connection time)

  ```
  - _____посмотрю log postgres_____
  
  ```
  damir@postgres-node-2:~$ tail  /var/log/postgresql/postgresql-14-main.log 
  2022-11-21 00:39:17.040 UTC [17261] LOG:  checkpoint starting: time
  2022-11-21 00:39:44.031 UTC [17261] LOG:  checkpoint complete: wrote 1832 buffers (11.2%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.975 s, sync=0.005 s, total=26.991 s; sync files=6, longest=0.004 s, average=0.001 s; distance=20205 kB, estimate=20876 kB
  2022-11-21 00:39:47.034 UTC [17261] LOG:  checkpoint starting: time
  2022-11-21 00:40:14.035 UTC [17261] LOG:  checkpoint complete: wrote 1957 buffers (11.9%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.976 s, sync=0.004 s, total=27.002 s; sync files=9, longest=0.004 s, average=0.001 s; distance=20749 kB, estimate=20863 kB
  2022-11-21 00:40:17.036 UTC [17261] LOG:  checkpoint starting: time
  2022-11-21 00:40:44.029 UTC [17261] LOG:  checkpoint complete: wrote 1828 buffers (11.2%); 0 WAL file(s) added, 0 removed, 2 recycled; write=26.976 s, sync=0.006 s, total=26.994 s; sync files=6, longest=0.004 s, average=0.001 s; distance=20647 kB, estimate=20842 kB
  2022-11-21 00:40:47.032 UTC [17261] LOG:  checkpoint starting: time
  2022-11-21 00:41:14.046 UTC [17261] LOG:  checkpoint complete: wrote 2154 buffers (13.1%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.989 s, sync=0.005 s, total=27.014 s; sync files=12, longest=0.003 s, average=0.001 s; distance=20545 kB, estimate=20812 kB
  2022-11-21 00:41:47.079 UTC [17261] LOG:  checkpoint starting: time
  2022-11-21 00:42:14.092 UTC [17261] LOG:  checkpoint complete: wrote 1775 buffers (10.8%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.999 s, sync=0.004 s, total=27.013 s; sync files=11, longest=0.002 s, average=0.001 s; distance=16558 kB, estimate=20387 kB
  ```

   > ___Здесь я наблюдаю сколько буферов было записано, изменения в составе журнальных файлов после контрольной точки, сколько времени заняла контрольная точка и расстояние (в байтах) между соседними контрольными точками
   В среднем на одну контрольную точку приходиться около 2000 буферов
   Все контрольные точки выполнились по расписанию по умолчанию checkpoint_completion_target = 0.9 время выполнения в логе половина от 30с.___

  - ___Просматриваю статистику из представления pg_stat_bgwriter___
  ```
    damir@postgres-node-2:~$ sudo -u postgres psql
    psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
    Type "help" for help.

  postgres=# SELECT * FROM pg_stat_bgwriter \gx
  -[ RECORD 1 ]---------+------------------------------
  checkpoints_timed     | 24
  checkpoints_req       | 0
  checkpoint_write_time | 566080
  checkpoint_sync_time  | 124
  buffers_checkpoint    | 41461
  buffers_clean         | 0
  maxwritten_clean      | 0
  buffers_backend       | 4217
  buffers_backend_fsync | 0
  buffers_alloc         | 4809
  stats_reset           | 2022-11-21 02:01:24.240743+00
  postgres=# 
  ```

  > ___Выполненно контрольных точек по расписанию, checkpoint_timeout - 24 (такое же количество насчитано и в лог файле) параметр max_wal_size = 1GB превышает сгенерированный объём WAL файлов___

  - ___для просмотра последние lsn для таблиц и каким файлам они принадлежат выполняю следующие команды___

  ```
  postgres=# \dt
                List of relations
   Schema |       Name       | Type  |  Owner   
  --------+------------------+-------+----------
   public | pgbench_accounts | table | postgres
   public | pgbench_branches | table | postgres
   public | pgbench_history  | table | postgres
   public | pgbench_tellers  | table | postgres
  (4 rows)


  postgres=# CREATE EXTENSION pageinspect;
  CREATE EXTENSION
  postgres=# SELECT lsn FROM page_header(get_raw_page('pgbench_accounts',0));
   lsn     
  ------------
   0/1C6E97B0
  (1 row)

  postgres=# SELECT lsn FROM page_header(get_raw_page('pgbench_branches',0));
      lsn     
  ------------
   0/1C6EFD68
  (1 row)

  postgres=# SELECT pg_walfile_name('0/1C6E97B0');
       pg_walfile_name      
  --------------------------
   00000001000000000000001C
  (1 row)

  postgres=# SELECT pg_walfile_name('0/1C6EFD68');
       pg_walfile_name      
  --------------------------
   00000001000000000000001C
  (1 row)

  postgres=# 
  ```
  в результате два wal файла

- __Сравнения tps в синхронном/асинхронном режиме утилитой pgbench__

  - ___переключаюсь на асинхронный режим___
  ```
  postgres=# ALTER SYSTEM SET synchronous_commit = off;
  ALTER SYSTEM
  postgres=# SELECT pg_reload_conf();
  pg_reload_conf 
  ----------------
  t
  (1 row)

  postgres=#
  ``` 
  - ___запуск pgbench___

  ```
  damir@postgres-node-2:~$ sudo -u postgres pgbench -P 30 -T 600
  pgbench (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
  starting vacuum...end.
  rogress: 540.1 s, 627.6 tps, lat 1.600 ms stddev 10.008
  progress: 570.1 s, 626.9 tps, lat 1.595 ms stddev 9.957
  progress: 600.1 s, 635.7 tps, lat 1.566 ms stddev 9.865
  transaction type: <builtin: TPC-B (sort of)>
  scaling factor: 1
  query mode: simple
  number of clients: 1
  number of threads: 1
  duration: 600 s
  number of transactions actually processed: 455306
  latency average = 1.317 ms
  latency stddev = 8.132 ms
  initial connection time = 4.432 ms
  tps = 758.755949 (without initial connection time)
  ```
  > _производительность по tps увеличилась но не так сильно, так как у меня инстанция на ssd_


  - ___проверяю лог файл___
  ```
  damir@postgres-node-2:~$ tail  /var/log/postgresql/postgresql-14-main.log
  2022-11-21 06:44:56.151 UTC [17279] LOG:  checkpoint starting: time
  2022-11-21 06:45:23.148 UTC [17279] LOG:  checkpoint complete: wrote 2189 buffers (13.4%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.979 s, sync=0.005 s, total=26.997 s; sync files=15, longest=0.004 s, average=0.001 s; distance=21101 kB, estimate=23063 kB
  2022-11-21 06:45:26.151 UTC [17279] LOG:  checkpoint starting: time
  2022-11-21 06:45:53.150 UTC [17279] LOG:  checkpoint complete: wrote 1823 buffers (11.1%); 0 WAL file(s) added, 0 removed, 2 recycled; write=26.979 s, sync=0.007 s, total=26.999 s; sync files=6, longest=0.004 s, average=0.002 s; distance=20880 kB, estimate=22845 kB
  2022-11-21 06:45:56.151 UTC [17279] LOG:  checkpoint starting: time
  2022-11-21 06:46:23.145 UTC [17279] LOG:  checkpoint complete: wrote 1832 buffers (11.2%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.979 s, sync=0.005 s, total=26.994 s; sync files=14, longest=0.004 s, average=0.001 s; distance=20923 kB, estimate=22652 kB
  2022-11-21 06:46:26.147 UTC [17279] LOG:  checkpoint starting: time
  2022-11-21 06:46:53.038 UTC [17279] LOG:  checkpoint complete: wrote 1818 buffers (11.1%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.877 s, sync=0.004 s, total=26.891 s; sync files=6, longest=0.003 s, average=0.001 s; distance=20985 kB, estimate=22486 kB
  2022-11-21 06:47:56.082 UTC [17279] LOG:  checkpoint starting: time
  2022-11-21 06:48:23.090 UTC [17279] LOG:  checkpoint complete: wrote 1216 buffers (7.4%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.993 s, sync=0.005 s, total=27.009 s; sync files=15, longest=0.004 s, average=0.001 s; distance=17035 kB, estimate=21941 kB
  ```
* __Касательно zabbix так же можно настроить и отслеживать данные.__
  
![image](https://user-images.githubusercontent.com/85208391/202900217-2ae22bdf-2601-49c9-ab2a-6c4ba4313597.png)

### Создания нового кластера с включенной контрольной суммой страниц.

* __Создаю новый кластер с включенной контрольной суммой страниц.__
```
damir@postgres-node-2:~$ sudo pg_ctlcluster 14 main stop
damir@postgres-node-2:~$ sudo pg_dropcluster 14 main
damir@postgres-node-2:~$ sudo pg_createcluster 14 main
Creating new PostgreSQL cluster 14/main ...
/usr/lib/postgresql/14/bin/initdb -D /var/lib/postgresql/14/main --auth-local peer --auth-host scram-sha-256 --no-instructions
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "C.UTF-8".
The default database encoding has accordingly been set to "UTF8".
The default text search configuration will be set to "english".

Data page checksums are disabled.

fixing permissions on existing directory /var/lib/postgresql/14/main ... ok
creating subdirectories ... ok
selecting dynamic shared memory implementation ... posix
selecting default max_connections ... 100
selecting default shared_buffers ... 128MB
selecting default time zone ... Etc/UTC
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok
syncing data to disk ... ok
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
damir@postgres-node-1:~$ sudo pg_ctlcluster 14 main start
```
- __проверяю включена ли проверка CRC__
```
damir@postgres-node-2:~$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# show data_checksums;
 data_checksums 
----------------
 off
(1 row)
```
Не включена. Включаю следующим образом.
```
damir@postgres-node-2:~$ sudo pg_ctlcluster 14 main stop
damir@postgres-node-2:~$ sudo su - postgres -c '/usr/lib/postgresql/14/bin/pg_controldata -D "/var/lib/postgresql/14/main/"' | grep state
Database cluster state:               shut down
damir@postgres-node-2:~$ sudo su - postgres -c '/usr/lib/postgresql/14/bin/pg_checksums --enable -D "/var/lib/postgresql/14/main"'
Checksum operation completed
Files scanned:  931
Blocks scanned: 3207
pg_checksums: syncing data directory
pg_checksums: updating control file
Checksums enabled in cluster
damir@postgres-node-2:~$ sudo pg_ctlcluster 14 main start
damir@postgres-node-2:~$ sudo su - postgres -c 'psql -c "SHOW data_checksums;"'
 data_checksums 
----------------
 on
(1 row)
```
- __создаю таблицу и вставляю несколько значений__
```
damir@postgres-node-2:~$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# create table t1 (i int);
CREATE TABLE
postgres=# insert into t1 values(1)
postgres-# ;
INSERT 0 1
postgres=# insert into t1 values(2);
INSERT 0 1
postgres=# insert into t1 values(3);
INSERT 0 1
postgres=# select i from t1;
 i 
---
 1
 2
 3
(3 rows)

postgres=# SELECT pg_relation_filepath('t1');
 pg_relation_filepath 
----------------------
 base/13726/16384
(1 row)

postgres=# 
```


Cоздайте таблицу. Вставьте несколько значений. Выключите кластер. Измените пару байт в таблице. Включите кластер и сделайте выборку из таблицы. Что и почему произошло? как проигнорировать ошибку и продолжить работу?__

