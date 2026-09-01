

---

```shell
git -C $(pwd)/docker-compose/sites/memoriaworks/svn/docker-subversion/websvn clone https://github.com/websvnphp/websvn.git
cd websvn
git checkout "2.3.3"
```

---

Create patch:

```shell
git diff ./templates/calm/index.tmpl > ./index.tmpl.patch
```

Apply patch:

```shell
git -C /var/www/html apply templates/calm/index.tmpl.patch
```
