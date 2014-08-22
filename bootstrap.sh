## to use: idemp a && echo "a"
function idemp() {
    IDEMPDIR="$HOME/.idempotency"
    mkdir -p $IDEMPDIR
    FLAG="$IDEMPDIR/$1"
    if [ ! -f "$FLAG" ]; then
        touch "$FLAG"
        return 0
    else
        return 1
    fi
}

if [ ! -f ./firstrun ];
then
#set some default values for the mysql. user root, pw root
echo "mysql-server-5.5 mysql-server/root_password password root" | debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password root" | debconf-set-selections


export DEBIAN_FRONTEND=noninteractive
apt-get update

#standalone bc grub messed our stuff up
apt-get -o Dpkg::Options::="--force-confnew" --force-yes -fuy dist-upgrade

apt-get install -y mysql-server php5-mysql php5-curl apache2 php5-dev php5-ldap php5-gd php5 libapache2-mod-php5 php-pear memcached drush libmemcached-tools make

# accept all defaults when we try to install pecl things

printf "\n" | pecl install apc
printf "\n" | pecl install xdebug
printf "\n" | pecl install memcache
printf "\n" | pecl install memcached
# just make a file so we know its been run
touch ./firstrun
fi


#self-updating drush
if [ ! -f ./drushsetup ];
then
drush dl drush-7.x-5.x-dev -y --destination='/usr/share'
touch ./drushsetup
fi

#set up db initially

if [ ! -f ./databasesetup ];
then
    echo "CREATE USER 'drupaluser'@'localhost' IDENTIFIED BY ''" | mysql --user=root --password=root
    echo "CREATE DATABASE acquia_drupal" | mysql --user=root --password=root 
    echo "GRANT ALL ON acquia_drupal.* TO 'drupaluser'@'localhost' IDENTIFIED BY 'ebis'" | mysql --user=root --password=root
    echo "flush privileges" | mysql --user=root --password=root
# just make a file so we know this has been done
    touch ./databasesetup
# if you had a database inside of the drupal-quickstart folder you can load this sucker up here if you uncomment this line
#    mysql --user=root --password=root acquia_drupal < /vagrant/acquia_drupal.sql

fi

# symlinking our drupal directory
rm -rf /var/www
ln -fs /vagrant/public /var/www

# check to see if the configuration is there
if [ ! -h /etc/apache2/sites-available/drupal ];
then
# copy the config file
    cp /vagrant/drupal.conf /etc/apache2/sites-available/drupal

# fixing localhost error
echo "ServerName localhost" | sudo tee /etc/apache2/conf.d/fqdn
#enable apache modules
    a2enmod rewrite mem_cache php5
# disable the default site
    a2dissite 000-default
# this comman makes the symlink in sites-enabled
    a2ensite drupal
#restart apache so we gotz the new setting
    service apache2 restart
fi
