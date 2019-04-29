#!/bin/sh

# populates wp-config.php then starts nginx
echo "<?php" > /var/www/html/wp-config.php
printf "define( 'DB_NAME', '%s' );\n" "${DATABASE}" >> /var/www/html/wp-config.php
printf "define( 'DB_USER', '%s' );\n" "${DB_USER}" >> /var/www/html/wp-config.php
printf "define( 'DB_PASSWORD', '%s' );\n" "$(cat ${DB_PASSWORD_FILE})" >> /var/www/html/wp-config.php
printf "define( 'DB_HOST', 'db' );\n" >> /var/www/html/wp-config.php
printf "define( 'DB_CHARSET', 'utf8' );\n" >> /var/www/html/wp-config.php
printf "define( 'DB_COLLATE', '' );\n" >> /var/www/html/wp-config.php
printf "define( 'WP_DEBUG', false );\n" >> /var/www/html/wp-config.php
printf "\$table_prefix = 'wp_';\n" >> /var/www/html/wp-config.php
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/html/wp-config.php
echo "require_once( ABSPATH . 'wp-settings.php' );" >> /var/www/html/wp-config.php
chown nginx: /var/www/html/wp-content/uploads
mkdir -p /run/php
/usr/sbin/php-fpm7 -D
/wait-for db:3306 && nginx -g 'daemon off;';