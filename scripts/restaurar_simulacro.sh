#!/bin/bash
# =====================================================================
# restaurar_simulacro.sh - Simulacro de recuperación SIN tocar la base real
#   1. Genera un respaldo fresco (respaldar.sh)
#   2. Lo restaura en una base NUEVA: proyecto_citas_restaurada
#   3. Verifica que es idéntica: mismo número de tablas, vistas, rutinas,
#      triggers y eventos, y mismo CHECKSUM TABLE en cada tabla
#   4. Simula el desastre (DROP DATABASE de la copia), la recupera de nuevo
#      y vuelve a verificar, midiendo el tiempo (RTO real)
#   5. Elimina la copia (para que sus eventos no sigan activos)
# Uso: ./scripts/restaurar_simulacro.sh
# Para restaurar de verdad la base original, ver README (Respaldo y recuperación).
# =====================================================================
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

DIR_SCRIPT="$(cd "$(dirname "$0")" && pwd)"
DIR_RESPALDOS="${DIR_RESPALDOS:-$DIR_SCRIPT/../respaldos}"
CONTENEDOR="${CONTENEDOR:-citas_mariadb}"
ORIGINAL="proyecto_citas"
COPIA="proyecto_citas_restaurada"
source "$DIR_SCRIPT/.respaldo.env"
: "${DB_PASS:?Falta DB_PASS}"

sql() { docker exec -i -e MYSQL_PWD="$DB_PASS" "$CONTENEDOR" mariadb -u root "$@"; }

echo "== 1. Respaldo fresco =="
"$DIR_SCRIPT/respaldar.sh"
ARCHIVO=$(ls -1t "$DIR_RESPALDOS"/${ORIGINAL}_*.sql.gz | head -n 1)
echo "Se usara: $ARCHIVO"

restaurar() {
  sql -e "DROP DATABASE IF EXISTS $COPIA"
  # El respaldo trae CREATE DATABASE/USE de la base original: se redirigen a la copia
  gunzip -c "$ARCHIVO" \
    | sed -e "s/^CREATE DATABASE \(.*\)\`$ORIGINAL\`/CREATE DATABASE \1\`$COPIA\`/" \
          -e "s/^USE \`$ORIGINAL\`;/USE \`$COPIA\`;/" \
    | sql --default-character-set=utf8mb4
}

conteos() {  # $1 = base; imprime: tablas vistas rutinas triggers eventos
  sql -N -e "SELECT
    (SELECT COUNT(*) FROM information_schema.TABLES   WHERE TABLE_SCHEMA='$1' AND TABLE_TYPE='BASE TABLE'),
    (SELECT COUNT(*) FROM information_schema.VIEWS    WHERE TABLE_SCHEMA='$1'),
    (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='$1'),
    (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='$1'),
    (SELECT COUNT(*) FROM information_schema.EVENTS   WHERE EVENT_SCHEMA='$1')"
}

verificar() {
  local fallos=0
  echo "-- Objetos (tablas vistas rutinas triggers eventos)"
  local a b
  a=$(conteos "$ORIGINAL"); b=$(conteos "$COPIA")
  echo "   original: $a"; echo "   copia:    $b"
  [ "$a" = "$b" ] || { echo "   DIFERENTE"; fallos=1; }

  echo "-- CHECKSUM TABLE por tabla"
  local t ca cb
  for t in $(sql -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$ORIGINAL' AND TABLE_TYPE='BASE TABLE' ORDER BY 1"); do
    ca=$(sql -N -e "CHECKSUM TABLE $ORIGINAL.$t" | awk '{print $2}')
    cb=$(sql -N -e "CHECKSUM TABLE $COPIA.$t"    | awk '{print $2}')
    if [ "$ca" = "$cb" ]; then printf "   %-20s %-12s IGUAL\n" "$t" "$ca"
    else printf "   %-20s %s <> %s DIFERENTE\n" "$t" "$ca" "$cb"; fallos=1; fi
  done
  return $fallos
}

echo "== 2. Restauracion en $COPIA =="
INICIO=$SECONDS
restaurar
echo "Restaurada en $((SECONDS - INICIO)) s"

echo "== 3. Verificacion =="
verificar

echo "== 4. Desastre: se elimina la copia y se recupera desde el respaldo =="
sql -e "DROP DATABASE $COPIA"
echo "Bases existentes ahora:"; sql -N -e "SHOW DATABASES LIKE 'proyecto%'"
INICIO=$SECONDS
restaurar
RTO=$((SECONDS - INICIO))
echo "Recuperada en $RTO s (RTO medido)"
verificar

echo "== 5. Limpieza =="
sql -e "DROP DATABASE $COPIA"
echo "Simulacro OK: la copia restaurada fue identica a la original (RTO medido: $RTO s)"
