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




11 дайте новой роли право на select для всех таблиц схемы testnm
12 создайте пользователя testread с паролем test123
13 дайте роль readonly пользователю testread
14 зайдите под пользователем testread в базу данных testdb
15 сделайте select * from t1;
16 получилось? (могло если вы делали сами не по шпаргалке и не упустили один существенный момент про который позже)
17 напишите что именно произошло в тексте домашнего задания
18 у вас есть идеи почему? ведь права то дали?
19 посмотрите на список таблиц
20 подсказка в шпаргалке под пунктом 20
21 а почему так получилось с таблицей (если делали сами и без шпаргалки то может у вас все нормально)
22 вернитесь в базу данных testdb под пользователем postgres
23 удалите таблицу t1
24 создайте ее заново но уже с явным указанием имени схемы testnm
25 вставьте строку со значением c1=1
26 зайдите под пользователем testread в базу данных testdb
27 сделайте select * from testnm.t1;
28 получилось?
29 есть идеи почему? если нет - смотрите шпаргалку
30 как сделать так чтобы такое больше не повторялось? если нет идей - смотрите шпаргалку
31 сделайте select * from testnm.t1;
32 получилось?
33 есть идеи почему? если нет - смотрите шпаргалку
31 сделайте select * from testnm.t1;
32 получилось?
33 ура!
34 теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);
35 а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly?
36 есть идеи как убрать эти права? если нет - смотрите шпаргалку
37 если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку - объясните что сделали и почему выполнив указанные в ней команды
38 теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);
39 расскажите что получилось и почему 

