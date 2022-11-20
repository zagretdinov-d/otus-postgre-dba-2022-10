# Lesson 9
### Тема: Работа с журналами

* __Цель:__

  * уметь работать с журналами и контрольными точками
  * уметь настраивать параметры журналов

### Решение:
* __создаю GCE инстанс типа e2-medium__
```
damir@Damir:~$ gcloud beta compute instances create postgres-node-2 \
> --machine-type=e2-medium \
> --image-family ubuntu-2004-lts \
> --image-project=ubuntu-os-cloud \
> --boot-disk-size=10GB \
> --boot-disk-type=pd-ssd \
> --tags=postgres \
> --restart-on-failure
```
