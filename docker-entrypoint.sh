#!/bin/bash
set -e

# return true if specified directory is empty
function directory_empty() {
  [ -n "$(find "${1}"/ -prune -empty)" ]
}

echo Running: "$@"

# Avoid destroying bootstrapping by simple start/stop
if [[ ! -e /.bootstrapped ]]; then

  ###
  ### Empty bind mount volume bootstrapping...
  ###

  find /data/dist -type f \
       \( -name '.*.html' -o -name '.*.css' -o -name '.*.xsl' \) \
       -exec mv -f {} /data/svn \;
  find /data/dist -type f -name '.svn.access' -exec mv -n {} /data/svn \;

  ###
  ### Repository bootstrapping...
  ###

  # default repo
  if [[ -z "${SUBVERSION_REPOS}" ]]; then
    SUBVERSION_REPOS=sandbox/test
    DESCRIPTION_sandbox='Sandbox and Testbed'
    if [[ ! `grep '\[test:/\]' /data/svn/.svn.access` ]]; then
      cat <<EOT >>/data/svn/.svn.access

[test:/]
* = rw
EOT
    fi
  fi

  declare -A repos
  OIFS=$IFS
  IFS=';' read -a TOKEN <<< "${SUBVERSION_REPOS}"
  for r in "${TOKEN[@]}"
  do
    DIR=`echo ${r} | cut -s -d/ -f1 | sed 's/\s/_/g'`
    REP=`echo ${r} | cut -s -d/ -f2 | sed 's/\s/_/g'`
    if [[ -n ${DIR} && -n ${REP} && `basename "${r}"` == "${REP}" ]]; then
      repos[${DIR}]+=" ${REP}"
      # dynamicly making variable name
      current_desc=DESCRIPTION_"${DIR}"
      current_desc=${!current_desc:-'Unlabeled repository group'}
      if [[ ! -d ${SVN_BASE}/${DIR}/${REP} ]]; then
        if [[ ! -d ${SVN_BASE}/${DIR} ]]; then
          mkdir -p ${SVN_BASE}/${DIR}
          ln -s ../.svn.access ${SVN_BASE}/${DIR}/.svn.access
          chown -R apache:apache ${SVN_BASE}/${DIR}
        fi
        svnadmin create ${SVN_BASE}/${DIR}/${REP}
        # IMPORTANT: Need to enable svnrdump load...
        #            ...remove manually after restore.
        cat <<EOT >${SVN_BASE}/${DIR}/${REP}/hooks/pre-revprop-change
#!/bin/sh
exit 0
EOT
        chmod 0755 ${SVN_BASE}/${DIR}/${REP}/hooks/pre-revprop-change
        chown -R apache:apache ${SVN_BASE}/${DIR}/${REP}
        echo "Repository ${SVN_BASE}/${DIR}/${REP} inside group '${current_desc}' created..."
      fi
    else
      echo "Skipping invalid: ${r}"
    fi
  done
  IFS=$OIFS

  for key in ${!repos[*]}; do
    # for value in ${repos[$key]}; do
    #   # getting values
    #   echo "repo[$key] = $value (${!current_desc})"
    # done

    current_desc=DESCRIPTION_${key}
    # Uncomment and use ${current_desc} instead of ${!current_desc}
    # gives another flavor in WebSVN for undefined parent directories... 
    # current_desc=${!current_desc:-'Unlabeled repository group'}

    apache_snippet="<Location \"/svn/${key}\">\n  DAV svn\n  DavMinTimeout 300\n  SVNParentPath ${SVN_BASE}/${key}\n  SVNListParentPath on\n  SVNIndexXSLT /repos/.svnindex.xsl\n  AuthzSVNAccessFile ${SVN_BASE}/${key}/.svn.access\n</Location>\n"
    sed -i -e "s#// additional paths...#\$config->parentPath('${SVN_BASE}/${key}', '${!current_desc}');\n&#g" /var/www/html/include/config.php
    sed -i -e "s#^\# additional repo groups...#${apache_snippet}&#g" /etc/apache2/conf.d/svn.conf
  done

  touch /.bootstrapped
fi

###
### Local htpasswd bootstrapping...
###

# Create .htpasswd
if [[ ! -f /data/svn/.htpasswd ]]; then
  touch /data/svn/.htpasswd
fi
# Create or update USER
if [[ -n $SVN_LOCAL_ADMIN_USER && -n $SVN_LOCAL_ADMIN_PASS ]]; then
  htpasswd -mb /data/svn/.htpasswd "${SVN_LOCAL_ADMIN_USER}" \
    "${SVN_LOCAL_ADMIN_PASS}" >/dev/null 2>&1
  sed -i -e "s/^# %%LOCAL_ADMIN%%/${SVN_LOCAL_ADMIN_USER}/" /data/svn/.svn.access
fi

find /data/svn -type f -name '.*' -exec chown apache:apache {} \;

###
### Start SVN services...
###

sudo -u apache -g apache /usr/bin/svnserve -d -r ${SVN_BASE} \
  --listen-port 3690 --config-file=/etc/subversion/svnserve.conf

###
### Start apache...
###

if [[ `basename ${1}` == "httpd" ]]; then # prod
  echo "Starting in prod mode..."
  # The tail approach...
  #
  # touch /var/log/apache2/error.log
  # touch /var/log/apache2/subversion.log
  # touch /var/log/apache2/access.log
  #
  # tail -f /var/log/apache2/error.log &
  # tail -f /var/log/apache2/subversion.log &
  # tail -f /var/log/apache2/access.log &

  # The direct approach...
  #
  ln -sf /dev/stderr /var/log/apache2/error.log
  ln -sf /dev/stdout /var/log/apache2/access.log
  ln -sf /dev/stdout /var/log/apache2/subversion.log

  exec "$@" </dev/null #>/dev/null 2>&1
else # dev
  echo "Starting in dev mode..."
  rm -f /var/log/apache2/error.log
  rm -f /var/log/apache2/access.log
  rm -f /var/log/apache2/subversion.log

  httpd -k start
fi

# fallthrough...
exec "$@"

