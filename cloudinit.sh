#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y software-properties-common build-essential gnupg \
    libzip-dev libpq-dev libicu-dev libxml2-dev \
    libpng-dev optipng pngquant gifsicle \
    jpegoptim \
    libfreetype6-dev libedit-dev libreadline-dev \
    curl git rsync zip \
    postgresql-client-common postgresql-client
# ubuntu
apt-get install -y libjpeg-turbo8-dev
# debian
#apt-get install -y libjpeg62-turbo-dev

# Install Ondrej repos for Ubuntu20.4, PHP7.2, composer and selected extensions
echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu focal main" > /etc/apt/sources.list.d/ondrej-php.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4f4ea0aae5267a6c
apt-get update
apt-get install -y php7.2-cli php7.2-fpm php7.2-dev php-imagick php-redis locales php7.2-intl
apt-get install -y php7.2-bcmath php7.2-curl php7.2-exif php7.2-mbstring php7.2-pgsql php7.2-xml php7.2-zip php7.2-gd
apt-get install -y php7.2-imap php7.2-json

# Install Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
#composer clear-cache

# Install Node.js
curl -sL https://deb.nodesource.com/setup_12.x | bash -
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update && apt-get install -y nodejs yarn
yarn global add pm2

# Install Nginx
apt-get install -y nginx nginx-extras supervisor
#apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* ~/.composer

# Configure php-fpm
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/g' /etc/php/7.2/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 100M/g' /etc/php/7.2/fpm/php.ini
sed -i 's/;catch_workers_output = yes/catch_workers_output = yes/g' /etc/php/7.2/fpm/pool.d/www.conf
sed -i 's/;php_flag\[display_errors\] = off/php_flag\[display_errors\] = on/g' /etc/php/7.2/fpm/pool.d/www.conf
sed -i 's/;php_admin_value\[error_log\] = \/var\/log\/fpm-php.www.log/php_admin_value\[error_log\] = \/var\/log\/fpm-php\/www.log/g' /etc/php/7.2/fpm/pool.d/www.conf
sed -i 's/;php_admin_flag\[log_errors\] = on/php_admin_flag\[log_errors\] = on/g' /etc/php/7.2/fpm/pool.d/www.conf
systemctl restart php7.2-fpm

# Configure Nginx
sed -i 's/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 64;/g' /etc/nginx/nginx.conf

install -d -o www-data -g www-data /var/www/api
#install -d -o www-data -g www-data /var/www/app

mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default~orig
cat <<"EOF" >> /etc/nginx/sites-available/default
map $http_user_agent $ignore_ua {
  default                 0;
  "~Pingdom.*"            1;
  "ELB-HealthChecker/1.0" 1;
}

server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;

  client_max_body_size 100M;

  root /var/www/api/web;
  index index.html app.php;

  charset utf-8;

  location / {
    if ($ignore_ua) {
      access_log off;
      return 200;
    }
    try_files $uri $uri/ /app.php?$query_string;
  }

  location ~ \.php$ {
    fastcgi_pass unix:/run/php/php7.2-fpm.sock;
    fastcgi_index app.php;

    fastcgi_read_timeout 1200;
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_param PHP_VALUE "error_log=/var/log/nginx/theapp-api_php_errors.log";
    fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    include fastcgi_params;
  }

  location ~ ^/(app_dev|config)\.php(/|$) {
    return 404;
  }

  location /docs {
    return 404;
  }

  location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
    try_files $uri =404;
  }

  location ~ /\.(?!well-known).* {
    deny all;
  }

  location = /favicon.ico { access_log off; log_not_found off; }
  location = /robots.txt  { access_log off; log_not_found off; }

  access_log /var/log/nginx/theapp-api_access.log;
  error_log /var/log/nginx/theapp-api_error.log;
}
EOF

systemctl restart nginx

## DEPLOY/INSTALL
#Copy symfony3 project to production server.
#export APP_ENV=prod
#export SYMFONY_ENV=prod
#SYMFONY_ENV=prod composer install --no-dev --optimize-autoloader
#php bin/console doctrine:schema:validate
#cd websocket_server; pm2 start stdoutput-consumer.js; pm2 start ws-app.js; pm2 startup; pm2 save; cd -
#pm2 restart [all|stdoutput-consumer|ws-app]
#pm2 [ls|status]
#pm2 logs --lines 200
#pm2 monit

## DATABASE
#postgis.sql
#```sql
#select current_user;
#create extension postgis;
#create extension fuzzystrmatch;
#create extension postgis_tiger_geocoder;
#create extension postgis_topology;
#alter schema tiger owner to rds_superuser;
#alter schema tiger_data owner to rds_superuser;
#alter schema topology owner to rds_superuser;
#CREATE FUNCTION exec(text) returns text language plpgsql volatile AS $f$ BEGIN EXECUTE $1; RETURN $1; END; $f$;
#SELECT exec('ALTER TABLE ' || quote_ident(s.nspname) || '.' || quote_ident(s.relname) || ' OWNER TO rds_superuser;')
#  FROM (
#    SELECT nspname, relname
#    FROM pg_class c JOIN pg_namespace n ON (c.relnamespace = n.oid)
#    WHERE nspname in ('tiger','topology') AND
#    relkind IN ('r','S','v') ORDER BY relkind = 'S')
#s;
#SET search_path=public,tiger;
#```
#
#Test tiger:
#select na.address, na.streetname, na.streettypeabbrev, na.zip
#from normalize_address('1 Devonshire Place, Boston, MA 02109') as na;
#
#Test topology:
#select topology.createtopology('my_new_topo',26986,0.5);
#
#Restore the dump
#psql --single-transaction -f dump.sql -u theapp -h db.theapp.private -p 5432
