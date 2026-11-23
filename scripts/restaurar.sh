#!/bin/bash
# =====================================================================
# restaurar.sh - Restauración REAL de proyecto_citas y de sus usuarios/roles
# a partir de los respaldos de respaldar.sh. SOBRESCRIBE la base actual.
# Uso:  ./scripts/restaurar.sh [respaldo_bd.sql.gz] [respaldo_usuarios.sql.gz]
# Sin argumentos usa los respaldos más recientes de respaldos/.
# Nota: con simple_password_check activo, MariaDB rechaza crear usuarios con la
# contraseña ya convertida en hash (error 1290). Por eso strict_password_validation
# se desactiva SOLO durante la restauración de usuarios y se vuelve a activar.
# =====================================================================
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin"

DIR_SCRIPT="$(cd "$(dirname "$0")" && pwd)"
DIR_RESPALDOS="${DIR_RESPALDOS:-$DIR_SCRIPT/../respaldos}"
CONTENEDOR="${CONTENEDOR:-citas_mariadb}"
source "$DIR_SCRIPT/.respaldo.env"
: "${DB_PASS:?Falta DB_PASS}"

BD="${1:-$(ls -1t "$DIR_RESPALDOS"/proyecto_citas_*.sql.gz | head -n 1)}"
USUARIOS="${2:-$(ls -1t "$DIR_RESPALDOS"/usuarios_*.sql.gz 2>/dev/null | head -n 1 || true)}"
sql() { docker exec -i -e MYSQL_PWD="$DB_PASS" "$CONTENEDOR" mariadb -u root "$@"; }

echo "Se restaurara: $BD"
[ -n "$USUARIOS" ] && echo "Usuarios y roles: $USUARIOS"
echo "Esto SOBRESCRIBE la base proyecto_citas actual."
read -r -p "Escriba SI para continuar: " RESP
[ "$RESP" = "SI" ] || { echo "Cancelado"; exit 1; }

INICIO=$SECONDS
echo ">> Restaurando la base de datos ..."
gunzip -c "$BD" | sql --default-character-set=utf8mb4

if [ -n "$USUARIOS" ]; then
  echo ">> Restaurando usuarios, roles y privilegios ..."
  sql -e "SET GLOBAL strict_password_validation = OFF"
  # --force: las cuentas del sistema (root, mariadb.sys) ya existen y darian error
  gunzip -c "$USUARIOS" | sql --force > /dev/null 2>&1 || true
  sql -e "SET GLOBAL strict_password_validation = ON; FLUSH PRIVILEGES"
fi

echo ">> Verificacion:"
sql proyecto_citas -e "
SELECT (SELECT COUNT(*) FROM information_schema.TABLES   WHERE TABLE_SCHEMA='proyecto_citas' AND TABLE_TYPE='BASE TABLE') AS tablas,
       (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='proyecto_citas') AS rutinas,
       (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='proyecto_citas') AS triggers,
       (SELECT COUNT(*) FROM information_schema.EVENTS   WHERE EVENT_SCHEMA='proyecto_citas')  AS eventos,
       (SELECT COUNT(*) FROM cita) AS citas,
       (SELECT COUNT(*) FROM mysql.user WHERE user LIKE '%\_citas' AND is_role='N') AS usuarios;"
echo "Restauracion completada en $((SECONDS - INICIO)) s"
