FROM alpine:latest
LABEL Maintainer="Vladislav Mostovoi <vladkimo@gmail.com>" \
      Description="Docker image for Open Web Analytics with Nginx & PHP-FPM 5.x based on Alpine Linux."

ARG OWA_VERSION

ENV OWA_UID="82" \
    OWA_USER="www-data" \
    OWA_GID="82" \
    OWA_GROUP="www-data" \
    WEBROOT_DIR=/var/www/html \
    OWA_DB_TYPE = "mysql"

# Add OWA configuration
ADD config /tmp/owa-config

# Add application user and group
RUN set -ex \
	&& addgroup -g $OWA_UID -S $OWA_GROUP \
	&& adduser -u $OWA_GID -D -S -G $OWA_USER $OWA_GROUP \
# Install packages
    && apk update \
    && apk upgrade \
    && apk add --update tzdata \
    && apk --no-cache add \
    php5-fpm \    
    php5-mysql \
    php5-mysqli \
    php5-pcntl \
    php5-json \
    php5-openssl \
    php5-curl \
    php5-zlib \
    php5-xml \
    php5-phar \
    php5-intl \
    php5-dom \
    php5-xmlreader \
    php5-ctype \
    php5-gd \
    nginx supervisor curl jq \
# Setup OWA configuration
    && cp /tmp/owa-config/nginx.conf /etc/nginx/nginx.conf \
    && cp /tmp/owa-config/owa-www.conf /etc/php5/fpm.d/ \
    && cp /tmp/owa-config/owa.ini /etc/php5/conf.d/ \
    && mkdir -p /etc/supervisor/conf.d \
    && cp /tmp/owa-config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf \
    && cp /tmp/owa-config/entrypoint.sh /usr/bin/owa-entrypoint.sh \
    && chmod 0775 /usr/bin/owa-entrypoint.sh \
# Setup php-fpm unix user/group
    && sed -i "s|user\s*=.*|user = ${OWA_USER}|g" /etc/php5/php-fpm.conf \
    && sed -i "s|group\s*=.*|group = ${OWA_GROUP}|g" /etc/php5/php-fpm.conf \
# Add Open Web Analytics (OWA)
    && mkdir -p $WEBROOT_DIR \
    && if [ "x$OWA_VERSION" = "x" ] | [ "$OWA_VERSION" = "latest" ] ; then \
    OWA_VERSION=$(curl -L -s -H 'Accept: application/json' https://api.github.com/repos/padams/Open-Web-Analytics/releases/latest| jq '.tag_name'| tr -d \") ; \
    fi \
    && echo "Install Open Web Analytics (OWA) version $OWA_VERSION" \
    && curl -fsSL -o /tmp/owa.tar.gz "https://github.com/padams/Open-Web-Analytics/archive/$OWA_VERSION.tar.gz" \
    && tar -xzf /tmp/owa.tar.gz -C /tmp \
    && mv /tmp/Open-Web-Analytics-$OWA_VERSION/* $WEBROOT_DIR \
    && chown -R $OWA_USER:$OWA_GROUP $WEBROOT_DIR/ \
    && chmod -R 0775 $WEBROOT_DIR/ \
    && apk del jq \
    && rm -rf /var/cache/apk/* /tmp/owa.tar.gz /tmp/owa-config \
    && sed -i "s|'OWA_DB_TYPE',\s*.*|'OWA_DB_TYPE', '${OWA_DB_TYPE}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_DB_NAME',\s*.*|'OWA_DB_NAME', '${OWA_DB_NAME}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_DB_HOST',\s*.*|'OWA_DB_HOST', '${OWA_DB_HOST}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_DB_USER',\s*.*|'OWA_DB_USER', '${OWA_DB_USER}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_DB_PASSWORD',\s*.*|'OWA_DB_PASSWORD', '${OWA_DB_PASSWORD}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_PUBLIC_URL',\s*.*|'OWA_PUBLIC_URL', '${OWA_PUBLIC_URL}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_NONCE_KEY',\s*.*|'OWA_NONCE_KEY', '${OWA_NONCE_SALT}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_NONCE_SALT',\s*.*|'OWA_NONCE_SALT', '${OWA_NONCE_SALT}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_AUTH_KEY',\s*.*|'OWA_AUTH_KEY', '${OWA_AUTH_KEY}');|g" /var/www/html/owa-config-dist.php \
    && sed -i "s|'OWA_AUTH_SALT',\s*.*|'OWA_AUTH_SALT', '${OWA_AUTH_SALT}');|g" /var/www/html/owa-config-dist.php \
    && mv -f /var/www/html/owa-config-dist.php /var/www/html/owa-config.php

WORKDIR $WEBROOT_DIR
EXPOSE 80 443
ENTRYPOINT ["/usr/bin/owa-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
