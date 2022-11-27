# Lesson 10
### Тема: Механизм блокировок

* __Цель:__

  * понимать как работает механизм блокировок объектов и строк

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
* __запускаем psql__
```
sudo -u postgres psql
```
* __Настраиваю логирования так, чтобы в журнал сообщений сбрасывалась информация о блокировках, удерживаемых более 200 миллисекунд__
  * Включаю логирование
  ```
  select current_setting('log_lock_waits');
  current_setting 
  -----------------
  on
  (1 row)
  ```
  * В моем случае он уже включен но если не включен используется следующая команда.
  ```
  ALTER SYSTEM SET log_lock_waits = 'on';
  SELECT name, setting, context, short_desc FROM pg_settings where name = 'log_lock_waits';
        name      | setting |  context  |      short_desc       
  ----------------+---------+-----------+-----------------------
   log_lock_waits | on      | superuser | Logs long lock waits.
  (1 row)
  ```
  * Применения настроек.
  ``` 
  postgres=# SELECT pg_reload_conf();
  pg_reload_conf 
  ----------------
  t
  (1 row)
  ```
  * Включаю удерживаемое более 200 миллисекунд.
  ```
  postgres=# select current_setting('deadlock_timeout');
  current_setting 
  -----------------
  1s
  (1 row)

  postgres=# ALTER SYSTEM SET deadlock_timeout = '200';
  ALTER SYSTEM
  postgres=# SELECT pg_reload_conf();
  pg_reload_conf 
  ----------------
  t
  (1 row)

  postgres=# SELECT name, setting, context, short_desc FROM pg_settings where name = 'deadlock_timeout';
         name       | setting |  context  |                          short_desc                           
  ------------------+---------+-----------+---------------------------------------------------------------
   deadlock_timeout | 200     | superuser | Sets the time to wait on a lock before checking for deadlock.
  (1 row)
  ```
  * Создаю тестовую бд и таблицу.
  ```
  postgres=# create database hw10;
  CREATE DATABASE
  postgres=# \c hw10
  You are now connected to database "hw10" as user "postgres".
  hw10=# create table hw10 (i int);
  CREATE TABLE
  hw10=# insert into hw10 values (1),(2),(3);
  INSERT 0 3
  ```
  
  * Cоздаю view просмотр блокировок.
  ```
  CREATE VIEW locks AS
  SELECT pid,
       locktype,
       CASE locktype
         WHEN 'relation' THEN relation::REGCLASS::text
         WHEN 'virtualxid' THEN virtualxid::text
         WHEN 'transactionid' THEN transactionid::text
         WHEN 'tuple' THEN relation::REGCLASS::text||':'||tuple::text
       END AS lockid,
       mode,
       granted
  FROM pg_locks;
  ```
* __Смоделирую ситуацию обновления одной и той же строки тремя командами UPDATE в разных сеансах.__

  * _session 1_
  ```
  hw10=# begin;
  BEGIN
  hw10=*# SELECT txid_current(), pg_backend_pid();
   txid_current | pg_backend_pid 
  --------------+----------------
            741 |          49871
  (1 row)


  update hw10 set i = 5 where i = 1;
  ```

  * _session 2_
  ```
  hw10=# begin;
  BEGIN
  hw10=*# SELECT txid_current(), pg_backend_pid();
   txid_current | pg_backend_pid 
  --------------+----------------
            742 |          49899
  (1 row)


  update hw10 set i = 5 where i = 1;
  ```
  * _session 3_
  ```
  hw10=# begin;
  BEGIN
  hw10=*# SELECT txid_current(), pg_backend_pid();
   txid_current | pg_backend_pid 
  --------------+----------------
            743 |          49911
  (1 row)

  update hw10 set i = 5 where i = 1;
  ```
    * _проверяю лог postgres просматириваю информацию о блокировках._
  ```
  damir@postgres-node-1:~$ cat /var/log/postgresql/postgresql-14-main.log
  2022-11-27 05:09:27.168 UTC [48369] postgres@hw10 LOG:  process 48369 still waiting for ShareLock on transaction 742 after 200.274 ms
  2022-11-27 05:09:27.168 UTC [48369] postgres@hw10 DETAIL:  Process holding the lock: 48192. Wait queue: 48369.
  2022-11-27 05:09:27.168 UTC [48369] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
  2022-11-27 05:09:27.168 UTC [48369] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 05:09:39.263 UTC [48373] postgres@hw10 LOG:  process 48373 still waiting for ExclusiveLock on tuple (0,1) of relation 16385 of database 16384 after 200.185 ms
  2022-11-27 05:09:39.263 UTC [48373] postgres@hw10 DETAIL:  Process holding the lock: 48369. Wait queue: 48373.
  2022-11-27 05:09:39.263 UTC [48373] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 05:10:46.595 UTC [48369] postgres@hw10 LOG:  process 48369 acquired ShareLock on transaction 742 after 79628.086 ms
  2022-11-27 05:10:46.595 UTC [48369] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
  2022-11-27 05:10:46.595 UTC [48369] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 05:10:46.596 UTC [48373] postgres@hw10 LOG:  process 48373 acquired ExclusiveLock on tuple (0,1) of relation 16385 of database 16384 after 67532.729 ms
  2022-11-27 05:10:46.596 UTC [48373] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 05:10:46.796 UTC [48373] postgres@hw10 LOG:  process 48373 still waiting for ShareLock on transaction 743 after 200.165 ms
  2022-11-27 05:10:46.796 UTC [48373] postgres@hw10 DETAIL:  Process holding the lock: 48369. Wait queue: 48373.
  2022-11-27 05:10:46.796 UTC [48373] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
  2022-11-27 05:10:46.796 UTC [48373] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  ```

    * _просматриваю блокировки для транзакции для каждой сессий._
      * Проверяю первую сессию.
      

      
      ```
      hw10=*# SELECT * FROM locks WHERE pid = 48810;
        pid  |   locktype    |  lockid  |       mode       | granted 
      -------+---------------+----------+------------------+---------
       48810 | relation      | pg_locks | AccessShareLock  | t
       48810 | relation      | locks    | AccessShareLock  | t
       48810 | relation      | hw10     | RowExclusiveLock | t
       48810 | virtualxid    | 4/92     | ExclusiveLock    | t
       48810 | transactionid | 747      | ExclusiveLock    | t
      (5 rows)
      ```
      > Описываю свои наблюдения, то есть pid процесса, который запросил 5 блокировак 2 блокировки на отношения - locks и таблицу pg_locks + 1 блокировка виртуального номера транзакции. в режиме чтения (AccessShareLock) и получаю их - granted = true
      Наблюдаю тип relation для hw10 в режиме RowExclusiveLock - устанавливается на изменяемое отношения.
      Наблюдаю тип virtualxid и transactionid в режиме ExclusiveLock - удерживаются каждой транзакцией для самой себя.
      
            
      * Проверяю вторую сессию.
      ```
       hw10=*# SELECT * FROM locks WHERE pid = 49899
        hw10-*# ;
        pid  |   locktype    | lockid |       mode       | granted 
      -------+---------------+--------+------------------+---------
       49899 | relation      | hw10   | RowExclusiveLock | t
       49899 | virtualxid    | 5/5    | ExclusiveLock    | t
       49899 | transactionid | 742    | ExclusiveLock    | t
       49899 | tuple         | hw10:1 | ExclusiveLock    | t
       49899 | transactionid | 741    | ShareLock        | f
      (5 rows)
      ```
      > Транзакция ожидает получение блокировки типа transactionid в режиме ShareLock для первой транзакции.
      Удерживается блокировка типа tuple для обновляемой строки.
      Наблюдаю "подвисание" команды! А в locks появился запрос блокировки ShareLock (смотрим таблицу совместимости), которая не может быть получена (granted f)



      * Проверяю третью сессию.
      ```
      hw10=*# SELECT * FROM locks WHERE pid = 49911;
        pid  |   locktype    | lockid |       mode       | granted 
      -------+---------------+--------+------------------+---------
       49911 | relation      | hw10   | RowExclusiveLock | t
       49911 | virtualxid    | 6/2    | ExclusiveLock    | t
       49911 | transactionid | 743    | ExclusiveLock    | t
       49911 | tuple         | hw10:1 | ExclusiveLock    | f
       (4 rows)
       ```
      > Транзакция ожидает получение блокировки типа tuple для обновляемой строки
      Теперь завершаю первую сессию к примеру выполню  rollback.
      
