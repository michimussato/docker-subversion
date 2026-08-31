

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

# Dump existing Repos

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
svnrdump --username=user --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/engine.gz dump http://localhost:7878/engine
svnrdump --username=user --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/game.gz dump http://localhost:7878/game
svnrdump --username=user --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/raw.gz dump http://localhost:7878/raw
```

# Load Repo from Archive

```shell
svnrdump --username=admin --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/engine.gz load http://localhost:80/svn/azura/engine
svnrdump --username=admin --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/game.gz load http://localhost:80/svn/azura/game
svnrdump --username=admin --password=pass --file=/home/michael/git/repos/memoria-works/OpenStudioLandscapesHub/docker-compose/sites/memoriaworks/.volumes/svn/repos/azura/raw.gz load http://localhost:80/svn/azura/raw
```



### Compose

#### Up

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

#### Logs

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/docker-compose.yml \
    --project-name iaean-docker-subversion \
    logs \
    --follow
```

#### Down

```shell
docker \
    compose \
    --progress=plain \
    --file $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/docker-compose.yml \
    --project-name iaean-docker-subversion \
    down
```

# Checkout Repo

```shell
svn checkout \
    --username admin \
    --password pass \
    http://localhost:80/svn/azura/game \
    ~/svn/repos/memoriaworks/game
```