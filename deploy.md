# Deploying

How Splitkit runs on a server (an AWS EC2 instance), how to set one up, and how to ship a new
version. Checking the data and restoring backups are in [validation.md](validation.md).

## How it fits together

- Images are built on a developer machine and pushed to Docker Hub. The server only pulls: the
  Flutter web build needs more disk and memory than a small instance has.
- All three images are tags in one private repo, `<user>/<repo>` (a free account has a
  single private repo, shared with another project's `web`, `backend` and `frontend` tags):
  `split-api`, `split-web` and `split-tricount` (the same image as `split-api`).
- The server runs [docker-compose.prod.yml](docker-compose.prod.yml): `db` (stock
  `postgres:16-alpine`), `api`, `tricount` and `web`. Only `web` is published. Its nginx serves
  the web app at `/` and proxies `/api/` to the API, so the API is reached through the same port
  (`http://<host>/api/v1/…`, docs at `/api/v1/docs`). Postgres and port 8000 stay inside.
- The API runs `alembic upgrade head` each time it starts, so a new image migrates the database
  on its own.
- The images are built for the CPU of the machine that pushes them (amd64). The instance must be
  x86_64 (t2, t3, t3a, m5 …), not Graviton (t4g, m6g …).

## Shipping a new version

```sh
tool/build.sh images --push <user>/<repo>   # on your machine, logged in to Docker Hub
```

It pushes each image twice: `split-<svc>` (what the server runs) and
`split-<svc>-<version>-<build>-<commit>` (to go back to). It refuses uncommitted changes in `app/`
or `api/` unless you add `--allow-dirty`, and the tag then ends in `-dirty`.
(`tool/push_images.sh` pushes only `split-<svc>`.)

Then on the server, one image at a time (the box is small and shared):

```sh
cd ~/splitkit
# A release with a migration: back up first, and copy the file off the server
docker compose exec -T db pg_dump -U splitkit -Fc splitkit > backups/splitkit-<revision>-pre-<what>-$(date +%Y%m%d-%H%M).dump
# Keep what runs now under its version, so going back needs no pull
for s in api tricount web; do docker tag <user>/<repo>:split-$s <user>/<repo>:split-$s-<running version>; done
docker compose pull api && docker compose pull tricount && docker compose up -d api tricount   # migrates
docker compose pull web && docker compose up -d web
docker compose ps                              # all four running, api "healthy"
docker compose exec api python -m app.validate
```

To roll back: if the release added a migration, undo it first, while the newer image is still
running (`docker compose exec api alembic downgrade -1`, once per migration). Otherwise the older
API won't start: its `alembic upgrade head` doesn't know the database's revision. Then tag the
kept image back (`docker tag …:split-api-<version> …:split-api`, the same for tricount and web)
and `docker compose up -d`. Or restore the backup (validation.md → Backups and restore).

Cloudflare caches the web app's files for up to 4 hours (`max-age=14400`): a hard reload in the
browser picks up a new release sooner.

## Setting up a server

### 1. The instance

- x86_64 instance type, Amazon Linux 2023. 1 GB of memory runs the stack; add swap if the API
  gets killed. The default 8 GB disk is enough, since nothing is built there.
- Security group, inbound: 80 and 443 from anywhere, 22 from your own IP. Nothing else.
- An Elastic IP, so the address survives a stop and start.

### 2. Docker and Compose

```sh
sudo dnf install -y docker
sudo systemctl enable --now docker             # enable: containers come back after a reboot
sudo usermod -aG docker ec2-user               # then log out and back in
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
  "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)"
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version
```

Buildx isn't needed: the server never builds. (Amazon Linux's buildx is too old for Compose to
build with anyway, which is how a build attempt fails there.)

### 3. Files

The server needs only two files, in `~/splitkit`:

```sh
ssh ec2-user@<host> mkdir -p splitkit
scp docker-compose.prod.yml ec2-user@<host>:splitkit/
```

and a `.env` written there (not copied from your machine):

```sh
COMPOSE_FILE=docker-compose.prod.yml           # so a plain `docker compose` uses the prod file
IMAGE=<user>/<repo>
POSTGRES_PASSWORD=<openssl rand -hex 32>       # hex: it goes into a database URL
JWT_SECRET=<openssl rand -hex 32>              # changing it later signs everyone out
WEB_PORT=80
```

Postgres takes `POSTGRES_PASSWORD` only when its volume is first created. To change it later,
also run `ALTER USER splitkit PASSWORD '…'` in the db container (see Troubleshooting).

### 4. Docker Hub login

The repo is private. Make a **read-only** personal access token on Docker Hub (Account settings
→ Personal access tokens) and use it as the password:

```sh
docker login -u <user>
```

### 5. First start

With an empty database, start everything and the API creates the schema:

```sh
cd ~/splitkit
docker compose up -d
```

To bring data over from another database instead, restore its dump **before the API first
starts** (the API's migrations would otherwise create the tables first, and the restore stops at
"already exists"). The dump must be at a migration the image has.

```sh
# where the data is now
docker compose exec -T db pg_dump -U splitkit splitkit > dump.sql
scp dump.sql ec2-user@<host>:splitkit/        # never commit it: it holds real users' data

# on the server
docker compose up -d db
docker compose exec -T db psql -U splitkit -d splitkit -v ON_ERROR_STOP=1 < dump.sql
docker compose up -d
docker compose exec api python -m app.validate
```

### 6. Passwords

The app has no way to change a password yet (ISSUES.md ISS-061), so it's done with SQL. To set
one user's password:

```sh
cd ~/splitkit
hash() { docker compose exec -T -e PW="$1" api python -c "import os; from app.core.security import hash_password; print(hash_password(os.environ['PW']))"; }
read -rs -p "New password: " NEWPW; echo
H=$(hash "$NEWPW")
docker compose exec -T db psql -U splitkit -d splitkit -c "UPDATE users SET password_hash = '$H' WHERE email = 'someone@example.com'"
```

**A database restored from a development dump has seeded accounts with the password
`dev-password`**, which this repo publishes. The seed gives them all one identical hash. With
`hash` defined as above, this locks every account still using it except the admin's, then sets
the admin's:

```sh
read -rs -p "New admin password: " NEWPW; echo
ADMIN=$(hash "$NEWPW"); LOCKED=$(hash "$(openssl rand -hex 32)")
docker compose exec -T db psql -U splitkit -d splitkit -v ON_ERROR_STOP=1 <<SQL
UPDATE users SET password_hash = '$LOCKED'
  WHERE password_hash = (SELECT password_hash FROM users WHERE email = 'admin@example.com') AND email <> 'admin@example.com';
UPDATE users SET password_hash = '$ADMIN' WHERE email = 'admin@example.com';
SQL
```

Do this before opening port 80. Anyone who finds the server can also sign up (ISS-062), and login
has no rate limit (ISS-060).

### 7. Backups

Amazon Linux has no cron until it's installed:

```sh
sudo dnf install -y cronie && sudo systemctl enable --now crond
mkdir -p ~/splitkit/backups
crontab -e
```

```
0 3 * * * cd /home/ec2-user/splitkit && docker compose exec -T db pg_dump -U splitkit -Fc splitkit > backups/splitkit-$(date +\%F).dump && find backups -name '*.dump' -mtime +14 -delete
```

That keeps two weeks on the instance's own disk, which goes if the instance does: copy them off
too (e.g. `aws s3 cp`). Restoring is in validation.md → Backups and restore; its commands work as
written on the server, since `COMPOSE_FILE` points `docker compose` at the prod file.

### 8. HTTPS (not set up yet)

The stack serves plain HTTP (ISS-059). The web app works over it, but passwords and tokens cross
the internet unencrypted, and the phone apps refuse it: Android release builds block cleartext
and iOS allows `http://` only on a local network. What's needed:

1. A domain (or a free subdomain) with an A record pointing at the Elastic IP.
2. TLS in front of `web`, e.g. a Caddy service in docker-compose.prod.yml on 80 and 443 (it gets
   a Let's Encrypt certificate by itself), with `web` no longer published.
3. Phone builds pointed at it:
   `flutter build apk --release --dart-define=API_ORIGIN=https://<domain>` (the app adds
   `/api/v1` itself, and nginx proxies it).

## Checking it

```sh
docker compose ps                              # db, api, tricount, web running; api healthy
curl -s localhost/api/v1/health                # from the server
docker compose logs -f api                     # or web, tricount, db
docker compose exec api python -m app.validate
```

## Troubleshooting

| What you see | Why | Fix |
|---|---|---|
| `compose build requires buildx 0.17 or later`, or `unable to prepare context: path ".../app" not found` | `docker compose` is reading the dev `docker-compose.yml`, which builds | Add `COMPOSE_FILE=docker-compose.prod.yml` to the server's `.env` |
| `required variable IMAGE is missing a value` | `.env` is missing a setting | Add it (the message names it) |
| `pull access denied` or `requested access to the resource is denied` | Not logged in to Docker Hub; the repo is private | `docker login -u <user>` |
| `exec format error` | The instance is arm64 (Graviton) and the images are amd64 | Use an x86_64 instance |
| `function "check_expense_split_sum" already exists` while restoring | The database isn't empty: already restored, or the API already started | Compare row counts with the dump. To redo it: `docker compose exec -T db psql -U splitkit -d splitkit -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"`, then restore again (this deletes the server's data) |
| API keeps restarting, logs say `password authentication failed for user "splitkit"` | `POSTGRES_PASSWORD` changed after the volume was created | `PW=$(grep '^POSTGRES_PASSWORD=' .env \| cut -d= -f2); docker compose exec -T db psql -U splitkit -d splitkit -c "ALTER USER splitkit PASSWORD '$PW'"`, then `docker compose up -d` |
| `502 Bad Gateway` from the web address | The API isn't up yet, or is failing | `docker compose logs api` |
