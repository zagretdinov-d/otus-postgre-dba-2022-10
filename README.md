# Lesson 13
### Тема: Нагрузочное тестирование и тюнинг PostgreSQL

* __Цель:__

  * сделать нагрузочное тестирование PostgreSQL
  * настроить параметры PostgreSQL для достижения максимальной производительности


### Решение:
* __создаю GCE инстанс типа e2-medium__
```
damir@Damir:~$ gcloud beta compute instances create postgres-node-3 \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
--boot-disk-type=pd-ssd \
--tags=postgres \
--restart-on-failure
```

* __В результате создается машина__
```
NAME             ZONE               MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
postgres-node-3  europe-central2-c  e2-medium                  10.186.0.7   34.118.62.xxx  RUNNING
```

* __подключаемся к VM и устанавливаем Postgres 14 с дефолтными настройками__
```
damir@postgres-node-3:~$ sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-14
```
* __редактирую /etc/postgresql/14/main/pg_hba.conf и sudo nano /etc/postgresql/14/main/postgresql.conf__
```
host    dbtest          devops          0.0.0.0/32            md5
listen_addresses = '*'
```
* __перезапускаюсь__
```
sudo pg_ctlcluster 14 main restart
```
* __запускаю psql__
```
sudo -u postgres psql
```
* __подготавливаю базу__
```
damir@postgres-node-3:/opt/postgres_exporter$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# CREATE USER devops WITH PASSWORD 'password';
CREATE ROLE
postgres=# CREATE DATABASE dbtest;
CREATE DATABASE
postgres=# GRANT ALL PRIVILEGES ON DATABASE dbtest TO devops;
GRANT
```
>Прежде чем приступить к нагрузочному тестированию и установки sysbench. Я в этот раз чтоб мониторить кластер  пробую подключить уже ранне равернутому prometheus c графаной.

![image](https://user-images.githubusercontent.com/85208391/206626225-dc680195-3829-4f10-a12b-92f3df412a55.png)
![image](https://user-images.githubusercontent.com/85208391/206626782-465ffe6e-2a3a-406d-8715-859c2b28f4ca.png)

>Удалось подключиться с помощью утилитки экспартера для postgres где я в конфигах прописал созданную базу и пользователя. В графане все работает и база успешно подцепилась.



* __приступаю к устанавливке sysbench для тестирования__
```
curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
sudo apt -y install sysbench
```
* __инициализирую созданную БД в sysbench__
```
sudo sysbench \
--db-driver=pgsql \
--oltp-table-size=1000000 \
--oltp-tables-count=10 \
--threads=1 \
--pgsql-host=34.118.62.XXX \
--pgsql-port=5432 \
--pgsql-user=devops \
--pgsql-password=513DFXXX \
--pgsql-db=dbtest \
/usr/share/sysbench/tests/include/oltp_legacy/parallel_prepare.lua \
run
```
В результате получаю.
```
SQL statistics:
    queries performed:
        read:                            0
        write:                           3730
        other:                           20
        total:                           3750
    transactions:                        1      (0.01 per sec.)
    queries:                             3750   (19.94 per sec.)
    ignored errors:                      0      (0.00 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          188.0275s
    total number of events:              1

Latency (ms):
         min:                               188026.77
         avg:                               188026.77
         max:                               188026.77
         95th percentile:                   100000.00
         sum:                               188026.77

Threads fairness:
    events (avg/stddev):           1.0000/0.00
    execution time (avg/stddev):   188.0268/0.00

```

>генерирую 1 000 000 строк в таблице для 10 таблиц (от sbtest1 до sbtest10) внутри базы данных dbtest. по умолчанию имя схемы - "public".

```
damir@postgres-node-3:~$ psql -U devops -d dbtest -h 127.0.0.1 -p 5432 -W -c '\dt+\'
Password: 
                                    List of relations
 Schema |   Name   | Type  | Owner  | Persistence | Access method |  Size  | Description 
--------+----------+-------+--------+-------------+---------------+--------+-------------
 public | sbtest1  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest10 | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest2  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest3  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest4  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest5  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest6  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest7  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest8  | table | devops | permanent   | heap          | 211 MB | 
 public | sbtest9  | table | devops | permanent   | heap          | 211 MB | 
(10 rows)
```
и по наблюдаю что происходит в моих графиках.

![image](https://user-images.githubusercontent.com/85208391/206629385-ad0d6248-e0d8-482c-84e5-22e729b303b9.png)
![image](https://user-images.githubusercontent.com/85208391/206629775-470d862f-9f74-4a32-a517-de00823e9b8a.png)

* __протестирую нагрузку read/write__

sudo sysbench \
--db-driver=pgsql \
--report-interval=10 \
--oltp-table-size=1000000 \
--oltp-tables-count=10 \
--threads=64 \
--time=600 \
--pgsql-host=34.118.62.XXX \
--pgsql-port=5432 \
--pgsql-user=devops \
--pgsql-password=513DFrXXX \
--pgsql-db=dbtest \
/usr/share/sysbench/tests/include/oltp_legacy/WR.lua \
run

![image](https://user-images.githubusercontent.com/85208391/206652508-94e3222b-cdb2-49e2-a937-fa30b09157ca.png)
![image](https://user-images.githubusercontent.com/85208391/206652822-db016b0a-f400-4dc4-8685-1d39d16b8962.png)

![image](https://user-images.githubusercontent.com/85208391/206653023-7f42ec59-e268-4182-bd01-e38526ce1f86.png)


* __Вывод__
![image](https://user-images.githubusercontent.com/85208391/206658720-9d8d5742-56bb-42f4-aecb-b25ee9e67ac1.png)

![image](https://user-images.githubusercontent.com/85208391/206658862-276907e1-0990-420e-8801-315cef9a1078.png)
![image](https://user-images.githubusercontent.com/85208391/206658959-34335431-a4b1-4cf3-abfb-796bce9cbc6c.png)

