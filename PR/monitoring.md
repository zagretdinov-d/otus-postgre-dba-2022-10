### Настройка агента Zabbix 5 на Centos-7.
---

__Устанавливаю агент Zabbix 5__

```
yum install https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install zabbix-agent
```
__Отредактирую файл.__
```
Server=ip сервера zabbix
ServerActive= ip сервера zabbix
Hostname=имя клиента узла
```
__Стартую агент__
```
sudo systemctl start zabbix-agent
sudo systemctl enable zabbix-agent
```
> Теперь загружаю конфигурацию и скрипты для мониторинга баз postgres c соответсвующих источников для каждого узла. Далле создаю для них отдельные каталоги с правами для zabbix. 
```
sudo mkdir /var/lib/zabbix
sudo chown zabbix:zabbix /var/lib/zabbix/
sudo chmod 755 /var/lib/zabbix/
sudo mkdir /var/lib/zabbix/postgresql

sudo cp zabbix_template_postgres/templates/db/postgresql/postgresql/* /var/lib/zabbix/postgresql/
sudo cp zabbix_template_postgres/templates/db/postgresql/template_db_postgresql.conf /etc/zabbix/zabbix_agentd.d/
```

__Создаю пользователя с правами zbx_monitor доступа к серверу.__
```
create user zbx_monitor with password 'password' ******;
grant pg_monitor to zbx_monitor;
```
__Редактирую pg_hba.conf, чтобы разрешить соединения с агентом Zabbix__
vi /var/lib/pgsql/12/data/pg_hba.conf
host    all              zbx_monitor 127.0.0.1/32 trust
host    all             zbx_monitor     0.0.0.0/0       md5

## Настройка prometheus на Centos-7
---

* __загружаю пакеты__
```
wget https://github.com/prometheus/prometheus/releases/download/v2.27.1/prometheus-2.27.1.linux-amd64.tar.gz
```

* __добавляю пользователя__

sudo useradd --no-create-home --shell /bin/false prometheus

* __создаю директории и назначаю владельца__
```
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus
```

* __разархивирую файлы prometheus__
```
tar -xvzf prometheus-2.27.1.linux-amd64.tar.gz
```
* __переменовываю и копирую в директории.__
```
sudo mv prometheus-2.27.1.linux-amd64 prometheuspackage
sudo cp prometheuspackage/prometheus /usr/local/bin/
sudo cp prometheuspackage/promtool /usr/local/bin/
```
Измените владельца на пользователя Prometheus Скопируйте каталоги «consoles» и «console_libraries» из «prometheuspackage» в «папку /etc/prometheus».
```
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

sudo cp -r prometheuspackage/consoles /etc/prometheus
sudo cp -r prometheuspackage/console_libraries /etc/prometheus

sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
```

Теперь мы создадим файл prometheus.yml.
```
sudo vim /etc/prometheus/prometheus.yml

global:
  scrape_interval: 10s
scrape_configs:
  - job_name: 'prometheus_master'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
```
* __Настройте служебный файл Prometheus и Скопируйте следующее содержимое в файл.__

```
sudo vim /etc/systemd/system/prometheus.service

[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries
[Install]
WantedBy=multi-user.target
```
Перезагружаю демона и prometheus.
```
sudo systemctl daemon-reload
sudo systemctl start prometheus
```
* __Настройка мониторинга  master ноды с помощью prometheus.__

Скачиваю архив postgres_exporter
```
wget https://github.com/wrouesnel/postgres_exporter/releases/download/v0.5.1/postgres_exporter_v0.5.1_linux-amd64.tar.gz
```
Создаю директорию и добавляю владельца.
```
sudo mkdir /opt/postgres_exporter
sudo adduser -M -r -s /sbin/nologin postgres_exporter
sudo chown -R postgres_exporter:postgres_exporter /opt/postgres_exporter
```
Создаю фаил .env для доступа к базе postgres по 9001 порту и добавляю запись data source.

```
sudo cd /opt/postgres_exporter
sudo vi postgres_exporter.env

DATA_SOURCE_NAME="postgresql://devops:51324ASdfQWer@35.232.96.109:9001/test?sslmode=disable"
```

Создаю сценарий запуска systemd сервиса postgres_exporter. Для этого создаю файл
```
sudo vi /etc/systemd/system/postgres_exporter.service

[Unit]
Description=Prometheus exporter for Postgresql
Wants=network-online.target
After=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
WorkingDirectory=/opt/postgres_exporter
EnvironmentFile=/opt/postgres_exporter/postgres_exporter.env
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=:9101 --web.telemetry-path=/metrics
Restart=always

[Install]
WantedBy=multi-user.target
```
Запускаю postgres_exporter
```
sudo systemctl daemon-reload
sudo systemctl start postgres_exporter.service
sudo systemctl enable postgres_exporter.service
```

* __Настрою Prometheus для получения данных postgres_exporter__

В файле prometheus.yml для работы с postgres_exporter:
В scrape_configs добавьте следующую секцию:
```
 - job_name: 'postgres_exporter<ip_master:9001>'
    static_configs:
      - targets: ['ip_master:9101']
```
Перезапускаю сервис Prometheus:
sudo systemctl reload prometheus.service
* __Настройка Grafana__
Для визуализации полученных данных установите соответствующие Dashboard