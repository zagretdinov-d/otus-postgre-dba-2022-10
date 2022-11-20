# Lesson 9
### Тема: Работа с журналами

* __Цель:__

  * уметь работать с журналами и контрольными точками
  * уметь настраивать параметры журналов

### Решение:
* __создаю GCE инстанс типа e2-medium__
```
damir@Damir:~$ gcloud beta compute instances create postgres-node-2 \
> --machine-type=e2-medium \
> --image-family ubuntu-2004-lts \
> --image-project=ubuntu-os-cloud \
> --boot-disk-size=10GB \
> --boot-disk-type=pd-ssd \
> --tags=postgres \
> --restart-on-failure
```

* __подключаемся к VM и устанавливаем Postgres 14 с дефолтными настройками__
```
damir@postgres-node-2:~$ sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-14
```
* __запускаю psql__
```
sudo -u postgres psql
```

* __Настройка выполнения контрольной точки.__
    * _____Настрайваю выполнения контрольной точки раз в 30 секунд._____
    ```
    postgres=# ALTER SYSTEM SET checkpoint_timeout = 30;
    ALTER SYSTEM
    ```

    * _____Включаю получения в журнале сообщений сервера информации о выполняемых контрольных точках и перезагружаю конфигурации_____
    ```
    postgres=# ALTER SYSTEM SET log_checkpoints = on;
    ALTER SYSTEM
    postgres=# SELECT pg_reload_conf();
    pg_reload_conf 
    ----------------
    t
    (1 row)

    postgres=#
   ```

   * _____Подготовка pgbench_____
  ```
  damir@postgres-node-2:~$ sudo -u postgres pgbench -i postgres
  dropping old tables...
  creating tables...
  generating data (client-side)...
  100000 of 100000 tuples (100%) done (elapsed 0.10 s, remaining 0.00 s)
  vacuuming...
  creating primary keys...
  done in 0.43 s (drop tables 0.01 s, create tables 0.01 s, client-side generate 0.24 s, vacuum 0.09 s, primary keys 0.08 s).

  ```
  ```
  damir@postgres-node-2:~$ sudo -u postgres pgbench -P 30 -T 600
  pgbench (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
  starting vacuum...end.
  transaction type: <builtin: TPC-B (sort of)>
  scaling factor: 1
  query mode: simple
  number of clients: 1
  number of threads: 1
  duration: 600 s
  number of transactions actually processed: 343861
  latency average = 1.744 ms
  latency stddev = 0.343 ms
  initial connection time = 4.285 ms
  tps = 573.105206 (without initial connection time)
  ```
  ```
  damir@postgres-node-2:~$ tail -f  /var/log/postgresql/postgresql-14-main.log
  2022-11-20 08:59:00.028 UTC [178435] LOG:  checkpoint starting: time
  2022-11-20 08:59:27.039 UTC [178435] LOG:  checkpoint complete: wrote 2162 buffers (1.6%); 0 WAL file(s) added, 0 removed, 2 recycled; write=26.980 s, sync=0.008 s, total=27.012 s; sync files=19, longest=0.004 s, average=0.001 s; distance=20563 kB, estimate=21054 kB
  2022-11-20 08:59:30.043 UTC [178435] LOG:  checkpoint starting: time
  2022-11-20 08:59:57.046 UTC [178435] LOG:  checkpoint complete: wrote 1830 buffers (1.4%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.978 s, sync=0.006 s, total=27.004 s; sync files=6, longest=0.004 s, average=0.001 s; distance=20114 kB, estimate=20960 kB
  2022-11-20 09:00:00.048 UTC [178435] LOG:  checkpoint starting: time
  2022-11-20 09:00:27.052 UTC [178435] LOG:  checkpoint complete: wrote 1917 buffers (1.5%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.979 s, sync=0.006 s, total=27.005 s; sync files=18, longest=0.004 s, average=0.001 s; distance=20510 kB, estimate=20915 kB
  2022-11-20 09:00:30.055 UTC [178435] LOG:  checkpoint starting: time
  2022-11-20 09:00:57.059 UTC [178435] LOG:  checkpoint complete: wrote 1808 buffers (1.4%); 0 WAL file(s) added, 0 removed, 1 recycled; write=26.977 s, sync=0.007 s, total=27.005 s; sync files=6, longest=0.004 s, average=0.002 s; distance=19767 kB, estimate=20800 kB


- 10 минут c помощью утилиты pgbench подавайте нагрузку.

- Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку.

- Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?

- Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.

- Создайте новый кластер с включенной контрольной суммой страниц. Создайте таблицу. Вставьте несколько значений. Выключите кластер. Измените пару байт в таблице. Включите кластер и сделайте выборку из таблицы. Что и почему произошло? как проигнорировать ошибку и продолжить работу?
