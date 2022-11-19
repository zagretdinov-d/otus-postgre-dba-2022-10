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




то есть все Transactions per second (TPS) я буду наблюдать в этой таблице


![image](https://user-images.githubusercontent.com/85208391/202756997-a6481fde-9d4e-4429-8d3b-ce0478cb0620.png)

![image](https://user-images.githubusercontent.com/85208391/202756813-3e573a49-c38a-4f1b-bfde-5cec2f4fda75.png)

![image](https://user-images.githubusercontent.com/85208391/202759350-c07dec25-5b7c-46cf-88ee-76a3e5499f06.png)

![image](https://user-images.githubusercontent.com/85208391/202759795-b582f346-e89f-472d-90d3-7f151a0e5f7b.png)

![image](https://user-images.githubusercontent.com/85208391/202760279-85f50eb8-3aa6-4bcb-953d-886694835c72.png)

![image](https://user-images.githubusercontent.com/85208391/202760794-cedd3668-5e69-41c6-86fa-5d4903cd91d4.png)

![image](https://user-images.githubusercontent.com/85208391/202761058-8f25dd96-7148-4e3d-aeb6-cda469bc973b.png)

![image](https://user-images.githubusercontent.com/85208391/202761353-36c71d68-5a87-4f0d-9141-714e94ae7938.png)

![image](https://user-images.githubusercontent.com/85208391/202761986-f56beaad-1300-4c82-805a-d14525328694.png)


```
sudo -u postgres pgbench -c8 -P 5 -T 1200 -U postgres postgres

transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
duration: 1200 s
number of transactions actually processed: 679791
latency average = 14.120 ms
latency stddev = 22.093 ms
initial connection time = 26.876 ms
tps = 566.496404 (without initial connection time)
```

изменю параметры vacuum
```
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
duration: 1200 s
number of transactions actually processed: 676985
latency average = 14.179 ms
latency stddev = 21.792 ms
initial connection time = 27.734 ms
tps = 564.123115 (without initial connection time)
```







