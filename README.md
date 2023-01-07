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

  - ___Создаю базу данных с таблицей orders и заполняю её данными:___
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
  - ___результат команды explain___

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

  - ___проверяю размер таблицы___
  ```
  db_ind=# select pg_size_pretty(pg_table_size('orders'));
  pg_size_pretty 
  ----------------
  313 MB
  (1 row)

  ```
  
* __Реализовация индекса для полнотекстового поиска__
    * ___создаю индекс по колонке id___
  ```
  db_ind=# create index idx_ord_id on orders(id);
  CREATE INDEX
  ```
  - ___проверяю план запроса - использования индекса___
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

  - ___размер индекса___
  
  ```
  db_ind=# select pg_size_pretty(pg_table_size('idx_ord_id'));
   pg_size_pretty 
  ----------------
   107 MB
  (1 row)
  ```
* __Создание индекса на несколько полей__
  - ___выполняю запрос___ 
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

   - ___создаю индекс на несколько полей___
   ```
  db_ind=# create index idx_ord_order_date_status on orders(order_date, status);
  CREATE INDEX
  ```
  - ___выполняю запрос___
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

  - ___создаю еще одну таблицу clients и наполняю ее значениями от 1 до 50___
  ```
  db_ind=# create table clients (user_id int, passwd text);
  CREATE TABLE
  db_ind=# insert into clients(user_id, passwd) 
  select generate_series, md5(random()::text) from generate_series(1, 50);
  INSERT 0 50
  db_ind=# 
  ```
  - ___количество строк___
  ```
  db_ind=# select count(*) from clients;
   count 
  -------
      50
  (1 row)

  ``` 
  - ___создаю индексы по полям user_id для каждой из таблиц___
  
  ```
  create unique index idx_cust_uid on clients(user_id);
  create index idx_ord_uid on orders(user_id);
  ```
  - ___прямое соединение двух или более таблиц, выполняю запрос при объединении двух таблиц по условию clients.user_id=orders.user_id___
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

  - ___Левостороннее соединение двух таблиц, выполняю запрос при объединении двух таблиц по условию clients.user_id=orders.user_id.___
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

   - ___Реализация кросс соединения. Соединяю таблицу orders и clients.___
  
  ```
  db_ind=# explain
  db_ind-#   select a.user_id, b.user_id from clients a cross join orders b;
                                    QUERY PLAN                                   
  -------------------------------------------------------------------------------
  Nested Loop  (cost=0.00..3215056.62 rows=250000000 width=8)
     ->  Seq Scan on orders b  (cost=0.00..90055.00 rows=5000000 width=4)
     ->  Materialize  (cost=0.00..1.75 rows=50 width=4)
           ->  Seq Scan on clients a  (cost=0.00..1.50 rows=50 width=4)
   JIT:
     Functions: 5
     Options: Inlining true, Optimization true, Expressions true, Deforming true
  (7 rows)
  ```
  - ___выполняю explain analyze___
  ```
  explain analyze
  select a.user_id, b.user_id from clients a cross join orders b;
  QUERY PLAN                                                        
  --------------------------------------------------------------------------------------------------------------------------
   Nested Loop  (cost=0.00..3215056.62 rows=250000000 width=8) (actual time=40.194..34097.045 rows=250000000 loops=1)
     ->  Seq Scan on orders b  (cost=0.00..90055.00 rows=5000000 width=4) (actual time=0.299..532.526 rows=5000000 loops=1)
     ->  Materialize  (cost=0.00..1.75 rows=50 width=4) (actual time=0.000..0.002 rows=50 loops=5000000)
           ->  Seq Scan on clients a  (cost=0.00..1.50 rows=50 width=4) (actual time=39.878..39.887 rows=50 loops=1)
   Planning Time: 0.113 ms
   JIT:
     Functions: 5
     Options: Inlining true, Optimization true, Expressions true, Deforming true
     Timing: Generation 0.645 ms, Inlining 1.999 ms, Optimization 25.809 ms, Emission 11.882 ms, Total 40.334 ms
   Execution Time: 42768.209 ms
  (10 rows)
  ```
  > Используется алгоритм Nested Loop.
    Cross Join или перекрестное соединение создает набор строк, где каждая строка из одной таблицы соединяется с каждой строкой из второй таблицы. 

  - __Реализация полного соединения.__ 
  ```
  explain analyze
  select a.user_id, b.user_id from clients a full join orders b ON a.user_id=b.user_id WHERE a.user_id is null or b.user_id is null;
  
    QUERY PLAN                                                        
  --------------------------------------------------------------------------------------------------------------------------
   Hash Full Join  (cost=2.12..103965.58 rows=25000 width=8) (actual time=19.198..1294.934 rows=1428494 loops=1)
     Hash Cond: (b.user_id = a.user_id)
     Filter: ((a.user_id IS NULL) OR (b.user_id IS NULL))
     Rows Removed by Filter: 3571506
     ->  Seq Scan on orders b  (cost=0.00..90055.00 rows=5000000 width=4) (actual time=0.171..468.490 rows=5000000 loops=1)
     ->  Hash  (cost=1.50..1.50 rows=50 width=4) (actual time=19.002..19.004 rows=50 loops=1)
           Buckets: 1024  Batches: 1  Memory Usage: 10kB
           ->  Seq Scan on clients a  (cost=0.00..1.50  rows=50 width=4) (actual time=18.955..18.966 rows=50 loops=1)
   Planning Time: 1.348 ms
   JIT:
     Functions: 14
     Options: Inlining false, Optimization false, Expressions true, Deforming true
     Timing: Generation 3.457 ms, Inlining 0.000 ms, Optimization 2.780 ms, Emission 15.789 ms, Total 22.026 ms
   Execution Time: 1352.480 ms
  ```
  > При выполнения запроса используется алгоритм Merge Full Join

  - ___Реализация запросов, в котором будут использованы
разные типы соединений___
  
  ```
  explain analyze
  select a.user_id from clients a inner join clients b on a.user_id=b.user_id
  left join orders c ON a.user_id=c.user_id;
                                                                      QUERY    PLAN                                                                  
  ---------------------------------------------------------------------------------------------------------------------------------------------
   Nested Loop Left Join  (cost=2.56..105721.02 rows=3521127 width=4) (actual time=15.309..729.013 rows=3571506 loops=1)
     ->  Hash Join  (cost=2.12..3.77 rows=50 width=4) (actual time=14.680..14.955 rows=50 loops=1)
           Hash Cond: (a.user_id = b.user_id)
           ->  Seq Scan on clients a  (cost=0.00..1.50 rows=50 width=4) (actual time=0.161..0.243 rows=50 loops=1)
           ->  Hash  (cost=1.50..1.50 rows=50 width=4) (actual time=14.497..14.499 rows=50 loops=1)
                 Buckets: 1024  Batches: 1  Memory Usage: 10kB
                 ->  Seq Scan on clients b  (cost=0.00..1.50 rows=50 width=4) (actual time=14.468..14.477 rows=50 loops=1)
     ->  Index Only Scan using idx_ord_uid on orders c  (cost=0.43..1410.11 rows=70423 width=4) (actual time=0.039..8.485 rows=71430 loops=50)
           Index Cond: (user_id = a.user_id)
           Heap Fetches: 0
   Planning Time: 0.513 ms
   JIT:
     Functions: 13
     Options: Inlining false, Optimization false, Expressions true, Deforming true
     Timing: Generation 3.488 ms, Inlining 0.000 ms,   Optimization 1.826 ms, Emission 12.090 ms, Total 17.404 ms
   Execution Time: 856.855 ms
  (16 rows)
  ```
  > Здесь была объедина таблица clients и левосторонним соеднинением с таблицей orders.

  - ___Запросы в общих чертах___
  > LEFT JOIN выводит все значения из левой таблицы и пересечения значений (по ключу) с правой.

  > Запрос с right join наоборот, вернёт все записи из правой таблицы и только те записи из левой, которые имеют общий ключ:

  > Запрос inner join - это внутреннее объединение (пересечение) значений, которые есть в обоих объединяемых таблицах. 

   > Запрос cross join выведет каждую запись левой таблицы соединённой с каждой записью правой (не зависимо от значения ключа).

   > Запрос full join вернёт строки с общими ключами в обоих таблицах, а также все строки обоих таблиц, где нет соответствия. 
   
   * __Структура таблиц.__
   
   ![изображение](https://user-images.githubusercontent.com/85208391/211150572-c74dcaa2-4317-4951-b198-0ee5d656de75.png)

   
   
