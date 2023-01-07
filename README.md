# Lesson 15
### Тема: Работа с индексами, join'ами, cтатистикой

####Цель:
* __знать и уметь применять основные виды индексов PostgreSQL__
* __строить и анализировать план выполнения запроса__
* __уметь оптимизировать запросы для с использованием индексов__
* __знать и уметь применять различные виды join'ов__
* __строить и анализировать план выполенения запроса__
* __оптимизировать запрос__
* __уметь собирать и анализировать статистику для таблицы__



### Решение:

* Для выполнения поставленных целей разворачиваю GCE инстанс типа e2-medium
```
damir@Damir:~$ gcloud beta compute instances create postgres- \
--machine-type=e2-medium \
--image-family ubuntu-2004-lts \
--image-project=ubuntu-os-cloud \
--boot-disk-size=10GB \
--boot-disk-type=pd-ssd \
--tags=postgres \
--restart-on-failure
```
В результате получаю.
```
Created [https://www.googleapis.com/compute/beta/projects/pg-devops1988-10/zones/europe-central2-c/instances/pg-host].
NAME     ZONE               MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
pg-host  europe-central2-c  e2-medium                  10.186.0.8   34.116.210.208  RUNNING
```
Подключаюсь к VM и устанавливаем Postgres 14 с дефолтными настройками

```
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-14
```
проверяю статус postgre
```
damir@pg-host:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
```
### 1 вариант:

* Создаю индексы на БД, которые ускорят доступ к данным.
___Навыки:___
  - определения узких мест
  - написания запросов для создания индекса
  - оптимизации

* __Решение__

  - Создаю базу данных с таблицей orders и заполняю её данными:
  ```
  postgres=# create database db_ind;
  CREATE DATABASE
  postgres=# \c db_ind
  You are now connected to database "db_ind" as user "postgres".
  db_ind=# create table orders(id int, user_id int, order_date date, status text, some_text text);
  db_ind=# insert into orders(id, user_id, order_date, status, some_text)
  db_ind-# select generate_series, (random() * 70), date'2021-01-01' + (random() * 300)::int as order_date
  db_ind-#         , (array['returned', 'completed', 'placed', 'shipped'])[(random() * 4)::int]
  db_ind-#         , concat_ws(' ', (array['go', 'space', 'sun', 'London'])[(random() * 5)::int]
  db_ind(#         , (array['the', 'capital', 'of', 'Great', 'Britain'])[(random() * 6)::int]
  db_ind(#         , (array['some', 'another', 'example', 'with', 'words'])[(random() * 6)::int]
  db_ind(#         )
  db_ind-# from generate_series(1, 5000000);
  INSERT 0 5000000
  ```
  - результат команды explain,

  ```
  db_ind=# explain
  select * from orders where id<10000000;
                                       QUERY PLAN                                    
  ---------------------------------------------------------------------------------
   Seq Scan on orders  (cost=0.00..102556.88 rows=4999650 width=34)
     Filter: (id < 10000000)
   JIT:
     Functions: 2
     Options: Inlining false, Optimization false, Expressions true, Deforming true
  (5 rows)
  ```

  - проверяю размер таблицы
  ```
  db_ind=# select pg_size_pretty(pg_table_size('orders'));
  pg_size_pretty 
  ----------------
  313 MB
  (1 row)

  ```
  
* __Реализовация индекса для полнотекстового поиска__
    * создаю индекс по колонке id
  ```
  db_ind=# create index idx_ord_id on orders(id);
  CREATE INDEX
  ```
  - проверяю план запроса - использования индекса
  ```
  db_ind=# explain
  db_ind-# select * from orders where id<1000000;
                                       QUERY PLAN                                     
  ------------------------------------------------------------------------------------
   Index Scan using idx_ord_id on orders  (cost=0.43..36907.11 rows=1011467      width=34)
     Index Cond: (id < 1000000)
  (2 rows)
  ```
  > Используется оператор Index Scan предназначен для сканирования всех записей некластеризованного индекса.
  вообщеи проверил индекс для таблицы orders, тоже успешно работает

  - размер индекса
  
  ```
  db_ind=# select pg_size_pretty(pg_table_size('idx_ord_id'));
   pg_size_pretty 
  ----------------
   107 MB
  (1 row)
  ```
* __Создание индекса на несколько полей__
  - выполняю запрос 
  ```
  explain
  select order_date, status
  from orders
  where order_date between date'2022-01-01' and date'2022-02-01'
          and status = 'placed';
  Gather  (cost=1000.00..77513.43 rows=1 width=12)
     Workers Planned: 2
     ->  Parallel Seq Scan on orders  (cost=0.00..76513.33 rows=1 width=12)
           Filter: ((order_date >= '2022-01-01'::date) AND (order_date <= '2022-02-01'::date) AND (status = 'placed'::text))
  (4 rows)
  ```



  >  Используется Seq scan последовательный перебор всех строк базы в поисках конкретного значения.

   - создаю индекс на несколько полей
   ```
  db_ind=# create index idx_ord_order_date_status on orders(order_date, status);
  CREATE INDEX
  ```
  - выполняю запрос
  ```
  explain
  select order_date, status
  from orders
  where order_date between date'2022-01-01' and date'2022-02-01'
          and status = 'placed';

                                                       QUERY PLAN                                  
  -------------------------------------------------------------------------------------------------------------------------
   Index Only Scan using idx_ord_order_date_status on orders  (cost=0.43..4.46 rows=1 width=12)
     Index Cond: ((order_date >= '2022-01-01'::date) AND (order_date <= '2022-02-01'::date) AND (status = 'placed'::text))
  (2 rows)
  ```

 > использовано индексное сканирование Index Only Scan.

* __Описание комментарии к каждому из индексов__
  
  - Индекс для полнотекстового поиска используются для поиска слов в тексте.
  - При частых запросов используется индекс для ускорения работы запросов, 
  - Частичный индекс - это индексы которые охватывают не все записи а только те которые соответствуют определенному условию. Поскольку запрос, ищущий общее значение (которое составляет более нескольких процентов всех строк таблицы), в любом случае не будет использовать индекс, нет смысла вообще сохранять эти строки в индексе. Это уменьшает размер индекса, что ускоряет запросы, использующие индекс. Это также ускорит многие операции обновления таблицы, поскольку индекс не нужно обновлять во всех случаях. 

> В данном решений было рассмотрен и изучен учебный практический материал занятия соответственно что и было применено. 

## 2 вариант:
* В результате выполнения ДЗ вы научитесь пользоваться различными вариантами соединения таблиц.
* навыки:
  - написания запросов с различными типами соединений

* __Решение__

  - создаю еще одну таблицу clients и наполняю ее значениями от 1 до 50
  ```
  db_ind=# create table clients (user_id int, passwd text);
  CREATE TABLE
  db_ind=# insert into clients(user_id, passwd) 
  select generate_series, md5(random()::text) from generate_series(1, 50);
  INSERT 0 50
  db_ind=# 
  ```
  - количество строк
  ```
  db_ind=# select count(*) from clients;
   count 
  -------
      50
  (1 row)

  ``` 
  - создаю индексы по полям user_id для каждой из таблиц
  
  ```
  create unique index idx_cust_uid on clients(user_id);
  create index idx_ord_uid on orders(user_id);
  ```
  - прямое соединение двух или более таблиц, выполняю запрос при объединении двух таблиц по условию clients.user_id=orders.user_id
  ```
  db_ind=# explain analyze
  select a.user_id, b.order_date from clients a inner join orders b on a.user_id=b.user_id;
                                                          QUERY PLAN                                                        
  --------------------------------------------------------------------------------------------------------------------------
   Hash Join  (cost=2.12..103965.58 rows=3521127 width=8) (actual time=17.832..1414.945 rows=3571506 loops=1)
     Hash Cond: (b.user_id = a.user_id)
   ->  Seq Scan on orders b  (cost=0.00..90055.00 rows=5000000 width=8) (actual time=0.051..508.001 rows=5000000 loops=1)
   ->  Hash  (cost=1.50..1.50 rows=50 width=4) (actual time=17.725..17.727 rows=50 loops=1)
           Buckets: 1024  Batches: 1  Memory Usage: 10kB
           ->  Seq Scan on clients a  (cost=0.00..1.50 rows=50 width=4) (actual   time=17.688..17.699 rows=50 loops=1)
   Planning Time: 1.319 ms
   JIT:
     Functions: 11
     Options: Inlining false, Optimization false, Expressions true, Deforming true
     Timing: Generation 3.181 ms, Inlining 0.000 ms, Optimization 2.114 ms,   Emission 14.896 ms, Total 20.191 ms
   Execution Time: 1544.352 ms
  (12 rows)
  ```
  > По данному запросу используется алгоритм соединения Hash Join.

  - Левостороннее соединение двух таблиц, выполняю запрос при объединении двух таблиц по условию clients.user_id=orders.user_id.
  ```
  db_ind=# explain analyze
  db_ind-# select a.user_id, b.user_id from clients a left join orders b ON a.user_id=b.user_id;
                                                          QUERY PLAN                                                        
  --------------------------------------------------------------------------------------------------------------------------
   Hash Right Join  (cost=2.12..103965.58 rows=3521127 width=8) (actual time=6.725..1221.270 rows=3571506 loops=1)
   Hash Cond: (b.user_id = a.user_id)
     ->  Seq Scan on orders b  (cost=0.00..90055.00 rows=5000000 width=4) (actual time=0.505..426.892 rows=5000000 loops=1)
     ->  Hash  (cost=1.50..1.50 rows=50 width=4) (actual time=6.181..6.183 rows=50 loops=1)
           Buckets: 1024  Batches: 1  Memory Usage: 10kB
           ->  Seq Scan on clients a  (cost=0.00..1.50 rows=50 width=4) (actual time=6.153..6.163 rows=50 loops=1)
   Planning Time: 0.273 ms
   JIT:
     Functions: 11
     Options: Inlining false, Optimization false, Expressions true, Deforming true
     Timing: Generation 1.137 ms, Inlining 0.000 ms, Optimization 0.435 ms,   Emission 5.475 ms, Total 7.047 ms
   Execution Time: 1357.087 ms
  (12 rows)
  ```

   > В запросе используется алгоритм Merge Join данный способ соединение физически.

   - Реализация кросс соединения.