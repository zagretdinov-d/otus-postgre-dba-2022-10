# Lesson 17
### Тема: Триггеры, поддержка заполнения витрин.

#### Цель:
* __Создать триггер для поддержки витрины в актуальном состоянии.__

### Решение:

* Для выполнения поставленных целей разворачиваю GCE инстанс типа e2-medium.
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
Подключаюсь к VM и устанавливаем Postgres 14 с дефолтными настройками.

```
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-14
```
Проверяю статус postgres.
```
damir@pg-host:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
```
* __Cоздаю таблицы в соответствии с файлом скаченным по ссылке и заполнил данными__

> Для работы с триггерами и функциями исользую DBeaver.

![image](https://user-images.githubusercontent.com/85208391/213932245-2b6435ea-bcb2-4714-963d-c891424f6f86.png)

![image](https://user-images.githubusercontent.com/85208391/214259157-579f6fe3-415f-4898-9c8d-c93317a67ed5.png)

* __Создать триггер (на таблице sales) для поддержки.__

> __Подсказка:__ не забыть, что кроме INSERT есть еще UPDATE и DELETE

* __Решение:__ Перед тем как создам соответствующие триггеры заполняю имеющимися записями и добавляю триггерные функции
```
INSERT INTO good_sum_mart SELECT G.good_name, sum(G.good_price * S.sales_qty) AS sum_sale
  FROM goods G
  INNER JOIN sales S ON S.good_id = G.goods_id
  GROUP BY G.good_name;
```
```
CREATE or replace function ft_insert_sales()
RETURNS trigger
AS
$TRIG_FUNC$
DECLARE
g_name varchar(63);
g_price numeric(12,2);
BEGIN
SELECT G.good_name, G.good_price*NEW.sales_qty INTO g_name, g_price FROM goods G where G.goods_id = NEW.good_id;
IF EXISTS(select from good_sum_mart T where T.good_name = g_name)
THEN UPDATE good_sum_mart T SET sum_sale = sum_sale + g_price where T.good_name = g_name;
ELSE INSERT INTO good_sum_mart (good_name, sum_sale) values(g_name, g_price);
END IF;
RETURN NEW;
END;
$TRIG_FUNC$
LANGUAGE plpgsql
VOLATILE
SET search_path = pract_functions, public
COST 50;
```
* теперь создаю сам триггер
```
CREATE TRIGGER tr_insert_sales
AFTER INSERT
ON sales
FOR EACH ROW
EXECUTE PROCEDURE ft_insert_sales();
```
> Создаю триггерную функцию удаление записи текущей стоймости у которой значение меньше либо равна 0 
```
CREATE or replace function ft_delete_sales()
RETURNS trigger
AS
$TRIG_FUNC$
DECLARE
g_name varchar(63);
g_price numeric(12,2);
BEGIN
SELECT G.good_name, G.good_price*OLD.sales_qty INTO g_name, g_price FROM goods G where G.goods_id = OLD.good_id;
IF EXISTS(select from good_sum_mart T where T.good_name = g_name)
THEN 
UPDATE good_sum_mart T SET sum_sale = sum_sale - g_price where T.good_name = g_name;
DELETE FROM good_sum_mart T where T.good_name = g_name and (sum_sale < 0 or sum_sale = 0);
END IF;
RETURN NEW;
END;
$TRIG_FUNC$
LANGUAGE plpgsql
VOLATILE
SET search_path = pract_functions, public
COST 50;
```
* добавляю триггер.
```
CREATE TRIGGER tr_delete_sales
AFTER DELETE
ON sales
FOR EACH ROW
EXECUTE PROCEDURE ft_delete_sales();
```
> При обновлении 
```
CREATE or replace function ft_update_sales()
RETURNS trigger
AS
$TRIG_FUNC$
DECLARE
g_name_old varchar(63);
g_price_old numeric(12,2);
g_name_new varchar(63);
g_price_new numeric(12,2);
BEGIN
SELECT G.good_name, G.good_price*OLD.sales_qty INTO g_name_old, g_price_old FROM goods G where G.goods_id = OLD.good_id;
SELECT G.good_name, G.good_price*NEW.sales_qty INTO g_name_new, g_price_new FROM goods G where G.goods_id = NEW.good_id;
IF EXISTS(select from good_sum_mart T where T.good_name = g_name_new)
THEN UPDATE good_sum_mart T SET sum_sale = sum_sale + g_price_new where T.good_name = g_name_new;
ELSE INSERT INTO good_sum_mart (good_name, sum_sale) values(g_name_new, g_price_new);
END IF;
IF EXISTS(select from good_sum_mart T where T.good_name = g_name_old)
THEN 
UPDATE good_sum_mart T SET sum_sale = sum_sale - g_price_old where T.good_name = g_name_old;
DELETE FROM good_sum_mart T where T.good_name = g_name_old and (sum_sale < 0 or sum_sale = 0);
END IF;
RETURN NEW;
END;
$TRIG_FUNC$
LANGUAGE plpgsql
VOLATILE
SET search_path = pract_functions, public
COST 50;
```
* добавляю триггер.
```
CREATE TRIGGER tr_update_sales
AFTER UPDATE
ON sales
FOR EACH ROW
EXECUTE PROCEDURE ft_update_sales();
```

### Задание со звездочкой*

> Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?
Подсказка: В реальной жизни возможны изменения цен.

__Решение:__ 
Благодаря тому, что изменение цен идет инкрементивным способом, а не вычисляется каждый раз с нуля - мы сохраняем общие стоимости всех транзакций на момент их совершения. Но при текущей схеме БД реализовать корректное удаление из стоимости от витрины - не представляется возможным, т.к. для вычитания мы используем текущее значение стоимости, а не стоимость на момент транзакции.

Возможно потребуется расширить таблицу sales колонкой стоимости единицы на момент заключения договора купли-продажи, что бы сумма сделки корректно высчитывалась и вычиталась из витрины.
