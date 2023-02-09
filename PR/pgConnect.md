### Подготовка и подключения базы данных к ПО DBeaver
>Для начала создам информационную базу в кластере и пользователя

Параметры создания информационной базы на мастер узле:
```
Имя: test
Сервер баз данных: ip_balancer:9001 
Тип СУБД: PostgreSQL
База данных: test
Пользователь сервера БД: devops
Пароль пользователя сервера БД: ******
```
```
[root@pg-node1 ~]# sudo -i -u postgres psql
psql (12.13)
Введите "help", чтобы получить справку.
postgres=# create database test;
CREATE DATABASE
postgres=# CREATE USER devops WITH PASSWORD '51324ASdfQWer';
CREATE ROLE
postgres=# GRANT ALL PRIVILEGES ON DATABASE "test" to devops;
GRANT
postgres=# \c test 
Вы подключены к базе данных "test" как пользователь "postgres".
test=# GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "devops";
GRANT
```

Проверяю подключения к базе.
```
psql -U devops -h 35.232.96.109 -p 9001 -d test -W
Пароль: 
psql (12.13 (Ubuntu 12.13-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

test=> 
```