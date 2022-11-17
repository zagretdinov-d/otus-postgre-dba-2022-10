# Lesson 8
### Тема: Настройка autovacuum с учетом оптимальной производительности

* __Цель:__

  * запустить нагрузочный тест pgbench
  * настроить параметры autovacuum для достижения максимального уровня устойчивой производительности

### Решение:
damir@Damir:~$ gcloud beta compute instances create postgres-node-2 \
> --machine-type=e2-medium \
> --image-family ubuntu-2004-lts \
> --image-project=ubuntu-os-cloud \
> --boot-disk-size=10GB \
> --boot-disk-type=pd-ssd \
> --tags=postgres \
> --restart-on-failure
