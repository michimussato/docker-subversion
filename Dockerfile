FROM docker.io/alpine:3.7

MAINTAINER "michimussato@etik.com"

ENV SVN_BASE /data/svn

# Install Apache with PHP, LDAP and DAV SVN
#
RUN apk add --no-cache apache2 apache2-webdav apache2-ldap apache2-utils && \
    apk add --no-cache php7-xml php7-apache2 && \
    apk add --no-cache subversion mod_dav_svn && \
    apk add --no-cache sudo bash && \
    rm -f /etc/apache2/conf.d/info.conf \
          /etc/apache2/conf.d/languages.conf \
          /etc/apache2/conf.d/dav.conf \
          /etc/apache2/conf.d/ssl.conf \
          /etc/apache2/conf.d/userdir.conf && \
    mkdir /run/apache2

# Install WebSVN
#
ENV WEBSVN_VERSION=2.3.3
RUN apk add --no-cache git
RUN mkdir -p /var/www/html
RUN git -C /var/www/html clone --branch ${WEBSVN_VERSION} --single-branch https://github.com/websvnphp/websvn.git . && \
    chown -R apache:apache /var/www/html/cache && \
    chmod -R 0700 /var/www/html/cache

RUN mkdir -p /data/dist && \
    svn cat https://svn.apache.org/repos/asf/subversion/trunk/tools/xslt/svnindex.css > /data/dist/.svnindex.css && \
    svn cat https://svn.apache.org/repos/asf/subversion/trunk/tools/xslt/svnindex.xsl > /data/dist/.svnindex.xsl && \
    sed -i 's/\/svnindex.css/\/repos\/.svnindex.css/' /data/dist/.svnindex.xsl

RUN mkdir -p $SVN_BASE && \
    chown -R apache:apache $SVN_BASE

# Apache config
#
COPY apache.conf/httpd.conf /etc/apache2/
COPY apache.conf/conf.d/*.conf /etc/apache2/conf.d/
COPY apache.conf/icons/* /var/www/localhost/icons/

COPY apache.conf/header.html /data/dist/.header.html
COPY apache.conf/footer.html /data/dist/.footer.html
COPY apache.conf/style.css /data/dist/.style.css
COPY svn.access /data/dist/.svn.access

# WebSVN config
#
COPY websvn.conf /var/www/html/include/config.php
# COPY websvn.conf /var/www/localhost/htdocs/websvn/include/config.php

# svnserve config
#
COPY svnserve.conf /etc/subversion/

COPY docker-entrypoint.sh /entrypoint.sh

WORKDIR $SVN_BASE
VOLUME $SVN_BASE

EXPOSE 80 3690
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
