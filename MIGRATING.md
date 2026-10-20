execute these commands in order:
* `docker compose build`
* `docker compose up --no-start`
* `migrate/volumes.sh`
* `migrate/database.sh`
* `docker compose run --rm fennec rake db:migrate`
* `docker compose up -d`

Environment variables were renamed from `GAYFURCITY_*` to `FENNEC_*`. The old names still work as a fallback, but should be updated.
If you keep secrets in `~/.gayfurcity`, move them to `~/.fennec`.
