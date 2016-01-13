#!/bin/bash
# Install Nginx + php-fpm + apc cache for Ubuntu and Debian distributions
cd ~
# apt-get update
# apt-get -fy dist-upgrade
# apt-get -fy upgrade
apt-get install lsb-release bc
REL=`lsb_release -sc`
DISTRO=`lsb_release -is | tr [:upper:] [:lower:]`
NCORES=` cat /proc/cpuinfo | grep cores | wc -l`
WORKER=`bc -l <<< "4*$NCORES"`

OPTION=${1-2}
SharedStorageAccountName=$2
SharedAzureFileName=$3
SharedStorageAccountKey=$4

wget http://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key
add-apt-repository "deb http://nginx.org/packages/$DISTRO/ $REL nginx"
add-apt-repository "deb-src http://nginx.org/packages/$DISTRO/ $REL nginx"

apt-get update


# Create Azure file shere if is the first VM
if [ $OPTION -lt 1 ]; 
then  
# Create Azure file share that will be used by front end VM's for moodledata directory

apt-get -y install nodejs-legacy
apt-get -y install npm
npm install -g azure-cli

sudo azure storage share create $SharedAzureFileName -a $SharedStorageAccountName -k $SharedStorageAccountKey
fi

apt-get install -fy nginx
apt-get install -fy php5-fpm php5-cli php5-mysql
apt-get install -fy php-apc php5-gd
# replace www-data to nginx into /etc/php5/fpm/pool.d/www.conf
sed -i 's/www-data/nginx/g' /etc/php5/fpm/pool.d/www.conf
service php5-fpm restart
# backup default Nginx configuration
mkdir /etc/nginx/conf-bkp
cp /etc/nginx/conf.d/default.conf /etc/nginx/conf-bkp/default.conf
cp /etc/nginx/nginx.conf /etc/nginx/nginx-conf.old
#
# Replace nginx.conf
#
wget https://raw.githubusercontent.com/juliosene/azure-nginx-php/master/templates/nginx.conf

sed -i "s/#WORKER#/$WORKER/g" nginx.conf
mv nginx.conf /etc/nginx/

# replace Nginx default.conf
#
wget https://raw.githubusercontent.com/juliosene/azure-nginx-php/master/templates/default.conf

#sed -i "s/#WORKER#/$WORKER/g" nginx.conf
mv default.conf /etc/nginx/conf.d/

# Memcache client installation
apt-get install -fy php-pear
apt-get install -fy php5-dev
printf "\n" |pecl install -f memcache
#
wget https://raw.githubusercontent.com/juliosene/azure-nginx-php/master/templates/memcache.ini

#sed -i "s/#WORKER#/$WORKER/g" memcache.ini
mv memcache.ini /etc/php5/mods-available/

 ln -s /etc/php5/mods-available/memcache.ini  /etc/php5/fpm/conf.d/20-memcache.ini
 
 # mount share file on /usr/share/nginx/html
if [ $OPTION -ne 2 ];
then
apt-get install cifs-utils
mount -t cifs //$SharedStorageAccountName.file.core.windows.net/$SharedAzureFileName /usr/share/nginx/html -o uid=$(id -u nginx),vers=2.1,username=$SharedStorageAccountName,password=$SharedStorageAccountKey,dir_mode=0770,file_mode=0770
fi

#
# Edit default page to show php info
#
#mv /usr/share/nginx/html/index.html /usr/share/nginx/html/index.php
echo -e "<html><title>Azure Nginx PHP</title><body><h2>Your Nginx and PHP are installed!</h1></br>\n<?php\nphpinfo();\n?></body>" > /usr/share/nginx/html/index.php
#
# Services restart
#
service php5-fpm restart
service nginx restart
