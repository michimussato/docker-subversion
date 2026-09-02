FROM docker.io/alpine:3.7

MAINTAINER "michimussato@etik.com"

ARG SVN_BASE
ENV SVN_BASE=${SVN_BASE}

# Install supervisord
RUN apk add --no-cache supervisor
COPY ./supervisord/supervisord.conf /etc/supervisord/

# Install OpenSSH Server
ARG SSHD_OPTS
ENV SSHD_OPTS=${SSHD_OPTS}
RUN apk add --no-cache openssh-server

# Install Apache with PHP and DAV SVN
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

RUN ln -sf /dev/stderr /var/log/apache2/error.log \
    && ln -sf /dev/stderr /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/subversion.log

# Install WebSVN
#
ENV WEBSVN_VERSION=2.3.3
RUN apk add --no-cache git
RUN mkdir -p /var/www/html
RUN git -C /var/www/html clone --branch ${WEBSVN_VERSION} --single-branch https://github.com/websvnphp/websvn.git . && \
    chown -R apache:apache /var/www/html/cache && \
    chmod -R 0700 /var/www/html/cache

# Apply patches
COPY ./websvn/patches/. /var/www/html
RUN git -C /var/www/html apply templates/calm/footer.tmpl.patch
RUN git -C /var/www/html apply templates/calm/index.tmpl.patch

RUN mkdir -p /data/dist && \
    svn cat https://svn.apache.org/repos/asf/subversion/trunk/tools/xslt/svnindex.css > /data/dist/.svnindex.css && \
    svn cat https://svn.apache.org/repos/asf/subversion/trunk/tools/xslt/svnindex.xsl > /data/dist/.svnindex.xsl && \
    sed -i 's/\/svnindex.css/\/repos\/.svnindex.css/' /data/dist/.svnindex.xsl

RUN mkdir -p $SVN_BASE && \
    chown -R apache:apache $SVN_BASE

# Apache config
#
COPY ./apache.conf/httpd.conf /etc/apache2/
COPY ./apache.conf/conf.d/*.conf /etc/apache2/conf.d/
COPY ./apache.conf/icons/* /var/www/localhost/icons/

COPY ./apache.conf/header.html /data/dist/.header.html
COPY ./apache.conf/footer.html /data/dist/.footer.html
COPY ./apache.conf/style.css /data/dist/.style.css
COPY ./svn/svn.access /data/dist/.svn.access

# WebSVN config
#
COPY ./static/var/www/html/include/config.php /var/www/html/include/config.php

# svnserve config
#
COPY ./static/etc/subversion/svnserve.conf /etc/subversion/
# SVN_SHELL
COPY ./static/usr/local/bin/svnonly /usr/local/bin/
RUN chown 0:0 /usr/local/bin/svnonly
RUN chmod 755 /usr/local/bin/svnonly
# SVN Users
# Todo
#  - [ ] This needs to be adjusted for
#        the new setup first before
#        it can be used.
#  - [ ] New usage will be something like:
#        - `docker exec -it subversion svnusers help
#        - `docker exec -it subversion svnusers add <user> <group> "<ssh_public_key>"
# COPY ./static/usr/local/bin/svnusers /usr/local/bin/
# RUN chown 0:0 /usr/local/bin/svnusers
# RUN chmod 755 /usr/local/bin/svnusers
#
# Dani's svnserve wrapper
# is no longer needed. umask
# is set via supervisord

COPY ./docker-entrypoint.sh /entrypoint.sh

WORKDIR $SVN_BASE

ENTRYPOINT ["/entrypoint.sh"]
