# Lesson 17
### Тема: Триггеры, поддержка заполнения витрин

#### Цель:
* __Создать триггер для поддержки витрины в актуальном состоянии.__

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
* __Cоздаю таблицы в соответствии с файлом скаченным по ссылке и заполнил данными__
 