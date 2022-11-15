# Lesson 7
### Тема: Логический уровень PostgreSQL

* __Цель:__

  * создание новой базы данных, схемы и таблицы
  * создание роли для чтения данных из созданной схемы созданной базы данных
  * создание роли для чтения и записи из созданной схемы созданной базы данных

### Решение:
__1 Cоздаю новый кластер PostgresSQL 14__
  * _c помощью скрипта состоящий из команд устанавливаю PostgresSQL 14._
```
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-14
```
  * _Проверяю сам кластер_
```
damir@node-2:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
```

__2 захожу под пользователем postgres__
```
damir@node-2:~$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# 
```

__3 создайте новую базу данных testdb__

```
postgres=# CREATE DATABASE testdb;
CREATE DATABASE
postgres=#
```
__4 захожу в созданную базу данных под пользователем postgres__
```
postgres=# \c testdb;
You are now connected to database "testdb" as user "postgres".
testdb=# \conninfo
You are connected to database "testdb" as user "postgres" via socket in "/var/run/postgresql" at port "5432".
```
__5 создайте новую схему testnm__
```
testdb=# CREATE SCHEMA testnm;
CREATE SCHEMA
```

__6 создаю новую таблицу t1 с одной колонкой c1 типа integer__
```
testdb=# CREATE TABLE t1(c1 integer);
CREATE TABLE
```

__7 вставляю строку со значением c1=1__
```
testdb=# INSERT INTO t1 values(1);
INSERT 0 1
```

__8 создаю новую роль readonly__
```
testdb=# CREATE role readonly;
CREATE ROLE
```

__9 даю новую роль право на подключение к базе данных testdb__
```
testdb=# grant connect on DATABASE testdb TO readonly;
GRANT
```

__10 дайте новой роли право на использование схемы testnm__

```
grant usage on SCHEMA testnm to readonly;
```
__11 дайте новой роли право на select для всех таблиц схемы testnm__
```
testdb=# grant SELECT on all TABLEs in SCHEMA testnm TO readonly;
GRANT
```

__12 создайте пользователя testread с паролем test123__
```
testdb=# CREATE USER testread with password 'test123'
testdb-# ;
CREATE ROLE
```
__13 дайте роль readonly пользователю testread__
```
testdb=# grant readonly TO testread;
GRANT ROLE
```
__14 зайдите под пользователем testread в базу данных testdb__
```
testdb=# 
Password for user testread: 
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
You are now connected to database "testdb" as user "testread" on host "*" (address "127.0.0.1") at port "5432".
```
__15 Делаю select * from t1;__
```
testdb=> SELECT * FROM t1;
ERROR:  permission denied for table t1
```
___Пояснение и моё решения которое решил применить:___
  * Не получилось так как у пользователя нет прав доступа к этой конкретной таблице.
  * Необходимо предоставить все привилегии проблемному пользователю. 
  * Подключаюсь к пользователю, который является суперпользователем.
  * Подключаюсь к базе данных testdb, в которой существует таблица t1.
  * Затем выполняю следующую команду, чтобы предоставить все привилегии пользователю testread в таблице «t1».

```
damir@node-2:~$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# \c testdb
You are now connected to database "testdb" as user "postgres".
testdb=# GRANT ALL PRIVILEGES ON TABLE t1 TO testread;
GRANT
testdb=# \c testdb testread *
Password for user testread: 
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
You are now connected to database "testdb" as user "testread" on host "*" (address "127.0.0.1") at port "5432".
testdb=> SELECT * FROM t1;
 c1 
----
  1
(1 row)

testdb=> 

```
  * В результате все успешно получилось.

__16 посмотр на список таблиц__
```
testdb=> \dt
        List of relations
 Schema | Name | Type  |  Owner   
--------+------+-------+----------
 public | t1   | table | postgres
(1 row)
 
testdb=> 
```
  * Согласно шпаргалке таблица создана в схеме public а не testnm и прав на public для роли readonly не давали.
  * потому что в search_path скорее всего "$user", public при том что схемы $USER нет то таблица по умолчанию создалась в public


__17 вернулся в базу данных testdb под пользователем postgres__
```
damir@node-2:~$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# \c testdb postgres
You are now connected to database "testdb" as user "postgres".
testdb=#
```
__18 удалите таблицу t1__

```
testdb=# drop TABLE t1;
DROP TABLE
```
__24 создайте ее заново но уже с явным указанием имени схемы testnm__
```
testdb=# CREATE TABLE testnm.t1(c1 integer);
CREATE TABLE
```

__25 вставьте строку со значением c1=1__
```
testdb=# INSERT INTO testnm.t1 values(1);
INSERT 0 1
```
__26 захожу под пользователем testread в базу данных testdb и выполню select * from testnm.t1;__

```
testdb=# \c testdb testread *
Password for user testread: 
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
You are now connected to database "testdb" as user "testread" on host "*" (address "127.0.0.1") at port "5432".
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
testdb=> 
```
соответственно не получилось потому что grant SELECT on all TABLEs in SCHEMA testnm TO readonly дал доступ только для существующих на тот момент времени таблиц а t1 пересоздавалась.

__27 Добавляю согласно шпаргалке команды и проверяю и делаю select * from testnm.t1;__

```
postgres=# \c testdb postgres
You are now connected to database "testdb" as user "postgres".
testdb=# ALTER default privileges in SCHEMA testnm grant SELECT on TABLEs to readonly;
ALTER DEFAULT PRIVILEGES
testdb=# \c testdb testread;
connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: FATAL:  Peer authentication failed for user "testread"
Previous connection kept
testdb=# \c testdb testread *
Password for user testread: 
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
You are now connected to database "testdb" as user "testread" on host "*" (address "127.0.0.1") at port "5432".
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
testdb=> 
```

Как видно снова не получилось потому что ALTER default будет действовать для новых таблиц а grant SELECT on all TABLEs in SCHEMA testnm TO readonly отработал только для существующих на тот момент времени. надо сделать снова или grant SELECT или пересоздать таблицу
```
postgres=# \c testdb postgres;
You are now connected to database "testdb" as user "postgres".
testdb=# grant SELECT on all TABLEs in SCHEMA testnm TO readonly
testdb-# ;
GRANT
testdb=# \c testdb testread *
Password for user testread: 
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
You are now connected to database "testdb" as user "testread" on host "*" (address "127.0.0.1") at port "5432".
testdb=> select * from testnm.t1;
 c1 
----
  1
(1 row)

testdb=> 
```
теперь все получилось!


28 теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);


35 а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly?
36 есть идеи как убрать эти права? если нет - смотрите шпаргалку
37 если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку - объясните что сделали и почему выполнив указанные в ней команды
38 теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);
39 расскажите что получилось и почему 

