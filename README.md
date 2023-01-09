# Lesson 16
### Тема: Секционирование таблицы

### Цель:
* __научиться секционировать таблицы.__

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
* __Секционирование большой таблицы из демо базы flights.__
  - Скачиваю архив тестовой базы данных с помощью wget c сайта https://postgrespro.com/education/demodb
  
  ```
    damir@pg-host:~$ wget https://edu.postgrespro.com/demo-big-en.zip
  --2023-01-08 03:02:34--  https://edu.postgrespro.com/demo-big-en.zip
  Resolving edu.postgrespro.com (edu.postgrespro.com)... 213.171.56.196
  Connecting to edu.postgrespro.com (edu.postgrespro.com)|213.171.56.196|:443... connected.
  HTTP request sent, awaiting response... 200 OK
  Length: 243203220 (232M) [application/zip]
  Saving to: ‘demo-big-en.zip’

  demo-big-en.zip                                             100%[=========================================================================================================================================>] 231.94M  57.1MB/s    in 4.4s    

  2023-01-08 03:02:39 (52.7 MB/s) - ‘demo-big-en.zip’ saved [243203220/243203220]
  ```
  - ___Распаковываю архив с помощью unzip.___

  ```
  damir@pg-host:~$ ls -l
  total 1146756
  -rwxrwxrwx 1 damir damir 931068524 Feb 21  2018 demo-big-en-20170815.sql
  -rw-rw-r-- 1 damir damir 243203220 Feb 21  2018 demo-big-en.zip
  damir@pg-host:~$ 
  ```
  - ___Загружаю и проверяю базу.___
  ```
  postgres=# \i demo-big-en-20170815.sql;
  demo=# SELECT * FROM flights limit 10;
  flight_id | flight_no |  scheduled_departure   |   scheduled_arrival    | departure_airport | arrival_airport |  status   | aircraft_code | actual_departure | actual_arrival 
  -----------+-----------+------------------------+------------------------+-------------------+-----------------+-----------+---------------+------------------+----------------
        2880 | PG0216    | 2017-09-14 11:10:00+00 | 2017-09-14 12:15:00+00 | DME               | KUF             | Scheduled | 763           |                  | 
        3940 | PG0212    | 2017-09-04 15:20:00+00 | 2017-09-04 16:35:00+00 | DME               | ROV             | Scheduled | 321           |                  | 
        4018 | PG0416    | 2017-09-13 16:20:00+00 | 2017-09-13 16:55:00+00 | DME               | VOZ             | Scheduled | CR2           |                  | 
        4587 | PG0055    | 2017-09-03 11:10:00+00 | 2017-09-03 12:25:00+00 | DME               | TBW             | Scheduled | CN1           |                  | 
        5694 | PG0341    | 2017-08-31 07:50:00+00 | 2017-08-31 08:55:00+00 | DME               | PES             | Scheduled | CR2           |                  | 
        6428 | PG0335    | 2017-08-24 06:30:00+00 | 2017-08-24 08:35:00+00 | DME               | JOK             | Scheduled | CN1           |                  | 
        6664 | PG0335    | 2017-09-07 06:30:00+00 | 2017-09-07 08:35:00+00 | DME               | JOK             | Scheduled | CN1           |                  | 
        7455 | PG0136    | 2017-09-10 12:30:00+00 | 2017-09-10 14:30:00+00 | DME               | NAL             | Scheduled | CR2           |                  | 
        9994 | PG0210    | 2017-09-01 15:00:00+00 | 2017-09-01 16:50:00+00 | DME               | MRV             | Scheduled | 733           |                  | 
       11283 | PG0239    | 2017-08-22 06:05:00+00 | 2017-08-22 08:40:00+00 | DME               | HMA             | Scheduled | SU9           |                  | 
  (10 rows)
  ```

    - ___Для сенкционирования на 2016, 2017 года и по умолчанию создаю таблицу flights_demo.___
    ```
    demo=# CREATE TABLE flights_demo (
    demo(#     flight_id integer NOT NULL,
    demo(#     flight_no character(6) NOT NULL,
    demo(#     scheduled_departure timestamp with time zone NOT NULL,
    demo(#     scheduled_arrival timestamp with time zone NOT NULL,
    demo(#     departure_airport character(3) NOT NULL,
    demo(#     arrival_airport character(3) NOT NULL,
    demo(#     status character varying(20) NOT NULL,
    demo(#     aircraft_code character(3) NOT NULL,
    demo(#     actual_departure timestamp with time zone,
    demo(#     actual_arrival timestamp with time zone,
    demo(#     CONSTRAINT flights_check CHECK ((scheduled_arrival > scheduled_departure)),
    demo(#     CONSTRAINT flights_check1 CHECK (((actual_arrival IS NULL) OR ((actual_departure IS NOT NULL) AND (actual_arrival IS NOT NULL) AND (actual_arrival > actual_departure)))),
    demo(#     CONSTRAINT flights_status_check CHECK (((status)::text = ANY (ARRAY[('On Time'::character varying)::text, ('Delayed'::character varying)::text, ('Departed'::character varying)::text, ('Arrived'::character varying)::text, ('Scheduled'::character varying)::text, ('Cancelled'::character varying)::text])))
    demo(# ) partition by range (scheduled_departure);
    CREATE TABLE
    ```
    - ___Теперь создаю секционирование на 2016, 2017 года и по умолчанию:__
    ``` 
    demo=# CREATE TABLE flights_2016 partition of flights_demo for values from ('2016-01-01') to ('2017-01-01');
    CREATE TABLE
    demo=# CREATE TABLE flights_2017 partition of flights_demo for values from ('2017-01-01') to ('2018-01-01');
    CREATE TABLE
    demo=# CREATE TABLE flights_default partition of flights_demo default;
    CREATE TABLE
    ```
    - ___В результате___
  ![image](https://user-images.githubusercontent.com/85208391/211228517-ce854602-cf83-443b-b3e0-3c3709473bae.png)
