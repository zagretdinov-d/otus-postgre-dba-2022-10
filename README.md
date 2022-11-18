# Lesson 8
### Тема: Настройка autovacuum с учетом оптимальной производительности

* __Цель:__

  * запустить нагрузочный тест pgbench
  * настроить параметры autovacuum для достижения максимального уровня устойчивой производительности

### Решение:
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


Проверяю
damir@postgres-node-2:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
damir@postgres-node-2:~$ 

Теперь предворительно для себя я настрою мониторинг на zabbix, где буду просматривать графики размера базы данных, занятое пространства на диске, используемое количество оперативной памяти.

У меня имеется в облаке уже рабочий мой zabbix. В крации в качестве дополнения распишу как настроил zabbix-agent созданныю машину.
ставлю zabbix-agent
wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+focal_all.deb
sudo dpkg -i zabbix-release_5.0-1+focal_all.deb
sudo apt install zabbix-agent
Проверяю порт 10050
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

этот же порт я добавляю в облаке GCE 

![image](https://user-images.githubusercontent.com/85208391/202591961-ae4862ab-4a5f-4013-86ef-f3d47903338d.png)


Создаю пользователя в postgres которого буду прописывать на zabbix сервере
postgres=# CREATE USER zbx_monitor WITH PASSWORD '51324ZXcv' INHERIT;
CREATE ROLE
postgres=# GRANT pg_monitor TO zbx_monitor;
GRANT ROLE

Отредактируйте pg_hba.conf, чтобы разрешить соединения с агентом Zabbix
host    all             zbx_monitor     127.0.0.1/32            trust
host    all             zbx_monitor     0.0.0.0/0               md5

Также в postgresql.conf исправлю.
listen_addresses = '*'

Даллее загружаю необходимые шаблоны  pgsql.sql и настраиваю конфиг zabbix-agent. перезагружаю postgres и zabbix-agent

Буду работать с базой devops её же и создам
postgres@postgres-node-2:/home/damir$ psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# create database devops;
CREATE DATABASE


Далее прописываю все данные удаленной машины на zabbix сервер.

В результате получаю необходимый мне график

![image](https://user-images.githubusercontent.com/85208391/202597793-2f81a477-f7c8-423e-af67-66cbb7d28fef.png)

то есть все Transactions per second (TPS) я буду наблюдать в этой таблице


![image](https://user-images.githubusercontent.com/85208391/202756997-a6481fde-9d4e-4429-8d3b-ce0478cb0620.png)

![image](https://user-images.githubusercontent.com/85208391/202756813-3e573a49-c38a-4f1b-bfde-5cec2f4fda75.png)

![image](https://user-images.githubusercontent.com/85208391/202759350-c07dec25-5b7c-46cf-88ee-76a3e5499f06.png)

![image](https://user-images.githubusercontent.com/85208391/202759795-b582f346-e89f-472d-90d3-7f151a0e5f7b.png)



















