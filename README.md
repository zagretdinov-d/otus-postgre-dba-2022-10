# Lesson 17
### Тема: Триггеры, поддержка заполнения витрин

#### Цель:
* __Создать триггер для поддержки витрины в актуальном состоянии.__

### Решение:

* Для выполнения поставленных целей разворачиваю GCE инстанс типа e2-medium
```
damir@Damir:~$ gcloud beta compute instances create postgres-1 \
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
Created [https://www.googleapis.com/compute/beta/projects/pg-devops1988-10-375513/zones/us-central1-a/instances/postgres-1].
NAME        ZONE           MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
postgres-1  us-central1-a  e2-medium                  10.128.0.2   35.202.233.86  RUNNING

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


![image](https://user-images.githubusercontent.com/85208391/213932245-2b6435ea-bcb2-4714-963d-c891424f6f86.png)

![image](https://user-images.githubusercontent.com/85208391/214259157-579f6fe3-415f-4898-9c8d-c93317a67ed5.png)

-- Создать триггер (на таблице sales) для поддержки.




-- Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE
Перед  созданием триггеров заполнил её уже имеющимися записями

INSERT INTO good_sum_mart SELECT G.good_name, sum(G.good_price * S.sales_qty) AS sum_sale
  FROM goods G
  INNER JOIN sales S ON S.good_id = G.goods_id
  GROUP BY G.good_name;




-- Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?
-- Подсказка: В реальной жизни возможны изменения цен.
 
