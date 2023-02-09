## Резервное копирование
Резервная копия базы данных будет сниматься с помощью написанного мною скрипта

Создаю директорий и файлы:
```
sudo mkdir /var/lib/pg_backup
```
Создаю переменную с данными.
```
sudo vi /var/lib/pg_backup/variables.conf

logfile="/var/lib/pg_backup/backups.log"
pathB="/mnt/backup"
dbUser="postgres"
database="test"
ip_backup_host="10.0.0.2"
node1="10.0.0.3"
node2="10.0.0.4"
node3="10.0.0.5"
```

```
sudo vi /var/lib/pg_backup/start_backup.sh

//Скрипт для резервного копирование на резервный сервер. 


!/bin/bash
#trap 'echo "# $BASH_COMMAND";read' DEBUG
source /var/lib/pg_backup/variables.conf
sudo chmod 777 $pathB
mkdir $pathB
count=3    # для пинга
result1=$(ping -c ${count} ${node1} 2<&1| grep -icE 'unknown|expired|unreachable|timeout|time out')
if [ "$result1" -eq 0 ]; then
        sleep 5
        replica1=$(ssh devops@$node1 patronictl -c /etc/patroni/config.yml list | grep " db-" | grep -v "Leader" | head -1 | awk -F"|" '{print $3}' | awk '{print $1}')
echo $replica1
        echo `date +%Y.%m.%d__%H:%M:%S`" Noda1 Replica: $replica1" >> ${logfile}
ssh devops@$replica1 << EOF
mkdir $pathB
sudo chmod 777 $pathB
sudo find $pathB -ctime +7 -delete
pg_dump -U $dbUser $database > $pathB/"$database"_pgsql_$(date "+%Y-%m-%d").sql
scp $pathB/"$database"_pgsql_$(date "+%Y-%m-%d").sql devops@$ip_backup_host:$pathB
EOF
#ssh devops@$ip_backup_host << EOF
#find $pathB -ctime +7 -delete
#EOF
sudo echo `date +%Y.%m.%d__%H:%M:%S`" Backup completed successfully"  >> ${logfile}
fi

if [ "$result1" != 0 ]; then
        echo `date +%Y.%m.%d__%H:%M:%S`" ERROR!  Bad PING-TEST to 'Node1' ($node1)" >> ${logfile}     # сообщение, если все пинги не пройдены

echo "node 2 monitoring $node2"
result2=$(ping -c ${count} ${node2} 2<&1| grep -icE 'unknown|expired|unreachable|timeout|time out')
if [ "$result2" -eq 0 ]; then
replica2=$(ssh devops@$node2 patronictl -c /etc/patroni/config.yml list | grep " db-" | grep -v "Leader" | head -1 | awk -F"|" '{print $3}' | awk '{print $1}')
echo " Replica: $replica2" >> ${logfile}
ssh devops@$replica2 << EOF
mkdir $pathB
sudo chmod 777 $pathB
find $pathB -ctime +7 -delete
pg_dump -U $dbUser $database > $pathB/"$database"_pgsql_$(date "+%Y-%m-%d").sql
scp $pathB/"$database"_pgsql_$(date "+%Y-%m-%d").sql root@$ip_backup_host:$pathB
EOF
ssh devops@$ip_backup_host << EOF
find $pathB -ctime +7 -delete
EOF
sed -i 's/echo.*/echo "0"/' /var/lib/pg_backup/bk-live.sh
/var/lib/pg_backup/bk-live.sh && sleep 10
echo "Backup completed successfully" >> ${logfile}
fi
       if [ "$result2" != 0 ]; then
                    echo "ERROR!  Bad PING-TEST to 'Node-Replica' ($node2)" >> ${logfile}     # сообщение, если все пинги не пройдены
                    echo "ERROR - BACKUP!" >> ${logfile}
                    exit 1

fi
fi
```
Для запуска меняю привелегии.
```
sudo chmod +x /var/lib/pg_backup/start_backup.sh
```
Добавляю запись для ежедневного запуска скрипта.

```
crontab -e
0 3 * * * /var/lib/pg_backup/start_backup.sh
```

>Данный скрипт запускается ежедневно в 3 часа ночи. 
Шаг первый - Проверяется доступность узла по ip адресу что объявлен в переменных.
Шаг второй - Проверяется какой узел в кластере является слэйвом, то есть при обращение к живому узлу кластера с помощью выполнения запроса в таблицу считывается ip адрес уже слэйв узла.
Шаг третий - по SSH проваливается на узел и выполняется pg_dump.
Шаг четвертый - копирует на удаленный сервер.
Шаг пятый - удаляет бэкапы старше 7 дней.  
 