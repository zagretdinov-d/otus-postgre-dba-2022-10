# Lesson 7
### Тема: Логический уровень PostgreSQL

* __Цель:__

  * создание новой базы данных, схемы и таблицы
  * создание роли для чтения данных из созданной схемы созданной базы данных
  * создание роли для чтения и записи из созданной схемы созданной базы данных

### Решение:
1 создайте новый кластер PostgresSQL 14
2 зайдите в созданный кластер под пользователем postgres
3 создайте новую базу данных testdb
4 зайдите в созданную базу данных под пользователем postgres
5 создайте новую схему testnm
6 создайте новую таблицу t1 с одной колонкой c1 типа integer
7 вставьте строку со значением c1=1
8 создайте новую роль readonly
9 дайте новой роли право на подключение к базе данных testdb
10 дайте новой роли право на использование схемы testnm
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

