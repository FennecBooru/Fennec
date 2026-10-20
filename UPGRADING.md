## Postgres

### Backup Old Data
```shell
docker volume create fennec_pg15.7
docker run --rm -v fennec_db_data:/old -v fennec_pg15.7:/new busybox sh -c "cp -r /old/* /new/"
```

### Dump Old Data
```shell
docker run --rm -v fennec_db_data:/var/lib/postgresql/data -e POSTGRES_USER=fennec -e POSTGRES_DB=fennec_development -e POSTGRES_HOST_AUTH_METHOD=trust -d --name fennec_pg15.7 postgres:15.7-alpine3.20
docker exec fennec_pg15.7 pg_dumpall -U fennec > ./pg15.7_dump.sql
docker rm -f fennec_pg15.7
```

### Import Old Data
```shell
docker volume create fennec_pg17.5
docker run --rm -v fennec_pg17.5:/var/lib/postgresql/data -e POSTGRES_USER=fennec -e POSTGRES_DB=fennec_development -e POSTGRES_HOST_AUTH_METHOD=trust -d --name fennec_pg17.5 postgres:17.5-alpine3.20
cat pg15.7_dump.sql | docker exec -i fennec_pg17.5 psql -U fennec -d postgres
docker rm -f fennec_pg17.5
```

### Replace Old Data
```shell
docker run --rm -v fennec_db_data:/old busybox sh -c "rm -rf /old/*"
docker run --rm -v fennec_pg17.5:/old -v fennec_db_data:/new busybox sh -c "cp -r /old/* /new/"
```

### Remove Intermediate Volume
```shell
docker volume rm fennec_pg17.5
```

### Remove Backup Data
```shell
docker volume rm fennec_pg15.7
```
