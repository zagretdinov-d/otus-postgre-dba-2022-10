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

__14 захожу под пользователем testread в базу данных testdb__
```
damir@node-2:~$ psql -U testread -h 127.0.0.1 -W -d testdb
Password: 
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

testdb=> 
```
__15 Делаю select * from t1;__
```
testdb=> SELECT * FROM t1;
ERROR:  permission denied for table t1
```
> Не получилось выполнить запрос, так как у нас право на выполнение select только для схемы testnm
Согласно шпаргалке таблица создана в схеме public а не testnm и прав на public для роли readonly не давали.
потому что в search_path скорее всего user, public при том что схемы $USER нет то таблица по умолчанию создалась в public


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
__18 удаляю таблицу t1__

```
testdb=# drop TABLE t1;
DROP TABLE
```
__19 создаю ее заново но уже с явным указанием имени схемы testnm__
```
testdb=# CREATE TABLE testnm.t1(c1 integer);
CREATE TABLE

testdb=# \dt testnm.*
        List of relations
 Schema | Name | Type  |  Owner   
--------+------+-------+----------
 testnm | t1   | table | postgres
(1 row)

testdb=#

```

__20 вставляю строку со значением c1=1__
```
testdb=# INSERT INTO testnm.t1 values(1);
INSERT 0 1
```
__21 захожу под пользователем testread в базу данных testdb и выполню select * from testnm.t1;__

```
damir@node-2:~$ psql -U testread -h 127.0.0.1 -W -d testdb
Password: 
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
testdb=> 
```
> соответственно не получилось потому что __grant SELECT on all TABLEs in SCHEMA testnm TO readonly;__ дал доступ только для существующих на тот момент времени таблиц а t1 пересоздавалась.

__22 возвращаюсь в базу данных testdb под пользователем postgres__

```
sudo -u postgres psql

\c testdb
```
__23 даю роль readonly и право на select для всех таблиц схемы testnm__
```
testdb=# ALTER DEFAULT PRIVILEGES IN SCHEMA testnm GRANT SELECT ON TABLES to readonly;
ALTER DEFAULT PRIVILEGES
testdb=# GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;
GRANT
testdb=#
```
__24 захожу под пользователем testread в базу данных testdb__
```
damir@node-2:~$ psql -U testread -h 127.0.0.1 -W -d testdb
Password: 
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.
```
>авторизирую \c testdb testread; и выполняю select * from testnm.t1;
```
testdb=>  \c testdb testread;
Password for user testread: 
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
You are now connected to database "testdb" as user "testread".
testdb=> select * from testnm.t1;
 c1 
----
  1
(1 row)

testdb=> 
```
> Получилось УРА!!! ALTER DEFAULT будет действовать для новых таблиц, а GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly; отработал только для существующих на тот момент времени
Надо было сделать снова GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly; или пересоздать таблицу

__25 выполняю команду create table t2(c1 integer); insert into t2 values (2);__

```
testdb=> create table t2(c1 integer);
CREATE TABLE
testdb=> insert into t2 values (2);
INSERT 0 1
testdb=> 
```
  * t2 была создана в схеме public, которая указана в search_path

```
testdb=> select * from pg_namespace;
  oid  |      nspname       | nspowner |                   nspacl                   
-------+--------------------+----------+--------------------------------------------
    99 | pg_toast           |       10 | 
    11 | pg_catalog         |       10 | {postgres=UC/postgres,=U/postgres}
  2200 | public             |       10 | {postgres=UC/postgres,=UC/postgres}
 13360 | information_schema |       10 | {postgres=UC/postgres,=U/postgres}
 16385 | testnm             |       10 | {postgres=UC/postgres,readonly=U/postgres}
(5 rows)

testdb=> 
testdb=> show search_path;
   search_path   
-----------------
 "$user", public
(1 row)

```
> __Ответ:__ Каждый пользователь может по умолчанию создавать объекты в схеме public любой базы данных, если у него есть право на подключение к этой базе данных. Лучше конечно убирать права у public.


__26 Чтобы раз и навсегда забыть про роль public - а в продакшн базе данных убираю права у роли public для схем public и для базы данных__

```
damir@node-2:~$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# \c testdb
You are now connected to database "testdb" as user "postgres".
testdb=# \dn
  List of schemas
  Name  |  Owner   
--------+----------
 public | postgres
 testnm | postgres
(2 rows)

testdb=# revoke create on schema public from public;
REVOKE
testdb=# revoke all on database testdb from public;
REVOKE
testdb=# 
```
__27 теперь выполняю от пользователя testread__
```
damir@node-2:~$ psql -U testread -h 127.0.0.1 -W -d testdb
Password: 
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

testdb=> \c testdb
Password: 
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
You are now connected to database "testdb" as user "testread".
testdb=> create table t3 (c1 integer);
ERROR:  permission denied for schema public
```
от пользователя testread не создаются объекты в схеме public.
```
testdb=> \dp testnm.*
                                Access privileges
 Schema | Name | Type  |     Access privileges     | Column privileges | Policies 
--------+------+-------+---------------------------+-------------------+----------
 testnm | t1   | table | postgres=arwdDxt/postgres+|                   | 
        |      |       | readonly=r/postgres       |                   | 
(1 row)

testdb=> \dp public.*
                            Access privileges
 Schema | Name | Type  | Access privileges | Column privileges | Policies 
--------+------+-------+-------------------+-------------------+----------
 public | t2   | table |                   |                   | 
(1 row)

testdb=> 
```
