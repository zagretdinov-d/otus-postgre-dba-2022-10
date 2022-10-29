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

![image](https://user-images.githubusercontent.com/85208391/198853185-945f4d3a-38d7-4ee8-93e7-a05566b0a077.png)

![image](https://user-images.githubusercontent.com/85208391/198853447-8c2f0c8c-9b9c-4e98-8c66-83b670f304c6.png)





