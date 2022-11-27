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
            737 |          51569
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
            738 |          51587
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
            739 |          51702
  (1 row)

  update hw10 set i = 5 where i = 1;
  ```
    * _проверяю лог postgres просматириваю информацию о блокировках._
  ```
  damir@postgres-node-1:~$ cat /var/log/postgresql/postgresql-14-main.log
  2022-11-27 09:28:48.214 UTC [51587] postgres@hw10 LOG:  process 51587 still waiting for ShareLock on transaction 737 after 200.167 ms
  2022-11-27 09:28:48.214 UTC [51587] postgres@hw10 DETAIL:  Process holding the lock: 51569. Wait queue: 51587.
  2022-11-27 09:28:48.214 UTC [51587] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
  2022-11-27 09:28:48.214 UTC [51587] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 09:43:17.912 UTC [51702] postgres@hw10 LOG:  process 51702 still waiting for ExclusiveLock on tuple (0,1) of relation 16385 of database 16384 after 200.174 ms
  2022-11-27 09:43:17.912 UTC [51702] postgres@hw10 DETAIL:  Process holding the lock: 51587. Wait queue: 51702.
  2022-11-27 09:43:17.912 UTC [51702] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 10:05:01.592 UTC [51587] postgres@hw10 LOG:  process 51587 acquired ShareLock on transaction 737 after 2173577.250 ms
  2022-11-27 10:05:01.592 UTC [51587] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
  2022-11-27 10:05:01.592 UTC [51587] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 10:05:01.592 UTC [51702] postgres@hw10 LOG:  process 51702 acquired ExclusiveLock on tuple (0,1) of relation 16385 of database 16384 after 1303879.529 ms
  2022-11-27 10:05:01.592 UTC [51702] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  2022-11-27 10:05:01.792 UTC [51702] postgres@hw10 LOG:  process 51702 still waiting for ShareLock on transaction 738 after 200.159 ms
  2022-11-27 10:05:01.792 UTC [51702] postgres@hw10 DETAIL:  Process holding the lock: 51587. Wait queue: 51702.
  2022-11-27 10:05:01.792 UTC [51702] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
  2022-11-27 10:05:01.792 UTC [51702] postgres@hw10 STATEMENT:  update hw10 set i = 5 where i = 1;
  ```
  ну здесь я наблюдаю транзакция по созданию индекса отрабатывается значительно дольше 200mc.


    * _просматриваю блокировки для транзакции для каждой сессий._
      * Проверяю первую сессию.
      

      
      ```
      hw10=*# SELECT * FROM locks WHERE pid = 51569;
        pid  |   locktype    |  lockid  |       mode       | granted 
      -------+---------------+----------+------------------+---------
       51569 | relation      | pg_locks | AccessShareLock  | t
       51569 | relation      | locks    | AccessShareLock  | t
       51569 | relation      | hw10     | RowExclusiveLock | t
       51569 | virtualxid    | 4/92     | ExclusiveLock    | t
       51569 | transactionid | 747      | ExclusiveLock    | t
      (5 rows)
      ```
      > Описываю свои наблюдения, то есть pid процесса, который запросил 5 блокировак 2 блокировки на отношения - locks и таблицу pg_locks + 1 блокировка виртуального номера транзакции. В режиме чтения (AccessShareLock) и получаю их - granted = true
      Наблюдаю тип relation для hw10 в режиме RowExclusiveLock - устанавливается на изменяемое отношения.
      Наблюдаю тип virtualxid и transactionid в режиме ExclusiveLock - удерживаются каждой транзакцией для самой себя.
      
            
      * Проверяю вторую сессию.
      ```
       hw10=*# SELECT * FROM locks WHERE pid = 51587
        hw10-*# ;
        pid  |   locktype    | lockid |       mode       | granted 
      -------+---------------+--------+------------------+---------
       51587 | relation      | hw10   | RowExclusiveLock | t
       51587 | virtualxid    | 5/5    | ExclusiveLock    | t
       51587 | transactionid | 742    | ExclusiveLock    | t
       51587 | tuple         | hw10:1 | ExclusiveLock    | t
       51587 | transactionid | 741    | ShareLock        | f
      (5 rows)
      ```
      > Транзакция ожидает получение блокировки типа transactionid в режиме ShareLock для первой транзакции.
      Удерживается блокировка типа tuple для обновляемой строки.
      Наблюдаю "подвисание" команды! А в locks появился запрос блокировки ShareLock (смотрим таблицу совместимости), которая не может быть получена (granted f)



      * Проверяю третью сессию.
      ```
      hw10=*# SELECT * FROM locks WHERE pid = 51702;
        pid  |   locktype    | lockid |       mode       | granted 
      -------+---------------+--------+------------------+---------
       51702 | relation      | hw10   | RowExclusiveLock | t
       51702 | virtualxid    | 6/2    | ExclusiveLock    | t
       51702 | transactionid | 743    | ExclusiveLock    | t
       51702 | tuple         | hw10:1 | ExclusiveLock    | f
       (4 rows)
       ```
      > Транзакция ожидает получение блокировки типа tuple для обновляемой строки
      
        * Общий вид текущих ожиданий просматриваю в pg_stat_activity
      
      ```
      hw10=*# SELECT pid, wait_event_type, wait_event, pg_blocking_pids(pid) FROM pg_stat_activity WHERE backend_type = 'client backend';
        pid  | wait_event_type |  wait_event   | pg_blocking_pids 
      -------+-----------------+---------------+------------------
       51569 |                 |               | {}
       51587 | Lock            | transactionid | {51569}
       51702 | Lock            | tuple         | {51587}
      (3 rows)
      ```
      
        * Теперь завершаю первую сессию выполню  rollback.

      ```
      hw10=# SELECT * FROM locks WHERE pid = 51569;
       pid | locktype | lockid | mode | granted 
      -----+----------+--------+------+---------
      (0 rows)

      hw10=# SELECT * FROM locks WHERE pid = 51587;
        pid  |   locktype    | lockid |       mode       | granted 
      -------+---------------+--------+------------------+---------
       51587 | relation      | hw10   | RowExclusiveLock | t
       51587 | virtualxid    | 5/2    | ExclusiveLock    | t
       51587 | transactionid | 738    | ExclusiveLock    | t
       (3 rows)

       hw10=# SELECT * FROM locks WHERE pid = 51702;
        pid  |   locktype    | lockid |       mode       | granted 
      -------+---------------+--------+------------------+---------
       51702 | relation      | hw10   | RowExclusiveLock | t
       51702 | virtualxid    | 6/2    | ExclusiveLock    | t
       51702 | transactionid | 738    | ShareLock        | f
       51702 | tuple         | hw10:1 | ExclusiveLock    | t
       51702 | transactionid | 739    | ExclusiveLock    | t
       (5 rows)
       hw10=# 
       ```
      >после фиксации изменений в первой сессии - все блокировки уходят
      Наблюдаю как вторая транзакция (create index) получает запрошенную блокировку (ShareLock) и выполняет построение индекса и так же при завршении второй транзакции.
    
      Делаю rollback во всех сеансах.
 * __Взаимоблокировка трех транзакций.__
    
    * Session-1 
    ```
    begin;
    update hw10 set i = 1 where i = 1;
    ```
    * Session-2 
    ```
    begin;
    update hw10 set i = 1 where i = 2;
    ```
    * Session-3
    ```
    begin;
    update hw10 set i = 1 where i = 3;
    ```
    
    * Session-1
    ```
    update hw10 set i = 1 where i = 2;
    ```
    * Session-2
    ```
    update hw10 set i = 1 where i = 3;
    ```
    * Session-3
    ```
    update hw10 set i = 1 where i = 1;
    ERROR:  deadlock detected
    DETAIL:  Process 53628 waits for ShareLock on transaction 749; blocked by process 53604.
    Process 53604 waits for ShareLock on transaction 750; blocked by process 53622.
    Process 53622 waits for ShareLock on transaction 751; blocked by process 53628.
    HINT:  See server log for query details.
    CONTEXT:  while updating tuple (0,1) in relation "hw10"
    ```
    >Возникла ошибка Deadlock при попытке обновления, тоесть в трех сессиях две сессии уже висят и в просессе мы запскаем третий что привел к данной ошибки дригими словами возникла блокировка в многопроцессорной обработке.

   * Открываю и смотрю логи.
   ```
   damir@postgres-node-1:~$ tail -n 20 /var/log/postgresql/postgresql-14-main.log
   2022-11-27 12:46:09.163 UTC [53622] postgres@hw10 DETAIL:  Process holding the lock: 53628. Wait queue: 53622.
   2022-11-27 12:46:09.163 UTC [53622] postgres@hw10 CONTEXT:  while updating tuple (0,3) in relation "hw10"
   2022-11-27 12:46:09.163 UTC [53622] postgres@hw10 STATEMENT:  update hw10 set i = 1 where i = 3;
   2022-11-27 12:46:39.131 UTC [53628] postgres@hw10 LOG:  process 53628 detected deadlock while waiting for ShareLock on transaction 749 after 200.209 ms
   2022-11-27 12:46:39.131 UTC [53628] postgres@hw10 DETAIL:  Process holding the lock: 53604. Wait queue: .
   2022-11-27 12:46:39.131 UTC [53628] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
   2022-11-27 12:46:39.131 UTC [53628] postgres@hw10 STATEMENT:  update hw10 set i = 1 where i = 1;
   2022-11-27 12:46:39.132 UTC [53628] postgres@hw10 ERROR:  deadlock detected
   2022-11-27 12:46:39.132 UTC [53628] postgres@hw10 DETAIL:  Process 53628 waits for ShareLock on transaction 749; blocked by process 53604.
	 Process 53604 waits for ShareLock on transaction 750; blocked by process 53622.
	 Process 53622 waits for ShareLock on transaction 751; blocked by process 53628.
	 Process 53628: update hw10 set i = 1 where i = 1;
	 Process 53604: update hw10 set i = 1 where i = 2;
	 Process 53622: update hw10 set i = 1 where i = 3;
   2022-11-27 12:46:39.132 UTC [53628] postgres@hw10 HINT:  See server log for query details.
   2022-11-27 12:46:39.132 UTC [53628] postgres@hw10 CONTEXT:  while updating tuple (0,1) in relation "hw10"
   2022-11-27 12:46:39.132 UTC [53628] postgres@hw10 STATEMENT:  update hw10 set i = 1 where i = 1;
   2022-11-27 12:46:39.133 UTC [53622] postgres@hw10 LOG:  process 53622 acquired ShareLock on transaction 751 after 30169.830 ms
   2022-11-27 12:46:39.133 UTC [53622] postgres@hw10 CONTEXT:  while updating tuple (0,3) in relation "hw10"
   2022-11-27 12:46:39.133 UTC [53622] postgres@hw10 STATEMENT:  update hw10 set i = 1 where i = 3;
   ```











      
  