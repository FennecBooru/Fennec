#!/usr/bin/env bash
set -euo pipefail

# Docker volume "rename" script
# Copies data from gayfurcity_* volumes into fennec_* volumes.
#
# Prerequisites: run `docker compose up --no-start` first so Compose
# has already created the destination volumes. This avoids them being
# treated as external by Compose.

VOLUMES=(
  "post_data"
  "elasticsearch_data"
  "db_data"
  "redis_data"
  "node_modules"
  "recommender_data"
  "clickhouse_data"
)

OLD_PREFIX="gayfurcity"
NEW_PREFIX="fennec"

echo "==> Starting volume migration: '${OLD_PREFIX}' -> '${NEW_PREFIX}'"
echo "    (destination volumes must already exist via 'docker compose up --no-start')"
echo ""

for VOL in "${VOLUMES[@]}"; do
  SRC="${OLD_PREFIX}_${VOL}"
  DST="${NEW_PREFIX}_${VOL}"

  echo "--- Migrating: ${SRC} -> ${DST}"

  if ! docker volume inspect "${SRC}" &>/dev/null; then
    echo "    [WARN] Source volume '${SRC}' not found, skipping."
    echo ""
    continue
  fi

  if ! docker volume inspect "${DST}" &>/dev/null; then
    echo "    [ERROR] Destination volume '${DST}' does not exist."
    echo "            Run 'docker compose up --no-start' first, then re-run this script."
    exit 1
  fi

  docker run --rm \
    -v "${SRC}:/src:ro" \
    -v "${DST}:/dst" \
    busybox \
    sh -c 'cp -a /src/. /dst/'

  echo "    [OK] Data copied to '${DST}'"
  echo ""
done

echo "==> Migration complete!"
echo ""
echo "Verify your new volumes look correct, then remove the old ones with:"
echo ""
for VOL in "${VOLUMES[@]}"; do
  echo "  docker volume rm ${OLD_PREFIX}_${VOL}"
done
echo ""
echo "Or all at once:"
printf "  docker volume rm"
for VOL in "${VOLUMES[@]}"; do
  printf " ${OLD_PREFIX}_${VOL}"
done
echo ""
