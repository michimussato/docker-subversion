![Memoria Works](https://avatars.githubusercontent.com/u/286479285?s=200)

---

<!-- TOC -->
* [Existing Repos](#existing-repos)
  * [Dump existing Repos](#dump-existing-repos)
    * [From Test Environment](#from-test-environment)
    * [From Live Server](#from-live-server)
  * [Load Repo](#load-repo)
    * [From Archive](#from-archive)
    * [From live Repo (direct transfer)](#from-live-repo-direct-transfer)
* [Compose](#compose)
  * [Up](#up)
  * [Logs](#logs)
  * [Down](#down)
* [Checkout Repo](#checkout-repo)
  * [SVN](#svn)
  * [HTTP/WebDAV](#httpwebdav)
<!-- TOC -->

---

Resources:
- https://github.com/iaean/docker-subversion.git
- https://www.youtube.com/watch?v=CfRWDbUsubA

```shell
git -C docker-compose/sites/memoriaworks/svn/test clone https://github.com/iaean/docker-subversion.git
```

```shell
# mkdir -p /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/iaean-docker-subversion
# sudo cp -r \
#     /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos \
#     /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/iaean-docker-subversion
# 
# # needs to be owned by apache:apache
# sudo chown -R 100:101 /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/iaean-docker-subversion/repos/azura
```

```shell
# mkdir -p /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/svn/static/iaean-docker-subversion
# sudo cp -r \
#     /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/svn/static/srv/svn \
#     /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/svn/static/iaean-docker-subversion
# 
# # needs to be owned by apache:apache
# sudo chown -R 100:101 /home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/svn/static/iaean-docker-subversion/svn/azura
```

# Existing Repos

## Dump existing Repos

### From Test Environment

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
svnrdump --username=user --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/engine.test.gz dump http://localhost:7878/engine
svnrdump --username=user --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/game.test.gz dump http://localhost:7878/game
svnrdump --username=user --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/raw.test.gz dump http://localhost:7878/raw
```

### From Live Server

References:
- https://app.clickup.com/t/90152125381/86ca8dewn?comment=90150248337279

> [!NOTE]
>
> SVN needs to be configured to use our non standard SSH port `41937`. 
> This can be achieved by editing `~/.subversion/config`: add a new 
> scheme to `[tunnels]` by adding `memoriaworks = ssh -p 41937`.
>
> Add `svn.memoriaworks.com` to `~/.ssh/known_hosts`:
> `ssh-keyscan -H -p 41937 -t ed25519 svn.memoriaworks.com >> ~/.ssh/known_hosts`
>
> After that, instead of protocol `svn+ssh://` we can then
> use `svn+memoriaworks://`.

> [!IMPORTANT]
>
> User needs to exist on `memoriaworks.memoriaworks.com`:
> - `/usr/local/sbin/webusers add mmussato`
> Generate SSH key pair on `localhost`:
> - `ssh-keygen -N "" -t ed25519`
> Add public key to `svnusers` on `memoriaworks.memoriaworks.com`:
> - `/usr/local/sbin/svnusers add mmussato dev "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG5Fc5JyKRrduxt/QD0A+Ud1hvOZzhCZexc+Pmnm36k4"`

```shell
svnrdump --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/engine.live.gz dump svn+memoriaworks://mmussato@svn.memoriaworks.com/azura/engine
svnrdump --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/game.live.gz dump svn+memoriaworks://mmussato@svn.memoriaworks.com/azura/game
svnrdump --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/raw.live.gz dump svn+memoriaworks://mmussato@svn.memoriaworks.com/azura/raw
```

## Load Repo

### From Archive

```shell
svnrdump --username=admin --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/engine.{test,live}.gz load http://localhost:80/svn/azura/engine
svnrdump --username=admin --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/game.{test,live}.gz load http://localhost:80/svn/azura/game
svnrdump --username=admin --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/raw.{test,live}.gz load http://localhost:80/svn/azura/raw
```

### From live Repo (direct transfer)

```shell
svnrdump dump svn+memoriaworks://mmussato@svn.memoriaworks.com/azura/engine | svnrdump --username=admin --password=pass load http://localhost:80/svn/azura/engine
svnrdump dump svn+memoriaworks://mmussato@svn.memoriaworks.com/azura/game | svnrdump --username=admin --password=pass load http://localhost:80/svn/azura/game
svnrdump dump svn+memoriaworks://mmussato@svn.memoriaworks.com/azura/raw | svnrdump --username=admin --password=pass load http://localhost:80/svn/azura/raw
```

# Compose

## Up

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

## Logs

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/docker-compose.yml \
    --project-name iaean-docker-subversion \
    logs \
    --follow
```

## Down

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/docker-compose.yml \
    --project-name iaean-docker-subversion \
    down
```

# Checkout Repo

## SVN

```shell
svn checkout \
    --username admin \
    --password pass \
    svn://localhost:3690/azura/game \
    ~/svn/repos/memoriaworks/game_svn
```

## HTTP/WebDAV

```shell
svn checkout \
    --username admin \
    --password pass \
    http://localhost:80/svn/azura/game \
    ~/svn/repos/memoriaworks/game_http
```
