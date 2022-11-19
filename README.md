# Lesson 8
### Тема: Настройка autovacuum с учетом оптимальной производительности

* __Цель:__

  * запустить нагрузочный тест pgbench
  * настроить параметры autovacuum для достижения максимального уровня устойчивой производительности

### Решение:
Создаю GCE инстанс типа e2-medium и standard disk 10GB
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

![image](https://user-images.githubusercontent.com/85208391/202587302-dfa1936d-e0d9-4113-b0e8-ec29fb2242b6.png)


подключаюсь к VM и устанавливаю Postgres 14
```
damir@postgres-node-2:~$ sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-14
```

___Проверяю___
```
damir@postgres-node-2:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
```

___Для построения графика и получений значений предворительно настрою мониторинг на zabbix.___

У меня имеется в облаке уже рабочий zabbix. В крации в качестве дополнения настраиваю zabbix-agent на созданной GCE инстанс.

___Установка___

```
wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+focal_all.deb
sudo dpkg -i zabbix-release_5.0-1+focal_all.deb
sudo apt install zabbix-agent
```
___Проверяю порт 10050___
```
damir@postgres-node-2:~$ sudo netstat -pnltu
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:10050           0.0.0.0:*               LISTEN      32586/zabbix_agentd 
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      879/sshd: /usr/sbin 
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      463/systemd-resolve 
tcp        0      0 127.0.0.1:5432          0.0.0.0:*               LISTEN      29698/postgres      
tcp6       0      0 :::10050                :::*                    LISTEN      32586/zabbix_agentd 
tcp6       0      0 :::22                   :::*                    LISTEN      879/sshd: /usr/sbin 
udp        0      0 127.0.0.53:53           0.0.0.0:*                           463/systemd-resolve 
udp        0      0 10.186.0.3:68           0.0.0.0:*                           459/systemd-network 
udp        0      0 127.0.0.1:323           0.0.0.0:*                           1372/chronyd        
udp6       0      0 ::1:323                 :::*                                1372/chronyd
```
___Добавляю в облаке GCE___ 

![image](https://user-images.githubusercontent.com/85208391/202591961-ae4862ab-4a5f-4013-86ef-f3d47903338d.png)


___Создаю пользователя в postgres которого буду прописывать на zabbix сервере___
```
postgres=# CREATE USER zbx_monitor WITH PASSWORD 'password' INHERIT;
CREATE ROLE
postgres=# GRANT pg_monitor TO zbx_monitor;
GRANT ROLE
```

___Отредактируйте pg_hba.conf, чтобы разрешить соединения с агентом Zabbix.___

```
host    all             zbx_monitor     127.0.0.1/32            trust
host    all             zbx_monitor     0.0.0.0/0               md5
```

___Также в postgresql.conf исправлю.___
```
listen_addresses = '*'
```

__Загружаю необходимые шаблоны  pgsql.sql, настраиваю конфиг zabbix-agent и перезагружаю.__

___Создаю базу которую буду мониторить___
```
postgres=# create database devops;
CREATE DATABASE
```
___Далее прописываю все данные удаленной машины на zabbix сервер.___

В результате получаю график значений tps для базы devops

![image](https://user-images.githubusercontent.com/85208391/202834208-5c73d3ea-3088-4091-941c-06e036b1e18f.png)
![image](https://user-images.githubusercontent.com/85208391/202834236-7dd5067c-4a20-44ff-b6b2-732dafb82c36.png)



___Закончил настраивать zabbix. Перехожу к параметрам postgresql.__
  * изменяю параметры настройки PostgreSQL полученные из материалов занятий
  
  /etc/postgresql/14/main/postgresql.conf

  ```
  max_connections = 40
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 512MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 500
random_page_cost = 4
effective_io_concurrency = 2
work_mem = 6553kB
min_wal_size = 4GB
max_wal_size = 16GB
```

* перезагружаем кластер
```
sudo pg_ctlcluster 14 main restart
```
___Процесс выполнения pgbench -i devops.___
```
damir@postgres-node-2:~$ sudo -u postgres pgbench -i devops
dropping old tables...
NOTICE:  table "pgbench_accounts" does not exist, skipping
NOTICE:  table "pgbench_branches" does not exist, skipping
NOTICE:  table "pgbench_history" does not exist, skipping
NOTICE:  table "pgbench_tellers" does not exist, skipping
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.10 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.45 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.27 s, vacuum 0.09 s, primary keys 0.08 s).
damir@postgres-node-2:~$ 
```
### Первый запуск

* Добавляю следующие параметры 
```
vacuum_cost_delay = 0
vacuum_cost_page_hit = 0
vacuum_cost_page_miss = 5
vacuum_cost_page_dirty = 5
vacuum_cost_limit = 200

autovacuum_naptime = 1min
autovacuum_vacuum_scale_factor = 0.2
autovacuum_vacuum_threshold = 50
autovacuum_analyze_scale_factor = 0.1
autovacuum_analyze_threshold = 50
autovacuum_max_workers = 3
```
* запускаю pgbench -c8 -P 5 -T 1200 -U postgres devops вакуума

```
sudo -u postgres pgbench -c8 -P 5 -T 1200 -U postgres postgres
```

* Результат
```
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
duration: 1200 s
number of transactions actually processed: 708151
latency average = 13.554 ms
latency stddev = 20.816 ms
initial connection time = 28.082 ms
tps = 590.127940 (without initial connection time)
```
![image](https://user-images.githubusercontent.com/85208391/202839629-6fe08303-a7c1-47b3-a1d4-d8284be6e68e.png)
![image](https://user-images.githubusercontent.com/85208391/202839602-84a9f1f5-7737-4e09-b7f6-eda9e7c4d524.png)

- Транзакции упали с 800 до 500 через 5 минут
- База выросла до 60МБ

### Второй запуск
Изменяю параметры конфигурации
```
autovacuum_naptime = 30min
autovacuum_vacuum_scale_factor = 0.1
autovacuum_vacuum_threshold = 50
autovacuum_analyze_scale_factor = 0.1
autovacuum_analyze_threshold = 50
autovacuum_max_workers = 4
```
```
sudo -u postgres pgbench -c8 -P 5 -T 1200 -U postgres postgres
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
duration: 1200 s
number of transactions actually processed: 674850
latency average = 14.224 ms
latency stddev = 21.895 ms
initial connection time = 26.833 ms
tps = 562.378702 (without initial connection time)
```
![image](https://user-images.githubusercontent.com/85208391/202841560-3cd966a8-c9dc-445a-8f5d-fe3ca10eab68.png)
![image](https://user-images.githubusercontent.com/85208391/202841627-9227b062-f828-4f8c-825a-5e349a268e8a.png)

### Третий запуск - более агресивный
Изменяю параметры конфигурации
```
autovacuum_naptime = 20
autovacuum_vacuum_scale_factor = 0.05
autovacuum_vacuum_threshold = 20
autovacuum_analyze_scale_factor = 0.05
autovacuum_analyze_threshold = 20
autovacuum_max_workers = 10
autovacuum_vacuum_insert_threshold = 500
autovacuum_vacuum_insert_scale_factor = 0.05
```

```
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
duration: 1200 s
number of transactions actually processed: 658327
latency average = 14.581 ms
latency stddev = 22.417 ms
initial connection time = 27.032 ms
tps = 548.570043 (without initial connection time)
```
![image](https://user-images.githubusercontent.com/85208391/202844010-1e0a2e75-0ba7-4110-9095-2f664d193ca3.png)
![image](https://user-images.githubusercontent.com/85208391/202844023-c4231e6f-c84c-43f1-b574-8ea7014d6708.png)


