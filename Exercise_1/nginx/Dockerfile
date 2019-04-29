FROM nginx:alpine
RUN apk add php7-fpm curl php7-mysqli
ADD https://wordpress.org/latest.tar.gz /wordpress.tar.gz
RUN tar xvzf /wordpress.tar.gz 
RUN mkdir -p /var/www
RUN mv /wordpress /var/www/html
RUN rm -rf /wordpress.tar.gz
RUN mkdir -p /var/www/html/wp-content/uploads
RUN chown nginx: /var/www/html/wp-content/uploads
COPY setup-container.sh /
COPY demo.wilkinson-rowe.name.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-www-pool.conf /etc/php7/php-fpm.d/www.conf
COPY wordpress-admin.htpasswd /etc/nginx/wordpress-admin.htpasswd
ADD https://raw.githubusercontent.com/eficode/wait-for/master/wait-for /wait-for
RUN ["chmod", "+x", "/setup-container.sh", "/wait-for"]
ENTRYPOINT ["/bin/sh", "-c", "/setup-container.sh"]