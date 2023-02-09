### Изменение настроек PostgreSQL через Patroni.

> PostgreSQL управляется Patroni и настройки PostgreSQL задаются через конфигурационный файл Paroni. Данные настройки должны быть одинаковыми на всех узлах. Для задания настроек PostgreSQL я использую параметр "parameters" в секции "postgresql" файла /etc/patroni/config.yml.

 __определяю оптимальные параметры postgres c помощью https://pgtune.leopard.in.ua/__
```
  parameters:
    unix_socket_directories: '/var/run/postgresql'
    max_connections: 20
    shared_buffers: 1GB
    effective_cache_size: 3GB
    maintenance_work_mem: 512MB
    checkpoint_completion_target: 0.9
    wal_buffers: 16MB
    default_statistics_target: 500
    random_page_cost: 1.1
    effective_io_concurrency: 200
    work_mem: 13107kB
    min_wal_size: 4GB
    max_wal_size: 16GB
```