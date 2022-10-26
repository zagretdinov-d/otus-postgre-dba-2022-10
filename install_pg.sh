echo "Установка до последней версии"
echo "Обновление до последней версии"
sudo apt update && sudo apt upgrade -y -q
echo "добавляем репозитории последней версии"
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
echo "Install postgresql-15"
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql-15

# sudo pg_ctlscluster 15 main stop //останавливает кластер
# sudo pg_createcluster 15 main2 //Создание нового кластера


