# Lesson 14
### Тема: Репликация

* __Цель:__

  * Реализовать свой миникластер на 3 ВМ
  * Задание со звездочкой*
       - реализовать горячее реплицирование для высокой доступности на 4ВМ.
       - Источником должна выступать ВМ №3. Написать с какими проблемами столкнулись.


### Решение:
> Для выполнения вышепоставленных целей подготавливаю 4 VM инстанции со следующими характеристиками.

* pg-node1 (Ubuntu 20.04, PostgreSQL 14)
* pg-node2 (Ubuntu 20.04, PostgreSQL 14)
* pg-node3 (Ubuntu 20.04, PostgreSQL 14)
* slave-node4 (Ubuntu 20.04, PostgreSQL 14)

> Для развертывания инстанций в google облаке применю такой инструмент terrafom. Если в крации в созданном файле main.tf добавленны параметры для создания 4-х машин и запск скрипта pg_install с установкой postgresql-14.

- __Настройка логической репликации. Создание БД и таблиц в pg-node1 и pg-node2:__
  - ___pg-node1___
  ``` 
  damir@pg-node1:~$ sudo -u postgres psql
  psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
  Type "help" for help.

  postgres=# alter system set wal_level = logical;
  ALTER SYSTEM
  postgres=#
  damir@pg-node1:~$ sudo pg_ctlcluster 14 main restart
  create database db_node1;
  postgres=# \c db_node1
  You are now connected to database "db_node1" as user "postgres".
  db_node1=#
  db_node1=# create table test1(id integer, mesg varchar(50));
  CREATE TABLE
  db_node1=# create table test2(id integer, mesg varchar(50));
  CREATE TABLE
  db_node1=#
  ```
  - ___pg-node2___
  ```
  damir@pg-node2:~$ sudo -u postgres psql
  psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
  Type "help" for help.

  postgres=# alter system set wal_level = logical;
  ALTER SYSTEM
  postgres=# exir
  postgres-# \q
  damir@pg-node2:~$ sudo pg_ctlcluster 14 main restart
  damir@pg-node2:~$ sudo -u postgres psql
  psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
  Type "help" for help.

  postgres=# create database db_node2;
  CREATE DATABASE
  postgres=# \c db_node2
  You are now connected to database "db_node2" as user "postgres".
  db_node2=# create table test2(id integer, mesg varchar(50));
  CREATE TABLE
  db_node2=# create table test1(id integer, mesg varchar(50));
  CREATE TABLE
  ```

- __Создаю публикацию таблицы test и подписываемся на публикацию таблицы test2 с ВМ №2:__

  - ___pg-node1___
    
   > публикую таблицу test1:

   ```
    db_node1=# CREATE PUBLICATION test1_pub FOR TABLE test1;
    CREATE PUBLICATION
    
    // Проверяю
    db_node1=# \dRp+
                                   Publication test1_pub
      Owner   | All tables | Inserts | Updates | Deletes | Truncates | Via root 
    ----------+------------+---------+---------+---------+-----------+----------
     postgres | f          | t       | t       | t       | t         | f
    Tables:
        "public.test1"
    
    // Добавляю пароль для логической репликации
    db_node1=# \password
    Enter new password for user "postgres": 
    Enter it again: 
    db_node1=# 
   ```
  - ___pg-node2___

  > Выполню тоже самое с таблицей test2
  ```
  db_node2=# CREATE PUBLICATION test2_pub FOR TABLE test2;
  CREATE PUBLICATION
  db_node2=# \dRp+
                             Publication test2_pub
    Owner   | All tables | Inserts | Updates | Deletes | Truncates | Via root 
  ----------+------------+---------+---------+---------+-----------+----------
   postgres | f          | t       | t       | t       | t         | f
  Tables:
      "public.test2"

  db_node2=# \password
  Enter new password for user "postgres": 
  Enter it again:
  ```

- __Оформляю подписку с ноды pg-node1 на таблицу test2 на ноде pg-node2:__
  
  > изменю параметры postgres.conf и разрешу удаленное подключение 

  ```
  sudo vi /etc/postgresql/14/main/postgresql.conf
  listen_addresses = '*'

  sudo vi /etc/postgresql/14/main/pg_hba.conf
  host all all 0.0.0.0/0 md5
  host all all ::/0 md5
  ```
  > Подписываю
  ```
  db_node1=# CREATE SUBSCRIPTION test2_sub CONNECTION 'host=10.128.0.34 port=5432 user=postgres password=devops123 dbname=db_node2' PUBLICATION test2_pub WITH (copy_data = false);
  NOTICE:  created replication slot "test2_sub" on publisher
  CREATE SUBSCRIPTION
  db_node1=# 
  ```

  > Проверяю
  ```
  db_node1=# SELECT * FROM pg_stat_subscription \gx
  -[ RECORD 1 ]---------+------------------------------
  subid                 | 16396
  subname               | test2_sub
  pid                   | 15110
  relid                 | 
  received_lsn          | 0/1715D90
  last_msg_send_time    | 2022-12-19 05:45:58.924928+00
  last_msg_receipt_time | 2022-12-19 05:45:58.925811+00
  latest_end_lsn        | 0/1715D90
  latest_end_time       | 2022-12-19 05:45:58.924928+00
  ```

- __Оформляю подписку с ноды pg-node2 на таблицу test1 ноды pg-node1:__

```
db_node2=# CREATE SUBSCRIPTION test1_sub CONNECTION 'host=10.128.0.35 port=5432 user=postgres password=devops123 dbname=db_node1' PUBLICATION test1_pub WITH (copy_data = false);
NOTICE:  created replication slot "test1_sub" on publisher
CREATE SUBSCRIPTION
db_node2=# SELECT * FROM pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16393
subname               | test1_sub
pid                   | 2594
relid                 | 
received_lsn          | 0/1717430
last_msg_send_time    | 2022-12-19 05:59:07.0889+00
last_msg_receipt_time | 2022-12-19 05:59:07.089898+00
latest_end_lsn        | 0/1717430
latest_end_time       | 2022-12-19 05:59:07.0889+00
```
> на каждом узле вставляю по одной строке в таблицу.
```
db_node1=# insert into test1 values (1, 'Строка в таблице test1 - 1');
INSERT 0 1
```

```
db_node2=# insert into test2 values (1, 'Строка в таблице test2 - 1');
INSERT 0 1
```

> Выполняю запросы на двух таблицах и проверяю идентичность.
```
db_node1=# select * from test1 a, test2 b
db_node1-# where
db_node1-# a.id = b.id;
 id |            mesg            | id |            mesg            
----+----------------------------+----+----------------------------
  1 | Строка в таблице test1 - 1 |  1 | Строка в таблице test2 - 1
(1 row)

db_node2=# select * from test1 a, test2 b
db_node2-# where
db_node2-# a.id = b.id;
 id |            mesg            | id |            mesg            
----+----------------------------+----+----------------------------
  1 | Строка в таблице test1 - 1 |  1 | Строка в таблице test2 - 1
(1 row)
```
![изображение](https://user-images.githubusercontent.com/85208391/208361270-196d4430-42ab-44cc-9051-b37ecb2775e5.png)


> на первой ноде pg-node1 добавлю пару строк и выполню запрос.
```
db_node1=# insert into test1 values (generate_series(2,10),md5(random()::text));
INSERT 0 9

db_node2=# select * from test1;
 id |               mesg               
----+----------------------------------
  1 | Строка в таблице test1 - 1
  2 | 23eaa4f38c601d3577765a5fb2f518c4
  3 | c6cdacad1b1b0c53f3c955ea4a050c97
  4 | 01a24a155e8a1092b84b719c0dbbd3c4
  5 | 10c8f45436a09940700ed3efc326d109
  6 | c10a4ee0d2d9c91d7068eb1d5a313414
  7 | 7391508cde849137c03f2fe42323068d
  8 | b1885de55e33b94e72c663ec3ed2d34a
  9 | db4daaab580f6e0c2dbbead914c5d78e
 10 | bdd2d42991ca8bd7bada6177b4a7fcf0
(10 rows)
```
на второй ноде pg-node2 добавлю пару строк и выполню запрос.
```
db_node2=# insert into test2 values (generate_series(2,10),md5(random()::text));
INSERT 0 9

db_node1=# select * from test2;
 id |               mesg               
----+----------------------------------
  1 | Строка в таблице test2 - 1
  2 | 4136f38c64ddb3fbbd5a2bd675a5983a
  3 | 84202ee7d867cecbe011663be7e79f4b
  4 | b73b12a5c34e6eceae7f353f56d92636
  5 | a02bf9c95ac8a03acfc3845676d619c5
  6 | ba511bb780d03bf58ee157cf787eb1e3
  7 | a869649b87235b5ee20180091a712313
  8 | 73afb9e1b4ad6af28874433ad335ce05
  9 | b5f3256279c1d8e415c44210d07e514d
 10 | b07fb90d4fb814ada388d611b1635a2f
(10 rows)
```
> создаю индексы для первой и второй ноде.
```
db_node1=# create unique index on test1 (id);
CREATE INDEX

db_node2=# create unique index on test2 (id);
CREATE INDEX
```
> В результате как видно что логическая репликация между node1 и node2 работает.

- __перехожу к третьему узлу - pg-node3__

> Прежде чем начать выполнения логической репликации необходимо создать те самые таблицы test1, test2. 
```
postgres=# create database db-node3;
postgres=# \c db_node3;
You are now connected to database "db_node3" as user "postgres".
db_node3=# create table test1(id integer, mesg varchar(50));
CREATE TABLE
db_node3=# create table test2(id integer, mesg varchar(50));
CREATE TABLE
```
> Подписываю и проверяю.

```
db_node3=# CREATE SUBSCRIPTION test1_3_sub CONNECTION 'host=10.128.0.35 port=5432 user=postgres password=devops123 dbname=db_node1' PUBLICATION test1_pub WITH (copy_data = false);
NOTICE:  created replication slot "test1_3_sub" on publisher
CREATE SUBSCRIPTION
db_node3=# CREATE SUBSCRIPTION test2_3_sub CONNECTION 'host=10.128.0.34 port=5432 user=postgres password=devops123 dbname=db_node2' PUBLICATION test2_pub WITH (copy_data = false);
NOTICE:  created replication slot "test2_3_sub" on publisher
CREATE SUBSCRIPTION

db_node3=# SELECT * FROM pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16391
subname               | test1_3_sub
pid                   | 5075
relid                 | 
received_lsn          | 0/17276E0
last_msg_send_time    | 2022-12-19 07:31:08.752266+00
last_msg_receipt_time | 2022-12-19 07:31:08.753486+00
latest_end_lsn        | 0/17276E0
latest_end_time       | 2022-12-19 07:31:08.752266+00
-[ RECORD 2 ]---------+------------------------------
subid                 | 16392
subname               | test2_3_sub
pid                   | 5107
relid                 | 
received_lsn          | 0/1726838
last_msg_send_time    | 2022-12-19 07:31:16.266526+00
last_msg_receipt_time | 2022-12-19 07:31:16.267223+00
latest_end_lsn        | 0/1726838
latest_end_time       | 2022-12-19 07:31:16.266526+00
```
> Выполняю запрос к таблице.

```
db_node3=# select * from test1;
 id | mesg 
----+------
(0 rows)
```
> ой а данных то нет что то пошло не так), а дело в том что 
copy_data (boolean)
Определяет, должны ли копироваться существующие данные в публикациях, на которые оформляется подписка, сразу после начала репликации. Значение по умолчанию — true. а я поставил false. 
Пересоздам подписки с условием получения всех данных:

```
db_node3=# drop subscription test1_3_sub;
NOTICE:  dropped replication slot "test1_3_sub" on publisher
DROP SUBSCRIPTION
db_node3=# drop subscription test2_3_sub;
NOTICE:  dropped replication slot "test2_3_sub" on publisher
DROP SUBSCRIPTION
db_node3=# CREATE SUBSCRIPTION test2_3_sub CONNECTION 'host=10.128.0.34 port=5432 user=postgres password=devops123 dbname=db_node2' PUBLICATION test2_pub WITH (copy_data = true);
NOTICE:  created replication slot "test2_3_sub" on publisher
CREATE SUBSCRIPTION
db_node3=# CREATE SUBSCRIPTION test1_3_sub CONNECTION 'host=10.128.0.35 port=5432 user=postgres password=devops123 dbname=db_node1' PUBLICATION test1_pub WITH (copy_data = true);
NOTICE:  created replication slot "test1_3_sub" on publisher
CREATE SUBSCRIPTION
db_node3=# SELECT * FROM pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16393
subname               | test2_3_sub
pid                   | 5260
relid                 | 
received_lsn          | 0/17268A8
last_msg_send_time    | 2022-12-19 07:36:35.942556+00
last_msg_receipt_time | 2022-12-19 07:36:35.942925+00
latest_end_lsn        | 0/17268A8
latest_end_time       | 2022-12-19 07:36:35.942556+00
-[ RECORD 2 ]---------+------------------------------
subid                 | 16394
subname               | test1_3_sub
pid                   | 5267
relid                 | 
received_lsn          | 0/1727750
last_msg_send_time    | 2022-12-19 07:36:44.54191+00
last_msg_receipt_time | 2022-12-19 07:36:44.54224+00
latest_end_lsn        | 0/1727750
latest_end_time       | 2022-12-19 07:36:44.54191+00

db_node3=# select * from test1;
 id |               mesg               
----+----------------------------------
  1 | Строка в таблице test1 - 1
  2 | 23eaa4f38c601d3577765a5fb2f518c4
  3 | c6cdacad1b1b0c53f3c955ea4a050c97
  4 | 01a24a155e8a1092b84b719c0dbbd3c4
  5 | 10c8f45436a09940700ed3efc326d109
  6 | c10a4ee0d2d9c91d7068eb1d5a313414
  7 | 7391508cde849137c03f2fe42323068d
  8 | b1885de55e33b94e72c663ec3ed2d34a
  9 | db4daaab580f6e0c2dbbead914c5d78e
 10 | bdd2d42991ca8bd7bada6177b4a7fcf0
(10 rows)

db_node3=# select * from test2;
 id |               mesg               
----+----------------------------------
  1 | Строка в таблице test2 - 1
  2 | 4136f38c64ddb3fbbd5a2bd675a5983a
  3 | 84202ee7d867cecbe011663be7e79f4b
  4 | b73b12a5c34e6eceae7f353f56d92636
  5 | a02bf9c95ac8a03acfc3845676d619c5
  6 | ba511bb780d03bf58ee157cf787eb1e3
  7 | a869649b87235b5ee20180091a712313
  8 | 73afb9e1b4ad6af28874433ad335ce05
  9 | b5f3256279c1d8e415c44210d07e514d
 10 | b07fb90d4fb814ada388d611b1635a2f
(10 rows)
```

## pg_basebackup
* __Настрою на node3 периодический бэкап баз db_node1 и db_node2__

Внесём изменения в pg_hba.conf на pg-node1 и pg-node2, разрешающее репликационное соединение пользователю postgres (без требования ввода пароля) с узла pg-node3 для работы программы pg_basebackup:

```
host replication postgres 10.128.0.33/32 trust
```
> создаю директорию для бэкапов
```
damir@pg-node3:~$ sudo mkdir /home/backup
damir@pg-node3:~$ sudo mkdir /home/backup/node1
damir@pg-node3:~$ sudo mkdir /home/backup/node2
```
> теперь выполняю саму процедуру
```
damir@pg-node3:~$ date=$(date +'%d-%m-%Y'_'%H:%M:%S')
damir@pg-node3:~$ sudo pg_basebackup -X stream -v -h 10.128.0.5 -U postgres -D /home/backup/node1/node1_$date

damir@pg-node3:~$ sudo pg_basebackup -X stream -v -h 10.128.0.34 -U postgres -D /home/backup/node1/node1_$date
pg_basebackup: initiating base backup, waiting for checkpoint to complete
pg_basebackup: checkpoint completed
pg_basebackup: write-ahead log start point: 0/2000028 on timeline 1
pg_basebackup: starting background WAL receiver
pg_basebackup: created temporary replication slot "pg_basebackup_16862"
pg_basebackup: write-ahead log end point: 0/2000138
pg_basebackup: waiting for background process to finish streaming ...
pg_basebackup: syncing data to disk ...
pg_basebackup: renaming backup_manifest.tmp to backup_manifest
pg_basebackup: base backup completed

damir@pg-node3:~$ sudo pg_basebackup -X stream -v -h 10.128.0.35 -U postgres -D /home/backup/node2/node2_$date
pg_basebackup: initiating base backup, waiting for checkpoint to complete
pg_basebackup: checkpoint completed
pg_basebackup: write-ahead log start point: 0/4000028 on timeline 1
pg_basebackup: starting background WAL receiver
pg_basebackup: created temporary replication slot "pg_basebackup_16866"
pg_basebackup: write-ahead log end point: 0/4000100
pg_basebackup: waiting for background process to finish streaming ...
pg_basebackup: syncing data to disk ...
pg_basebackup: renaming backup_manifest.tmp to backup_manifest
pg_basebackup: base backup completed
```
> проверяю директори.
```
damir@pg-node3:~$ sudo ls -l /home/backup/node1/node1_19-12-2022_08\:07\:23/
total 260
-rw------- 1 root root      3 Dec 19 08:08 PG_VERSION
-rw------- 1 root root    225 Dec 19 08:08 backup_label
-rw------- 1 root root 180794 Dec 19 08:08 backup_manifest
drwx------ 6 root root   4096 Dec 19 08:08 base
drwx------ 2 root root   4096 Dec 19 08:08 global
drwx------ 2 root root   4096 Dec 19 08:08 pg_commit_ts
drwx------ 2 root root   4096 Dec 19 08:08 pg_dynshmem
drwx------ 4 root root   4096 Dec 19 08:08 pg_logical
drwx------ 4 root root   4096 Dec 19 08:08 pg_multixact
drwx------ 2 root root   4096 Dec 19 08:08 pg_notify
drwx------ 2 root root   4096 Dec 19 08:08 pg_replslot
drwx------ 2 root root   4096 Dec 19 08:08 pg_serial
drwx------ 2 root root   4096 Dec 19 08:08 pg_snapshots
drwx------ 2 root root   4096 Dec 19 08:08 pg_stat
drwx------ 2 root root   4096 Dec 19 08:08 pg_stat_tmp
drwx------ 2 root root   4096 Dec 19 08:08 pg_subtrans
drwx------ 2 root root   4096 Dec 19 08:08 pg_tblspc
drwx------ 2 root root   4096 Dec 19 08:08 pg_twophase
drwx------ 3 root root   4096 Dec 19 08:08 pg_wal
drwx------ 2 root root   4096 Dec 19 08:08 pg_xact
-rw------- 1 root root    110 Dec 19 08:08 postgresql.auto.conf

damir@pg-node3:~$ sudo ls -l /home/backup/node2/node2_19-12-2022_08\:07\:23/
total 260
-rw------- 1 root root      3 Dec 19 08:08 PG_VERSION
-rw------- 1 root root    225 Dec 19 08:08 backup_label
-rw------- 1 root root 180630 Dec 19 08:08 backup_manifest
drwx------ 6 root root   4096 Dec 19 08:08 base
drwx------ 2 root root   4096 Dec 19 08:08 global
drwx------ 2 root root   4096 Dec 19 08:08 pg_commit_ts
drwx------ 2 root root   4096 Dec 19 08:08 pg_dynshmem
drwx------ 4 root root   4096 Dec 19 08:08 pg_logical
drwx------ 4 root root   4096 Dec 19 08:08 pg_multixact
drwx------ 2 root root   4096 Dec 19 08:08 pg_notify
drwx------ 2 root root   4096 Dec 19 08:08 pg_replslot
drwx------ 2 root root   4096 Dec 19 08:08 pg_serial
drwx------ 2 root root   4096 Dec 19 08:08 pg_snapshots
drwx------ 2 root root   4096 Dec 19 08:08 pg_stat
drwx------ 2 root root   4096 Dec 19 08:08 pg_stat_tmp
drwx------ 2 root root   4096 Dec 19 08:08 pg_subtrans
drwx------ 2 root root   4096 Dec 19 08:08 pg_tblspc
drwx------ 2 root root   4096 Dec 19 08:08 pg_twophase
drwx------ 3 root root   4096 Dec 19 08:08 pg_wal
drwx------ 2 root root   4096 Dec 19 08:08 pg_xact
-rw------- 1 root root    110 Dec 19 08:08 postgresql.auto.conf
damir@pg-node3:~$ 
```
> как видно все сбэкапилось все нормально работает. В дополнении чтоб не выполнять это все в ручную просто можно создать скрипт который будет бэкапить данные, а старые данные старше к примеру 7 дней удалять и с помощью cron выполнять ежедневно в определенное время.

> теперь проблема сдесь заключается в том что невозможно настроить обычную master-slave репликацию. Нужно менять параметры на на pg-node3. в результате репликация ломается. Перестаёт работать pg-node3. И в этом случае настрою 4 ую ноду.

> Для начала я настрою параметры главного сервера это будет нода pg-node3
```
listen_addresses = '*'
wal_level = 'logical'
max_replication_slots = 60
max_wal_senders = 80
```
* Настраиваю резервный сервер:

_Останавливаю postgresql и добавляю следующие параметры._
```
sudo pg_ctlcluster 14 main start

sudo vi /etc/postgresql/14/main/pg_hba.conf
host replication postgres 10.128.0.33/32 trust

sudo vi /etc/postgresql/14/main/postgresql.conf
listen_addresses = '*'
```
_Удаляю содержимое в папке._
```
sudo rm -rf /var/lib/postgresql/14/main
```
_Делаю бэкап  БД. Ключ -R создаст заготовку управляющего файла recovery.conf._
```
sudo -u postgres pg_basebackup -X stream -v -h 10.128.0.33 -p 5432 -R -D /var/lib/postgresql/14/main

```
_Получаю следующие конфигурации_ 
```
wal_level = 'replica'
primary_conninfo = 'user=postgres passfile=''/var/lib/postgresql/.pgpass'' channel_binding=prefer host=10.128.0.33 port=5432 sslmode=prefer sslcompression=0 sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any'
```
_Стартую кластер_
```
sudo pg_ctlcluster 12 main2 start
```
* __Проверяю результ настроек__


