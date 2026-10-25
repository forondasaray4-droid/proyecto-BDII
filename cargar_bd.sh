#!/usr/bin/env bash
# =========================================================
# cargar_bd.sh - Crea la base proyecto_citas desde cero
# Uso (desde la raíz del repositorio):
#   ./cargar_bd.sh [contenedor] [contraseña_root]
# Por defecto: citas_mariadb y root_password (entorno de práctica)
# =========================================================
set -e

CONT="${1:-citas_mariadb}"
PASS="${2:-root_password}"

echo ">> Activando plugin de política de contraseñas (si no estaba)"
docker exec "$CONT" mariadb -uroot -p"$PASS" -e "INSTALL SONAME 'simple_password_check'" 2>/dev/null || true

for f in esquema datos_prueba procedimientos triggers funciones clase10_seguridad_citas; do
  echo ">> Ejecutando sql/$f.sql"
  docker exec -i "$CONT" mariadb -uroot -p"$PASS" --default-character-set=utf8mb4 < "sql/$f.sql" > /dev/null
done

echo ">> Listo. Resumen:"
docker exec "$CONT" mariadb -uroot -p"$PASS" proyecto_citas -e "
SELECT COUNT(*) AS tablas      FROM information_schema.TABLES   WHERE TABLE_SCHEMA='proyecto_citas' AND TABLE_TYPE='BASE TABLE';
SELECT COUNT(*) AS vistas      FROM information_schema.VIEWS    WHERE TABLE_SCHEMA='proyecto_citas';
SELECT COUNT(*) AS procedimientos FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='proyecto_citas' AND ROUTINE_TYPE='PROCEDURE';
SELECT COUNT(*) AS funciones   FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='proyecto_citas' AND ROUTINE_TYPE='FUNCTION';
SELECT COUNT(*) AS triggers    FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='proyecto_citas';"
