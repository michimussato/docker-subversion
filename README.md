![Memoria Works](https://avatars.githubusercontent.com/u/286479285?s=200)

---

<!-- TOC -->
* [docker-subversion](#docker-subversion)
  * [Features](#features)
  * [Configuration](#configuration)
    * [Persistent storage](#persistent-storage)
    * [Repository groups](#repository-groups)
    * [Autoconfiguration via environment](#autoconfiguration-via-environment)
  * [Compose](#compose)
    * [Up](#up)
    * [Logs](#logs)
    * [Down](#down)
  * [Running](#running)
    * [Running the docker image](#running-the-docker-image)
    * [Accessing your repositories](#accessing-your-repositories)
      * [Checkout Repo](#checkout-repo)
        * [SVN](#svn)
        * [HTTP/WebDAV](#httpwebdav)
    * [Importing your repositories](#importing-your-repositories)
      * [Dump to Archive](#dump-to-archive)
        * [Using Test Server](#using-test-server)
        * [From Live Server](#from-live-server)
      * [Load from Archive](#load-from-archive)
      * [From live Repo (direct transfer)](#from-live-repo-direct-transfer)
    * [Setting local user passwords](#setting-local-user-passwords)
  * [TODO](#todo)
  * [Towards SSL/TLS and Alpine](#towards-ssltls-and-alpine)
<!-- TOC -->

---

# docker-subversion

> [!NOTE]
>
> Project forked from [iaean/docker-subversion](https://github.com/iaean/docker-subversion).
>
> Existing Docker image has not been updated in years: 
> [iaean/subversion](https://hub.docker.com/r/iaean/subversion/)

Docker container for [Subversion](http://subversion.apache.org/) 
with [WebSVN](https://websvnphp.github.io/).

## Features

- Provides coexistent access via [`svn://`](http://svnbook.red-bean.com/1.7/svn.serverconfig.svnserve.html) 
  and [`http://`]([4](http://svnbook.red-bean.com/1.7/svn.serverconfig.httpd.html))
- Ultra small [Alpine Linux](https://alpinelinux.org/) based image
- Local password authentication (`.htpasswd`)
- [Path based authorization](http://svnbook.red-bean.com/1.7/svn.serverconfig.pathbasedauthz.html)
- Complete autoconfiguration via environment
- Repository grouping via SVN parent path
- Fancy SVN DAV [repository group browsing](http://httpd.apache.org/docs/2.4/mod/mod_autoindex.html) 
  inspired by [Apaxy](https://oupala.github.io/apaxy/)

## Configuration

### Persistent storage

Repositories are stored inside *"repository groups"* or *"SVN parent paths"* 
under `/data/svn`. This directory is published. To enable persistence, 
run your docker container via:

* named volume: `-v svn_repos:/data/svn`
* bind mount: `-v /path/to/svn_repos:/data/svn`

The following two files under `/data/svn` needs special attention, too: 
`.htpasswd` and `.svn.access`. This could become important, if you want 
to back up your environment. Backup your repositories as usual, but 
keep a copy of these files when indicated, because your authentication 
and authorization configuration is stored here.

### Repository groups

Repositories are grouped and managed within so-called *"repository groups"* 
or *"SVN parent paths"*. In fact that are simple directories inside 
`/data/svn` wherein the proper repositories are residing. You can provide 
a description for these directories which is used by WebSVN.   
You specify all repositories via `SUBVERSION_REPOS`. A repository is described 
by the *SVN parent path* and the repo name separated by a slash. 
Specify several repos separated by semicolon. They are created, 
if they does not exist. The environment variable for the description is 
built by prefixing the *repository group* name with `DESCRIPTION_`. 
Spaces in group or repo name are not allowed. See the examples below.

### Autoconfiguration via environment

| Variable               | Scope        | Default      | Example                                                    |
|------------------------|--------------|--------------|------------------------------------------------------------|
| **SUBVERSION_REPOS**   | recommended  | sandbox/test | **legacy**/code;**legacy**/conf;**dev**/apps;**prod**/apps |
| DESCRIPTION_**legacy** | recommended  |              | Legacy stuff                                               |
| DESCRIPTION_**prod**   | recommended  |              | Production app code & config                               |
| DESCRIPTION_**dev**    | recommended  |              | Development app code & config                              |
| SVN_LOCAL_ADMIN_USER   | recommended  |              | admin                                                      |
| SVN_LOCAL_ADMIN_PASS   | recommended  |              | password                                                   |

## Compose

### Up

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/docker-compose.yml \
    --project-name iaean-docker-subversion \
    up \
    --build \
    --remove-orphans \
    --detach
    # `--pull always` to set pull policy to always
```

### Logs

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/docker-compose.yml \
    --project-name iaean-docker-subversion \
    logs \
    --follow
```

### Down

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/docker-compose.yml \
    --project-name iaean-docker-subversion \
    down
```

## Running

Besides `svn://`, `http://`is exposed only. To provide adequate security 
and handle your certificate bale, you are highly encouraged to run the 
`http://` part behind a SSL enabled reverse proxy and publishing `https://` only.

```apache
# All your SSL and virtual host stuff...

<Location />
  SSLRequireSSL
</Location>

ProxyPreserveHost On
RequestHeader set X-Forwarded-Proto "https"

ProxyPass / http://subversion:4711/ connectiontimeout=5 timeout=300
ProxyPassReverse / http://subversion:4711/
```

Keep in mind that your passwords are not encrypted via `svn://`.

### Running the docker image

Use docker to run the container as you normally would.

Production:

```shell
docker \
    run \
    -p 80:80 \
    -p 3690:3690 \
    --env-file env \
    --rm \
    --name subversion \
    subversion
```

Devolopment:

```shell
docker \
    run \
    -it \
    -p 80:80 \
    -p 3690:3690 \
    --env-file env \
    --rm \
    --name subversion \
    subversion \
    /bin/sh
```

```shell
docker \
    exec \
    -it \
    subversion \
    /bin/sh
```

```shell
docker \
    exec \
    -u apache \
    -it \
    subversion \
    /bin/sh
```

### Accessing your repositories

Assume your docker exposes to `localhost`:

- Browse via SVN DAV: `http://localhost:80/`
- Browse via WebSVN: `http://localhost:80/websvn/`
- SVN access via `http`:
  ```shell
  svn \
      info \
      --username=<user> \
      --password=<password> \
      http://localhost:80/svn/group/repo
  ```
- SVN access via `svn`:
  ```shell
  svn \
      info \
      --username=<user> \
      --password=<password> \
      svn://localhost:3690/group/repo
  ```

The trailing part of the URL is `group/repo`, for HTTP prefixed with `svn/`.

#### Checkout Repo

##### SVN

```shell
svn checkout \
    --username=<user> \
    --password=<password> \
    svn://localhost:3690/group/repo \
    ~/path/to/local/repo_svn
```

##### HTTP/WebDAV

```shell
svn checkout \
    --username=<user> \
    --password=<password> \
    http://localhost:80/svn/group/repo \
    ~/path/to/local/repo_http
```

### Importing your repositories

```shell
zcat \
    backup.svn.gz \
    | svnrdump [--username=admin --password=...] \
    load \
    http://localhost:80/svn/group/repo
```

Keep in mind that `pre-revprop-change` hook is enabled for any via 
`SUBVERSION_REPOS` autocreated repo to support `svnrdump`.
Because this is not the Subversion default, you want to disable 
this hook manually after importing.

#### Dump to Archive

##### Using Test Server

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-svn-server/docker-compose.yml \
    --project-name glitchedpolygons-docker-svn-server \
    up \
    --build \
    --remove-orphans
```

```shell
svnrdump \
    --username=<user> \
    --password=<password> \
    --file=./<repo>.test.gz \
    dump \
    http://localhost:7878/<repo>
```

##### From Live Server

References:
- https://app.clickup.com/t/90152125381/86ca8dewn?comment=90150248337279

> [!NOTE]
>
> SVN needs to be configured to use our non-standard SSH port. 
> This can be achieved by editing `~/.subversion/config`: add a new 
> scheme to `[tunnels]` by adding `memoriaworks = ssh -p <port>`.
>
> Add `svn.memoriaworks.com` to `~/.ssh/known_hosts`:
> `ssh-keyscan -H -p <port> -t ed25519 svn.memoriaworks.com >> ~/.ssh/known_hosts`
>
> After that, instead of protocol `svn+ssh://` we can then
> use `svn+memoriaworks://`.

> [!IMPORTANT]
>
> User needs to exist on `memoriaworks.memoriaworks.com`:
> - `/usr/local/sbin/webusers add <user>`
> Generate SSH key pair on `localhost`:
> - `ssh-keygen -N "" -t ed25519`
> Add public key to `svnusers` on `memoriaworks.memoriaworks.com`:
> - `/usr/local/sbin/svnusers add <user> <group> "ssh-ed25519 <hash>"`

```shell
svnrdump \
    --file=./<group>_<repo>.live.gz \
    dump \
    svn+memoriaworks://<user>@svn.memoriaworks.com/<group>/<repo>
```

#### Load from Archive

```shell
svnrdump \
    --username=<user> \
    --password=<password> \
    --file=./<group>_<repo>.{test,live}.gz \
    load \
    http://localhost:80/svn/<group>/<repo>
```

#### From live Repo (direct transfer)

```shell
svnrdump \
    dump \
    svn+memoriaworks://<user>@svn.memoriaworks.com/<group>/<repo> \
    | svnrdump \
    --username=<user> \
    --password=<password> \
    load \
    http://localhost:80/svn/<group>/<repo>
```

### Setting local user passwords

We are using Apache htpasswd for `httpd` local auth.

`docker exec -u apache -it subversion htpasswd -mb .htpasswd foobar password`

## TODO

- [ ] Apache publishes XML for repository indexing. This is transformed to HTML via 
  [XSLT](https://svn.apache.org/repos/asf/subversion/trunk/tools/xslt/svnindex.xsl). 
  Make the XSLT looks smooth like the group listing HTML to avoid the visual break 
  at SVN DAV browsing.
- [ ] **Bind** mount volumes under Docker for Windows should not be used actually, 
  because they are 
  [problematic](https://docs.docker.com/docker-for-windows/troubleshoot/#permissions-errors-on-data-directories-for-shared-volumes) 
  due to `chmod` and `chown`. Files are created as user `root` and this cannot be 
  changed. Just there is no workaround for this behaviour. Maybe a configurable solution 
  could be to run `httpd` and `svnserve` as `root`, if this becomes an issue.
- [ ] Add an additional WebSVN instance with 
  [MultiViews](https://websvnphp.github.io/docs/install.html#multiviews) enabled.

## Towards SSL/TLS and Alpine

Alpine Linux is linking almost all packages against [LibreSSL](http://www.libressl.org/). 
LibreSSL should be compatible to [OpenSSL](https://www.openssl.org/). 
But it ***isn't***. I fought against a bug in LibreSSL a couple of days. 
There are servers with certificates from well-known CA's and OpenSSL 
works like a charm. But LibreSSL ***doesn't***. This is because of a bug 
in LibreSSL with TLSv1.2 and elliptic curve handshaking. <b><sup id="a1">[(1)](#f1)</sup><sup id="a2">[(2)](#f2)</sup></b>

In my opinion, this is a **major drawback** for Alpine Linux, because it can **break** 
SSL/TLS security for **any package**. In our case OpenLDAP via SASL and Apache. 
Beside [nginx](https://nginx.org/) I don't know about an application that 
support feeding *Elliptic curve groups* to their TLS stack. 
The workaround for our case was a forced downgrade to AES128-SHA cipher. 
And feeding ciphers is supported by OpenLDAP. But feeding 
*Elliptic curve groups* isn't. It could have been worse.

If you run into this issue, try to use `LDAP_TLS_Ciphers` and hoping your server supports some working fallback.

[^1]: https://bugs.alpinelinux.org/issues/8199 "LibreSSL Bug"
[^2]: https://github.com/libressl-portable/openbsd/issues/79 "LibreSSL Bug"

```bash
# Uhmpf... BROKEN!!
#
echo | openssl s_client -connect sec.srv.tld:636 -tls1_2 | egrep 'Cipher|Protocol'
140182729145292:error:140040E5:SSL routines:CONNECT_CR_SRVR_HELLO:ssl handshake failure:ssl_pkt.c:585:
New, (NONE), Cipher is (NONE)
    Protocol  : TLSv1.2
    Cipher    : 0000

# Works. But negotiates to AES128-SHA only.
#
echo | openssl s_client -connect sec.srv.tld:636 -tls1_2 -groups secp256k1:secp224r1 2>/dev/null | egrep 'Cipher|Protocol'
New, TLSv1/SSLv3, Cipher is AES128-SHA
    Protocol  : TLSv1.2
    Cipher    : AES128-SHA

# Works. But needs forced cipher.
#
echo | openssl s_client -connect sec.srv.tld:636 -tls1_2 -cipher AES128-SHA 2>/dev/null | egrep 'Cipher|Protocol'
New, TLSv1/SSLv3, Cipher is AES128-SHA
    Protocol  : TLSv1.2
    Cipher    : AES128-SHA

# TLSv1.1 works fine.
#
echo | openssl s_client -connect sec.srv.tld:636 -tls1_1 2>/dev/null | egrep 'Cipher|Protocol'
New, TLSv1/SSLv3, Cipher is ECDHE-RSA-AES128-SHA
    Protocol  : TLSv1.1
    Cipher    : ECDHE-RSA-AES128-SHA
```

[16]: http://svnbook.red-bean.com/1.7/svn.ref.svnserve.html
[17]: http://svnbook.red-bean.com/1.7/svn.ref.mod_dav_svn.conf.html
[18]: http://svnbook.red-bean.com/1.7/svn.ref.mod_authz_svn.conf.html

---
<a name="f1">1)</a> https://bugs.alpinelinux.org/issues/8199 [↩](#a1)     
<a name="f2">2)</a> https://github.com/libressl-portable/openbsd/issues/79 [↩](#a2)
