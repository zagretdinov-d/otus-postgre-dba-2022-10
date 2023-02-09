## Подготовка инфраструктуры кластера с помощью terraform.
---

* __Установка в Linux Mint Terraform.__
```
$ curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
$ sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
$ sudo apt install terraform
```
Проверяю версию установленного терраформа
```
damir@dev:~$ terraform version
Terraform v1.3.7
on linux_amd64
```
* __Инициализация данных__
В моем случае я скачиваю данные с ЛК Google cloud, объявляю данные в переменных провайдера терраформа и инициализирую следующей командой. 
```terraform init```

* __Модульная структура данных терраформа__
  
  ```
  damir@dev:~/patroni_project$ tree terraform/
  terraform/
  ├── balancer.tf
  ├── counter
  ├── main.tf
  ├── mygcp-creds.json
  ├── network.tf
  ├── node-1.tf
  ├── node-2.tf
  ├── node-3.tf
  ├── terraform.tfstate
  ├── terraform.tfstate.backup
  ├── terraform.tfvars
  └── variables.tf
  ```
> В моем случае будет созданна инфраструтура состоящая из 4 машин - сам балансер + 3 ноды. Для данной инфраструтуры будет созданна своя подсеть, то есть я объявляю переменные ip адресов в файле terraform.tfvars.

* __Основные команды__
  * Для приведения системы в целевое состояние используется команда    terraform -auto-approve=true apply - идемпотентна!
  * Для просмотра, какие изменения будут применены terraform plan
  * Для обновления конфигурации terraform refresh
  * Для просмотра выходных переменных terraform output
  * Для пересоздания ресурса terraform taint google_compute_instance.app
  * После создания инфраструктуры в папке появляется state-файл со всей созданной инфраструктурой и удаляется после terraform-destroy

> Для приведения систему в действтия в корне папки terraform я выполняю команду 

```terraform apply```

В результате получаю: