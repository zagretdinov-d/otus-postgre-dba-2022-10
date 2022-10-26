# Lesson 2
### Тема: SQL и реляционные СУБД. Введение в PostgreSQL
* __Цель__:
    * научиться работать с Google Cloud Platform на уровне Google Compute Engine (IaaS)ЯндексОБлаке на уровне Compute Cloud
    * научиться управлять уровнем изоляции транзакций в PostgreSQL и понимать особенность работы уровней read commited и repeatable read

* __Решение:__


 _Создание проекта в Google Cloud Platform_
  *    В консоли Google Cloud menu > IAM и администратор > Создать проект;
  *    В поле «Имя проекта» я ввел pg-devops и дату рождения, жму создать;
![image](https://user-images.githubusercontent.com/85208391/197787063-a6b31e59-ec8c-4f84-afd2-3c3124d40a90.png)

_Создаю инстанс виртуальной машины с дефолтными параметрами_
  * VM instances > Create an instance

   ![image](https://user-images.githubusercontent.com/85208391/197797886-41b9cbfb-6482-4e46-9d26-842c6fcd290d.png)

___
## Установка Google Cloud и подключения по SSH
_В данном случае я ипользую OS Linux mint соответственно я буду разворачивать  вданной системе, данный процесс разделил на этапы_

- _Шаг-1: установка gcutil/google SDK_
```
 wget https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz
 tar -zxvf google-cloud-sdk.tar.gz
 bash google-cloud-sdk/install.sh
 sudo snap install google-cloud-sdk --classic
```
_чтобы обновить $PATH и включить завершение bash? ( Т/и ) ? у
далее нажимаю enter_

- _Шаг-2: Аутентификация в Google_
```
gcloud auth login 
gcloud config set project pg-devops1988-10
```
- _Шаг-3: Проверка статуса_
_Ввожу следующую команду_
```
gcloud compute instances list
```
_выходные данные:_

![image](https://user-images.githubusercontent.com/85208391/197828060-be5dd53c-563c-4b9f-a0a4-df7af81cd584.png)

- _Шаг-4: Создание ssh-ключей_
```
gcloud compute ssh pgnode-1
```
![image](https://user-images.githubusercontent.com/85208391/197829735-ce18c323-03bd-446f-b664-6bdfbd40b7ce.png)

_В результате получаем успешно добавленный ключ в облаке_
![image](https://user-images.githubusercontent.com/85208391/197832445-cb9b0d8d-9f25-4e32-bc66-14b42f646bf8.png)

_Так же ssh-add можно выполнить следующим образом_
```
gcloud compute os-login ssh-keys add \
--key-file=.ssh/id_rsa.pub \
--project=pg-devops1988-10
```
- Проваливаюсь по SSH соединению:

![image](https://user-images.githubusercontent.com/85208391/197837031-af6add55-d063-4781-90e1-970469566a0d.png)
---
## Установка PostgreSQL
- Ставим PostgreSQL-14
  ```
  sudo apt update && sudo apt upgrade -y -q
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get update
  sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql-14
  ```
- Установка успешно завершена

  ![image](https://user-images.githubusercontent.com/85208391/197893150-3954412e-6089-487d-a311-c9e5f609115c.png)

-  Подключаюсь по ssh к двум сессиям и запускаю везде psql из под пользователя postgres

  ![image](https://user-images.githubusercontent.com/85208391/197894257-ea6e9fce-356b-4a19-b030-be7fe48326b6.png)

- Отключаю auto commit
```
\set AUTOCOMMIT OFF
\echo :AUTOCOMMIT
```
- Согласно заданию создана новая таблица и добавлены следующие записи в первой сессии:
```
create table persons(id serial, first_name text, second_name text); 
insert into persons(first_name, second_name) values('ivan', 'ivanov'); 
insert into persons(first_name, second_name) values('petr', 'petrov'); 
commit;
```


![image](https://user-images.githubusercontent.com/85208391/197896629-e8df8556-bc18-4e51-84b1-230e18bd7b4f.png)


- Смотрю текущий уровень изоляции:
```
show transaction isolation level;
```
![image](https://user-images.githubusercontent.com/85208391/197898565-ecbb1e51-2f7a-4d86-a733-0386a5d674ad.png)

* Начинаю новую транзакцию на обоих сессиях с дефолтным (не меняя) уровнем изоляции
   * На обоих сесиях
    ``` begin; ``` 
   
    * На первой сессии
    ``` insert into persons(first_name, second_name) values('sergey', 'sergeev'); ```
    * На второй сессии
    ``` select * from persons; ```
    * При выполнения запроса новая запись не была добавлена.
    
    ![image](https://user-images.githubusercontent.com/85208391/197907638-c3d91757-b345-4c43-bbe6-64811435bcc3.png)
    * Причины:
      *   Вторая сессия транзакции не смогла прочитать еще не подтвержденные данные первой сессии транзакции, так как autocommit был отключен.
  ```commit;```

* Завершаю первую сессию транзакций ```commit;```
  * на второй сессии ``` select * from persons;```
  * проверяю после подтверждения commit запись появилась