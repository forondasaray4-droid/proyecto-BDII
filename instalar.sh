#!/bin/bash
# =====================================================================
# instalar.sh - Construye TODA la base de datos proyecto_citas desde cero
# Ejecuta en orden los scripts sql/01_*.sql ... sql/09_*.sql dentro del
# contenedor de MariaDB. (sql/10_pruebas.sql se ejecuta aparte: ./instalar.sh --pruebas)
#
# Uso (desde la raíz del repositorio, con el contenedor ya levantado):
#   cp scripts/respaldo.env.ejemplo scripts/.respaldo.env   # y editar valores
#   docker compose --env-file scripts/.respaldo.env up -d --build
#   ./instalar.sh
# ATENCIÓN: 01_esquema.sql borra y recrea la base proyecto_citas.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

CONTENEDOR="${CONTENEDOR:-citas_mariadb}"
ARCHIVO_ENV="scripts/.respaldo.env"

if [ ! -f "$ARCHIVO_ENV" ]; then
  echo "ERROR: falta $ARCHIVO_ENV (copie scripts/respaldo.env.ejemplo y complete los valores)" >&2
  exit 1
fi
source "$ARCHIVO_ENV"

: "${DB_PASS:?Falta DB_PASS en $ARCHIVO_ENV}"
: "${PASS_LECTOR:?Falta PASS_LECTOR}" "${PASS_RECEPCION:?Falta PASS_RECEPCION}" "${PASS_GESTOR:?Falta PASS_GESTOR}"
: "${LLAVE_AES:?Falta LLAVE_AES}" "${PIN_DEMO:?Falta PIN_DEMO}"

# Las variables de sesión que usan los scripts (se antepone este encabezado a cada
# archivo; así las contraseñas y la llave no quedan escritas en el repositorio).
ENCABEZADO="SET @llave_aes='${LLAVE_AES}'; SET @pin_demo='${PIN_DEMO}'; \
SET @pass_lector='${PASS_LECTOR}'; SET @pass_recepcion='${PASS_RECEPCION}'; SET @pass_gestor='${PASS_GESTOR}';"

ejecutar() {  # lee SQL por la entrada estándar (acepta opciones extra de mariadb)
  docker exec -i -e MYSQL_PWD="$DB_PASS" "$CONTENEDOR" \
    mariadb -u root --default-character-set=utf8mb4 "$@"
}

echo ">> Esperando a MariaDB en el contenedor $CONTENEDOR ..."
for i in $(seq 1 30); do
  if docker exec -e MYSQL_PWD="$DB_PASS" "$CONTENEDOR" mariadb-admin -u root ping --silent 2>/dev/null; then
    break
  fi
  [ "$i" -eq 30 ] && { echo "ERROR: MariaDB no responde" >&2; exit 1; }
  sleep 2
done

echo ">> Activando la politica de contrasenas (simple_password_check)"
echo "INSTALL SONAME 'simple_password_check';" | ejecutar 2>/dev/null || true

if [ "${1:-}" = "--pruebas" ]; then
  echo ">> Ejecutando sql/10_pruebas.sql (casos de prueba)"
  { echo "$ENCABEZADO"; cat sql/10_pruebas.sql; } | ejecutar --force
  exit 0
fi

for archivo in sql/0*.sql; do
  echo ">> Ejecutando $archivo ..."
  { echo "$ENCABEZADO"; cat "$archivo"; } | ejecutar > /dev/null
done

echo ">> Resumen de la instalacion:"
docker exec -e MYSQL_PWD="$DB_PASS" "$CONTENEDOR" mariadb -u root proyecto_citas -e "
SELECT (SELECT COUNT(*) FROM information_schema.TABLES   WHERE TABLE_SCHEMA='proyecto_citas' AND TABLE_TYPE='BASE TABLE') AS tablas,
       (SELECT COUNT(*) FROM information_schema.VIEWS    WHERE TABLE_SCHEMA='proyecto_citas') AS vistas,
       (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='proyecto_citas' AND ROUTINE_TYPE='PROCEDURE') AS procedimientos,
       (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='proyecto_citas' AND ROUTINE_TYPE='FUNCTION')  AS funciones,
       (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='proyecto_citas') AS triggers,
       (SELECT COUNT(*) FROM information_schema.EVENTS   WHERE EVENT_SCHEMA='proyecto_citas')   AS eventos,
       (SELECT COUNT(*) FROM cita) AS citas;"
echo "Instalacion completada"
