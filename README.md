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
* __Запуск логирования__

