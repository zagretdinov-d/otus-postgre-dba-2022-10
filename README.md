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

___Останавливаю postgres___
``` sudo -u postgres pg_ctlcluster 14 main stop либо sudo systemctl start postgresql@14-main```

![image](https://user-images.githubusercontent.com/85208391/201456403-740bd19a-bd0e-45f6-b96e-d5f7b4dd9f37.png)

___Создаю новый standard persistent диск GKE через Compute Engine -> Disks в том же регионе и зоне что GCE инстанс размером например 10GB___

* В результате получилось:

![изображение](https://user-images.githubusercontent.com/85208391/200985501-fa3502df-8e4a-462e-a516-c041f72b893a.png)

* Добавил диск disk-1 к ВМ node-1

___Инициализация диска___
* Проверяю новый диск

```
damir@node-1:~$ lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0     7:0    0  55.6M  1 loop /snap/core18/2566
loop1     7:1    0  63.2M  1 loop /snap/core20/1623
loop2     7:2    0 301.2M  1 loop /snap/google-cloud-cli/77
loop3     7:3    0  67.8M  1 loop /snap/lxd/22753
loop4     7:4    0    48M  1 loop /snap/snapd/17029
loop5     7:5    0    48M  1 loop /snap/snapd/17336
loop6     7:6    0  55.6M  1 loop /snap/core18/2620
loop7     7:7    0  63.2M  1 loop /snap/core20/1695
loop8     7:8    0 301.9M  1 loop /snap/google-cloud-cli/87
sda       8:0    0    10G  0 disk 
├─sda1    8:1    0   9.9G  0 part /
├─sda14   8:14   0     4M  0 part 
└─sda15   8:15   0   106M  0 part /boot/efi
sdb       8:16   0    10G  0 disk
```
___Деление нового диска GPT partition___

```
damir@node-1:~$ sudo parted /dev/sdb mklabel gpt
Warning: The existing disk label on /dev/sdb will be destroyed and all data on this disk will be lost. Do you want
to continue?
Yes/No? Yes                                                               
Information: You may need to update /etc/fstab.
```
* Создаю раздел на весь диск: ```sudo parted -a opt /dev/sdb mkpart primary ext4 0% 100%```

_проверяю:_
```
damir@node-1:~$ lsblk                                                     
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0     7:0    0  55.6M  1 loop /snap/core18/2566
loop1     7:1    0  63.2M  1 loop /snap/core20/1623
loop2     7:2    0 301.2M  1 loop /snap/google-cloud-cli/77
loop3     7:3    0  67.8M  1 loop /snap/lxd/22753
loop4     7:4    0    48M  1 loop /snap/snapd/17029
loop5     7:5    0    48M  1 loop /snap/snapd/17336
loop6     7:6    0  55.6M  1 loop /snap/core18/2620
loop7     7:7    0  63.2M  1 loop /snap/core20/1695
loop8     7:8    0 301.9M  1 loop /snap/google-cloud-cli/87
sda       8:0    0    10G  0 disk 
├─sda1    8:1    0   9.9G  0 part /
├─sda2    8:2    0  1007K  0 part 
├─sda14   8:14   0     4M  0 part 
└─sda15   8:15   0   106M  0 part /boot/efi
sdb       8:16   0    10G  0 disk 
└─sdb1    8:17   0    10G  0 part 
```
* Создаю файловую систему:

```
damir@node-1:~$ sudo mkfs.ext4 -L datapartition /dev/sdb1
mke2fs 1.45.5 (07-Jan-2020)
Discarding device blocks: done                            
Creating filesystem with 2620928 4k blocks and 655360 inodes
Filesystem UUID: f0a490c7-8c2a-4449-8ae6-e8e94bab2652
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done
```
* Меняю метку раздела и проверяю
```
damir@node-1:~$ sudo e2label /dev/sdb1 pg_devops
damir@node-1:~$ lsblk --fs
NAME    FSTYPE   LABEL           UUID                                 FSAVAIL FSUSE% MOUNTPOINT
loop0   squashfs                                                            0   100% /snap/core18/2566
loop1   squashfs                                                            0   100% /snap/core20/1623
loop2   squashfs                                                            0   100% /snap/google-cloud-cli/77
loop3   squashfs                                                            0   100% /snap/lxd/22753
loop4   squashfs                                                            0   100% /snap/snapd/17029
loop5   squashfs                                                            0   100% /snap/snapd/17336
loop6   squashfs                                                            0   100% /snap/core18/2620
loop7   squashfs                                                            0   100% /snap/core20/1695
loop8   squashfs                                                            0   100% /snap/google-cloud-cli/87
sda                                                                                  
├─sda1  ext4     cloudimg-rootfs 7bfcb64a-21ec-4573-80d8-a894782410b7    6.9G    27% /
├─sda2                                                                               
├─sda14                                                                              
└─sda15 vfat     UEFI            12A9-4639                              99.2M     5% /boot/efi
sdb                                                                                  
└─sdb1  ext4     pg_devops       f0a490c7-8c2a-4449-8ae6-e8e94bab2652  
```

_pg_devops - это будет метка, файловая система - ext4._

* Монтирую новый диск.
```
damir@node-1:~$ sudo mkdir -p /mnt/data
damir@node-1:~$ sudo mount -o defaults /dev/sdb1 /mnt/data
```
_следующей командой проверяю:_
```
damir@node-1:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       9.6G  2.6G  6.9G  28% /
devtmpfs        983M     0  983M   0% /dev
tmpfs           987M     0  987M   0% /dev/shm
tmpfs           198M  952K  197M   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           987M     0  987M   0% /sys/fs/cgroup
/dev/loop0       56M   56M     0 100% /snap/core18/2566
/dev/loop1       64M   64M     0 100% /snap/core20/1623
/dev/loop2      302M  302M     0 100% /snap/google-cloud-cli/77
/dev/loop3       68M   68M     0 100% /snap/lxd/22753
/dev/loop4       48M   48M     0 100% /snap/snapd/17029
/dev/sda15      105M  5.2M  100M   5% /boot/efi
/dev/loop5       48M   48M     0 100% /snap/snapd/17336
/dev/loop6       56M   56M     0 100% /snap/core18/2620
/dev/loop7       64M   64M     0 100% /snap/core20/1695
/dev/loop8      302M  302M     0 100% /snap/google-cloud-cli/87
tmpfs           198M     0  198M   0% /run/user/1001
/dev/sdb1       9.8G   24K  9.3G   1% /mnt/data
```
_в результате: /dev/sdb1 - /mnt/data_

* Чтобы диск нормально примонтировался после перезагрузки - делаю изменения прописываю в /etc/fstab то есть вношу запись данные диска:
```
damir@node-1:~$ cat /etc/fstab
LABEL=cloudimg-rootfs	/	 ext4	defaults	0 1
LABEL=UEFI	/boot/efi	vfat	umask=0077	0 1
#/dev/sdb1
UUID=4e2d2239-6d21-4578-a199-eefe22ca059c /mnt/data ext4  defaults 0 0
LABEL=pg_devops   /mnt/data       ext4    defaults        0 0
```
_Проверяю_
```
damir@node-1:~$ sudo mount -a
damir@node-1:~$ lsblk -fs
NAME  FSTYPE   LABEL           UUID                                 FSAVAIL FSUSE% MOUNTPOINT
loop0 squashfs                                                            0   100% /snap/core18/2566
loop1 squashfs                                                            0   100% /snap/core18/2620
loop2 squashfs                                                            0   100% /snap/core20/1623
loop3 squashfs                                                            0   100% /snap/core20/1695
loop4 squashfs                                                            0   100% /snap/google-cloud-cli/77
loop5 squashfs                                                            0   100% /snap/google-cloud-cli/87
loop6 squashfs                                                            0   100% /snap/lxd/22753
loop7 squashfs                                                            0   100% /snap/snapd/17336
loop8 squashfs                                                            0   100% /snap/snapd/17029
sda1  ext4     cloudimg-rootfs 7bfcb64a-21ec-4573-80d8-a894782410b7    6.9G    27% /
└─sda                                                                              
sda2                                                                               
└─sda                                                                              
sda14                                                                              
└─sda                                                                              
sda15 vfat     UEFI            12A9-4639                              99.2M     5% /boot/efi
└─sda                                                                              
sdb1  ext4     pg_devops       4e2d2239-6d21-4578-a199-eefe22ca059c    9.2G     0% /mnt/data
└─sdb
```

_после того как я перемонтировал sudo mount -a, всё прошло удачно и проверил диск sdb1._ 

* Проверка доступности файловой системы нового диска.
```
damir@node-1:~$ df -h -x tmpfs -x devtmpfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1       9.8G   24K  9.3G   1% /mnt/data
```
_Диск на месте._

___Тест файловой системы нового диска.___

```
damir@node-1:~$ ls -l /mnt/data
total 16
drwx------ 2 root root 16384 Nov 12 06:54 lost+found
damir@node-1:~$ echo "testing" | sudo tee /mnt/data/file
testing
damir@node-1:~$ cat /mnt/data/file
testing
damir@node-1:~$ sudo rm /mnt/data/file
damir@node-1:~$ cat /mnt/data/file
cat: /mnt/data/file: No such file or directory
```
_файловая система нового диска работает нормально_

__Делаю пользователя postgres владельцем /mnt/data__ 
```
damir@node-1:~$ sudo chown -R postgres:postgres /mnt/data/
damir@node-1:~$ ls -l /mnt/data
total 16
drwx------ 2 postgres postgres 16384 Nov 12 06:54 lost+found

```
__Переношу содержимое /var/lib/postgres/14 в /mnt/data__
```
damir@node-1:~$ sudo mv /var/lib/postgresql/14 /mnt/data
damir@node-1:~$ ls -l /mnt/data
total 20
drwxr-xr-x 3 postgres postgres  4096 Nov  9 23:33 14
drwx------ 2 postgres postgres 16384 Nov 12 06:54 lost+found
```
попытайтесь запустить кластер - sudo -u postgres pg_ctlcluster 14 main start

__Попытка запустить кластер - sudo -u postgres pg_ctlcluster 14 main start___

```
damir@node-1:~$ sudo -u postgres pg_ctlcluster 14 main start
Error: /var/lib/postgresql/14/main is not accessible or does not exist
```
__Напишите получилось или нет и почему???__

#### Ответ:  Ну конечно не получилось, все данные postgres были перенесены на новое место и соответственно postgres не стартует. 
__Для исправления данной ошибки я выполню следующие действия.__

* Открываю конфигурационный файл /etc/postgresql/14/main/postgresql.conf
```
damir@node-1:~$ cd /etc/postgresql/14/main
damir@node-1:/etc/postgresql/14/main$ ls 
conf.d  environment  pg_ctl.conf  pg_hba.conf  pg_ident.conf  postgresql.conf  start.conf
damir@node-1:/etc/postgresql/14/main$ sudo nano postgresql.conf
damir@node-1:/etc/postgresql/14/main$ sudo -u postgres pg_ctlcluster 14 main start
Warning: the cluster will not be running as a systemd service. Consider using systemctl:
  sudo systemctl start postgresql@14-main
Removed stale pid file.
```
* Изменяю data_directory = '/var/lib/postgresql/14/main' на data_directory = '/mnt/data/14/main'

* после запуска проверяю кластер:
```
damir@node-1:/etc/postgresql/14/main$ sudo -u postgres pg_lsclusters
Ver Cluster Port Status Owner    Data directory    Log file
14  main    5432 online postgres /mnt/data/14/main /var/log/postgresql/postgresql-14-main.log
```
___Все работает!!!___

* Захожу через psql и проверяю содержимое ранее созданной таблицы

![image](https://user-images.githubusercontent.com/85208391/201466731-931198ac-536f-4785-8197-61e90bc2c71d.png)

## Задание со звездочкой *:
* ___Поднимаю второй сервер называю node-2. Устанавливаю Postgresql-14.___
* ___Далее что необходимо остановить первый сервер и отключить диск, то-есть в данном случае без выполнения данных действий невозможно перемонтировать.___

![image](https://user-images.githubusercontent.com/85208391/201468528-184d96b7-47e9-4f7a-a8a2-d17646861119.png)

 ```
node-1 -> Edit node-1 instance -> remove disk
node-2 -> Edit node-2 instance -> attach existing disk -> Выбор диска.
и сохраняемся.
```
_В результате вывод:_

![image](https://user-images.githubusercontent.com/85208391/201468852-9fe4ba15-87c3-421f-a6fc-1c73b0c6dd33.png)

* __Подключаюсь к новой ВМ node-2 и останавливаю postgresql:__

```
damir@node-2:~$ sudo systemctl stop postgresql
damir@node-2:~$ systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/lib/systemd/system/postgresql.service; enabled; vendor preset: enabled)
     Active: inactive (dead) since Sat 2022-11-12 09:52:49 UTC; 9s ago
   Main PID: 10455 (code=exited, status=0/SUCCESS)

Nov 12 09:08:08 node-2 systemd[1]: Starting PostgreSQL RDBMS...
Nov 12 09:08:08 node-2 systemd[1]: Finished PostgreSQL RDBMS.
Nov 12 09:52:49 node-2 systemd[1]: postgresql.service: Succeeded.
Nov 12 09:52:49 node-2 systemd[1]: Stopped PostgreSQL RDBMS.
damir@node-2:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
```

* __Удаляю файлы с данными из /var/lib/postgres и проверяю диск__
```
damir@node-2:~$ sudo rm -rf /var/lib/postgresql
damir@node-2:~$ lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sdb       8:16   0    10G  0 disk 
└─sdb1    8:17   0    10G  0 part 
```
* __Делаю пользователя postgres владельцем, монтирую внешний диск__

```
sudo chown -R postgres:postgres /var/lib/postgresql/
sudo mount /dev/sdb1 /var/lib/postgresql/
df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       9.6G  2.2G  7.4G  23% /
devtmpfs        2.0G     0  2.0G   0% /dev
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           393M  944K  392M   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/loop0       56M   56M     0 100% /snap/core18/2566
/dev/loop1       64M   64M     0 100% /snap/core20/1623
/dev/loop2      302M  302M     0 100% /snap/google-cloud-cli/77
/dev/loop3       68M   68M     0 100% /snap/lxd/22753
/dev/loop4       48M   48M     0 100% /snap/snapd/17029
/dev/sda15      105M  5.2M  100M   5% /boot/efi
tmpfs           393M     0  393M   0% /run/user/1001
/dev/sdb1       9.8G   42M  9.2G   1% /var/lib/postgresql
```
* __Запуск PostgreSQL__
sudo systemctl start postgresql

* __Тест__

```
damir@node-2:~$ sudo -u postgres psql
psql (14.6 (Ubuntu 14.6-1.pgdg20.04+1))
Type "help" for help.

postgres=# select * from test;
 c1 
----
 1
(1 row)
```
![image](https://user-images.githubusercontent.com/85208391/201469605-46eb921f-c54f-40f9-b55b-c29d05000a2e.png)

Все успешно запустилось и работает.