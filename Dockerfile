FROM php:7.0-apache
COPY php.ini /usr/local/etc/php/
COPY index.php /var/www/html/ 
COPY vendor/ /var/www/html/vendor/