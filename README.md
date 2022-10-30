# Lesson 3
### Тема: Установка и настройка PostgteSQL в контейнере Docker
* __Цель__:
  * установить PostgreSQL в Docker контейнере
  * настроить контейнер для внешнего подключения

* __Решение:__

___Cоздание ВМ с Ubuntu 20.04/22.04 или развернуть докер любым удобным способом___

* Раннее в предыдущем задание были развернуты инстанции Ubuntu 22.04, произвожу запуск одной инстанции с именем pgnode-1 и на ней буду выполнять все по шаговые действия.

![image](https://user-images.githubusercontent.com/85208391/198849625-407b2ffa-7d62-43fc-be14-3f7e0bf1661f.png)

* Убеждаюсь и проверяю установленны ли кластеры PostgreSQL применяя следующие команды.

``` 
pg_lsclusters
sudo pg_ctlcluster 14 main stop
sudo pg_dropcluster 14 main
```

![image](https://user-images.githubusercontent.com/85208391/198852411-50128c7f-b8f5-4ba6-b15c-d79678b42e44.png)

* Все кластера успешно удалены.

___Установка Docker Engine___

* Приступаю к установке Docker.
```
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && rm get-docker.sh && sudo usermod -aG docker $USER
```

![image](https://user-images.githubusercontent.com/85208391/198853185-945f4d3a-38d7-4ee8-93e7-a05566b0a077.png)

* Запускаю docker и добавляю автозагрузку.

```
sudo systemctl start docker
sudo systemctl enable docker
```

![image](https://user-images.githubusercontent.com/85208391/198853447-8c2f0c8c-9b9c-4e98-8c66-83b670f304c6.png)

* Создаю Docker Postgres Volume — каталог для хранения данных, то есть сделаю каталог /var/lib/postgres
```
sudo mkdir -p /var/lib/postgres
```

* Создаю сеть, разворачиваю контейнер с PostgreSQL 14 и смонтирую в него созданный каталог /var/lib/postgres
```
sudo docker network create pg-net
sudo docker run --name pg-node --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:14
```

![image](https://user-images.githubusercontent.com/85208391/198855489-a0d8c526-c5ca-4db1-adb0-a7fd42e33cb3.png)

* Видно что все успешно поставилось c соответственно запустилось.
``` sudo docker ps ```

![image](https://user-images.githubusercontent.com/85208391/198858160-5fc0c349-dae9-4651-992c-942b133c841d.png)


* Разворачиваю отдельный контейнер с клиентом postgres
   * Подключась из контейнера с клиентом к контейнеру с сервером
   ``` 
   sudo docker run -it --rm --network pg-net --name pg-client postgres:14 psql -h pg-node -U postgres 
   ```
   * Создаю таблицу с парой строк используя следующие команды.
   ```
   create table city (id int, name varchar(60));
   insert into city values (1, 'Astana'), (2, 'Karaganda');
   select * from city;
   ```
* И в результате 

![image](https://user-images.githubusercontent.com/85208391/198858660-c40b5e11-6083-46cc-b0d9-b5f50669bf58.png)

* Убедимся что подключились через отдельный контейнер. ```sudo docker ps -a```

![image](https://user-images.githubusercontent.com/85208391/198859156-f0c2f77d-af92-49c7-b54b-52decf6c0fcc.png)


___Подключения к контейнеру с сервером с компьютера извне инстансов GCP места установки докера___
* В данном случае я все разворачивал на google облаке. Перед тем чтоб подключиться к серверу со своего компьютера необходимо добавить порт 5432 в облаке и сохранить.
![image](https://user-images.githubusercontent.com/85208391/198860710-447219ec-23af-48db-abde-ce76b7bdf607.png)



* После добавления порта успешно подключаюсь. ```psql -p 5432 -U postgres -h <external_IP> -d postgres -W```

![image](https://user-images.githubusercontent.com/85208391/198860761-be889ff6-c393-45c6-b1b3-5db308bb2c3d.png)


![image](https://user-images.githubusercontent.com/85208391/198861281-6ad57844-756f-42e0-8f04-0698f4bb754c.png)

* Удаление контейнера с сервера.
* Создание заного контейнера
* Подключаюсь снова из контейнера с клиентом к контейнеру с сервером
  ``` 
  По данным поставленным целям выполняю следующие команды:
  sudo docker stop <container_id>
  sudo docker rm <container_id>
  sudo docker run --name pg-node --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:14
  ```
В результате получаю:

![image](https://user-images.githubusercontent.com/85208391/198866842-a188aa75-af99-48d6-ba28-d97307b262e5.png)

* Как видно на скриншоте все данные остались на месте, так как был изначально создан Docker Postgres Volume — каталог для хранения данных и соответственно примонтирован в docker run.

## Дополнения
В качестве дополнения проведу работу с docker-compose.
Устанавливаю docker-compose ``` sudo apt install docker-compose -y ```
файл docker-compose.yml на гите.
где можно командами
``` 
git clone <github>
unzip <repository>
cd <repository>
sudo docker-compose up -d
```
то есть клоним с гитлаба, разархивируем, проваливаемся в каталог и запускаем.

* Еще пару вариантов
   * с помощью команды ```scp``` отправляю файлик docker-compose.yml на сервер и вы полняю команду ``` sudo docker-compose up -d ```.
   * Copy-past создал файлик docker-compose.yml скопировал вставил содержимое.

* В результате все успешно запустилось, примонтировалось и работает.

![image](https://user-images.githubusercontent.com/85208391/198874212-c47ca3ad-60ed-4ec1-b0fd-9e261aa565d1.png)

Для просмотра содержимого, файл docker-compose.yml так же загружен в github.

## Заключение
* Изучен и установлен PostgreSQL-14 в Docker контейнер
* Настроен контейнер для внешнего подключения 
* Проведена дополнительная работа с инструментом docker compose.  
