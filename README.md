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

![image](https://user-images.githubusercontent.com/85208391/197832445-cb9b0d8d-9f25-4e32-bc66-14b42f646bf8.png)

