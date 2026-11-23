#!/bin/bash
# =====================================================================
# respaldar.sh - Respaldo automático de proyecto_citas (lógico, comprimido)
#   1. Base de datos completa: estructura, datos, rutinas, triggers y eventos
#   2. Usuarios, roles y privilegios (--system=users) en un archivo aparte (chmod 600)
#   3. Verifica que cada respaldo terminó ("Dump completed"), copia a una segunda
#      ubicación si DIR_COPIA está definido (regla 3-2-1) y aplica retención de 7 días
#   4. Registra cada ejecución en respaldos/respaldos.log
# Uso manual:  ./scripts/respaldar.sh
# Con cron:    ver sección "Respaldo y recuperación" del README
# =====================================================================
set -euo pipefail

# cron ejecuta con un PATH mínimo: se define explícitamente
export PATH="/usr/local/bin:/usr/bin:/bin"

DIR_SCRIPT="$(cd "$(dirname "$0")" && pwd)"
DIR_RESPALDOS="${DIR_RESPALDOS:-$DIR_SCRIPT/../respaldos}"
CONTENEDOR="${CONTENEDOR:-citas_mariadb}"
BASE_DATOS="proyecto_citas"
DIAS_RETENCION=7

# Las contraseñas NO se escriben en el script: se leen de un archivo protegido
source "$DIR_SCRIPT/.respaldo.env"
: "${DB_PASS:?Falta DB_PASS en scripts/.respaldo.env}"
DIR_COPIA="${DIR_COPIA:-}"

FECHA=$(date +%Y%m%d_%H%M%S)
ARCHIVO="$DIR_RESPALDOS/${BASE_DATOS}_${FECHA}.sql.gz"
ARCHIVO_USUARIOS="$DIR_RESPALDOS/usuarios_${FECHA}.sql.gz"
LOG="$DIR_RESPALDOS/respaldos.log"
INICIO=$SECONDS

mkdir -p "$DIR_RESPALDOS"
registrar() { echo "$(date '+%F %T') $1" >> "$LOG"; }

# 1. Respaldo completo de la base (si falla, se registra el error y se borra el archivo)
if ! docker exec -e MYSQL_PWD="$DB_PASS" "$CONTENEDOR" \
       mariadb-dump -u root --single-transaction --routines --triggers --events \
       --databases "$BASE_DATOS" | gzip > "$ARCHIVO"; then
  registrar "ERROR: fallo mariadb-dump de $BASE_DATOS"
  rm -f "$ARCHIVO"
  exit 1
fi

# 2. Verificar que el archivo no esté vacío y que el dump terminó completo
if [ ! -s "$ARCHIVO" ] || ! gunzip -c "$ARCHIVO" | tail -n 1 | grep -q "Dump completed"; then
  registrar "ERROR: respaldo incompleto $ARCHIVO"
  rm -f "$ARCHIVO"
  exit 1
fi

# 3. Respaldo de usuarios, roles y privilegios (contiene hashes: se protege como una clave)
if ! docker exec -e MYSQL_PWD="$DB_PASS" "$CONTENEDOR" \
       mariadb-dump -u root --system=users | gzip > "$ARCHIVO_USUARIOS"; then
  registrar "ERROR: fallo el respaldo de usuarios"
  rm -f "$ARCHIVO_USUARIOS"
  exit 1
fi
if [ ! -s "$ARCHIVO_USUARIOS" ] || ! gunzip -c "$ARCHIVO_USUARIOS" | tail -n 1 | grep -q "Dump completed"; then
  registrar "ERROR: respaldo de usuarios incompleto $ARCHIVO_USUARIOS"
  rm -f "$ARCHIVO_USUARIOS"
  exit 1
fi
chmod 600 "$ARCHIVO" "$ARCHIVO_USUARIOS"

# 4. Segunda ubicación (regla 3-2-1), si se configuró
if [ -n "$DIR_COPIA" ] && [ -d "$DIR_COPIA" ]; then
  cp -p "$ARCHIVO" "$ARCHIVO_USUARIOS" "$DIR_COPIA/"
  registrar "COPIA: respaldos copiados a $DIR_COPIA"
fi

# 5. Retención: eliminar respaldos con más días que DIAS_RETENCION
find "$DIR_RESPALDOS" \( -name "${BASE_DATOS}_*.sql.gz" -o -name "usuarios_*.sql.gz" \) \
     -mtime +"$DIAS_RETENCION" -delete

# 6. Registrar el resultado
TAMANO=$(du -h "$ARCHIVO" | cut -f1)
registrar "OK: $(basename "$ARCHIVO") ($TAMANO) + $(basename "$ARCHIVO_USUARIOS") en $((SECONDS - INICIO)) s"
echo "Respaldo generado: $ARCHIVO ($TAMANO)"
echo "Usuarios y roles:  $ARCHIVO_USUARIOS"
