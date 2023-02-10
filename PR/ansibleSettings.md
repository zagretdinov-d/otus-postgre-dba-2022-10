### Развёртывание отказоустойчивого кластера PostgreSQL + Patroni + etcd + HAProxy с помощью Ansible.

* __Устанавливаю Ansible на свою OS.__
```
sudo apt-add-repository ppa:Ansible/Ansible
sudo apt-get update && sudo apt-get install Ansible
```
Проверяю версию.
```
damir@dev:~/patroni_project$ ansible --version
ansible 2.9.6
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/home/damir/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 3.8.10 (default, Jun 22 2022, 20:18:18) [GCC 9.4.0]
```
* __Модульная структура данных ansible__
```
damir@dev:~/patroni_project$ tree ansible/
ansible/
├── defaults
│   └── main.yml
├── inventory.yml
├── requirements.txt
├── site.yml
├── tasks
│   ├── add_etcd_config.yml
│   ├── add_haproxy_config.yml
│   ├── add_patroni_config.yml
│   ├── add_repo.yml
│   ├── firewall.yml
│   ├── install_etcd.yml
│   ├── install_patroni.yml
│   ├── os_update.yml
│   ├── percona_release.yml
│   └── selinux_off.yml
└── templates
    ├── etcd_1.conf
    ├── etcd_2.conf
    ├── etcd_3.conf
    ├── haproxy.cfg
    ├── patroni.service
    └── patroni.yml

3 directories, 20 files
```
> Развертывание отказоустоичевого кластера полностью выполняет ansible то есть выполняются последовательные пошаговые действия по установке и наcтройке конфигураций. 

Команда для запуска всей структуры:
```
ansible-playbook -i inventory.yml site.yml
```
Команда выполняетя после того как terraform полностью выполнит работу над созданием машин в облаке.


