#!/bin/bash
set -e

echo Running: "$@"

function create_ssh_host_keys() {
  # Missing host keys manually
  # - https://techcolleague.com/sshd-no-hostkeys-available/
  # 2026-09-02 07:22:07,256 DEBG 'sshd' stdout output:
  # Could not load host key: /etc/ssh/ssh_host_rsa_key
  # Could not load host key: /etc/ssh/ssh_host_dsa_key
  # Could not load host key: /etc/ssh/ssh_host_ecdsa_key
  # Could not load host key: /etc/ssh/ssh_host_ed25519_key
  # sshd: no hostkeys available -- exiting.
  if [[ ! -e /etc/ssh/ssh_host_rsa_key ]]; then
    ssh-keygen -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
  fi
  if [[ ! -e /etc/ssh/ssh_host_dsa_key ]]; then
    ssh-keygen -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
  fi
  if [[ ! -e /etc/ssh/ssh_host_ecdsa_key ]]; then
    ssh-keygen -N "" -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
  fi
  if [[ ! -e /etc/ssh/ssh_host_ed25519_key ]]; then
    ssh-keygen -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
  fi
  return 0
}
create_ssh_host_keys

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

    # Linking custom hooks into each <repo>/hooks/
    # Not sure if it would be better to just
    # copy the hooks over to the target repos.
    # The links persist even if the target files
    # disappear later. Maybe SVN will complain
    # about the broken links.
    if [[ -d /data/hooks ]]
    then
      for h in /data/hooks/*
      do
        pushd ${SVN_BASE}/${DIR}/${REP}/hooks &> /dev/null || exit 1
        echo "Linking hook ${h} into ${SVN_BASE}/${DIR}/${REP}/hooks..."
        ln -s "${h}" $(basename "${h}") &> /dev/null && echo "Linked successfully." || echo "Target file exists. Link not created."
        popd &> /dev/null || exit 1
      done
    else
      echo "No /data/hooks directory mounted."
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

# Launch services using supervisord
/usr/bin/supervisord -c /etc/supervisord/supervisord.conf
