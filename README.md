# Lesson 6
### Тема: Физический уровень PostgreSQL

* __Цель__:

   - создавать дополнительный диск для уже существующей виртуальной машины, размечать его и делать на нем файловую систему
   
   - переносить содержимое базы данных PostgreSQL на дополнительный диск
   - переносить содержимое БД PostgreSQL между виртуальными машинами

* __Решение__:

___Создаю виртуальную машину c Ubuntu 20.04 LTS (bionic) в GCE___

  ![изображение](https://user-images.githubusercontent.com/85208391/200965481-29dc733e-b6cb-42dd-92ee-bfb98bc58afc.png)
  
___поставлена версия PostgreSQL 14 и проверена___

```sudo -u postgres pg_lsclusters```

![изображение](https://user-images.githubusercontent.com/85208391/200966515-3e175450-409b-4e33-9f3a-81ef8c5c5bf6.png)


___Cогласно заданию захожу из под пользователя postgres в psql и создаю произвольную таблицу с произвольным содержимым___

``` postgres=# create table test(c1 text);```

``` postgres=# insert into test values('1');```

![image](https://user-images.githubusercontent.com/85208391/201454914-a674446d-2b53-4d53-81b0-971c3f77a697.png)


![изображение](https://user-images.githubusercontent.com/85208391/200985501-fa3502df-8e4a-462e-a516-c041f72b893a.png)
