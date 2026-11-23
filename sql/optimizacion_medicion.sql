-- =====================================================================
-- optimizacion_medicion.sql  -  EXPLAIN / ANALYZE ANTES y DESPUÉS de los índices
-- Proyecto citas, tabla transaccional cita (10.000+ filas).
-- Ejecutar sentencia por sentencia (Workbench: Ctrl+Enter) o completo:
--   docker exec -i citas_mariadb mariadb -u root -p proyecto_citas < sql/optimizacion_medicion.sql
-- Anotar por cada consulta: type, key, rows (EXPLAIN) y r_total_time_ms (ANALYZE
-- FORMAT=JSON). Con ellos se llena la tabla comparativa del README.
-- Es repetible: deja la base con los índices definitivos de 08_indices.sql.
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

-- ---------------------------------------------------------------------
-- PASO 0. Volver al estado "ANTES": solo los índices de las llaves foráneas.
-- (Las llaves foráneas exigen un índice; se recrean los automáticos antes de
--  eliminar los compuestos.)
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS fk_cita_medico   ON cita (id_medico);
CREATE INDEX IF NOT EXISTS fk_cita_paciente ON cita (id_paciente);
DROP INDEX IF EXISTS idx_cita_medico_fecha_hora      ON cita;
DROP INDEX IF EXISTS idx_cita_paciente_fecha         ON cita;
DROP INDEX IF EXISTS idx_cita_fecha_estado           ON cita;
DROP INDEX IF EXISTS idx_recordatorio_estado_envio   ON recordatorio;
DROP INDEX IF EXISTS idx_paciente_apellido_nombre    ON paciente;
ANALYZE TABLE cita, recordatorio, paciente;
SHOW INDEX FROM cita;

-- ---------------------------------------------------------------------
-- PASO 1. ANTES (sin los índices nuevos)
-- ---------------------------------------------------------------------
-- Q1. Agenda de un médico en un mes (JOIN + rango de fechas + ORDER BY)
EXPLAIN SELECT c.fecha, c.hora, p.nombre, p.apellido
          FROM cita c JOIN paciente p ON p.id_paciente = c.id_paciente
         WHERE c.id_medico = 7 AND c.fecha >= '2026-03-01' AND c.fecha < '2026-04-01'
         ORDER BY c.fecha, c.hora;
ANALYZE FORMAT=JSON SELECT c.fecha, c.hora, p.nombre, p.apellido
          FROM cita c JOIN paciente p ON p.id_paciente = c.id_paciente
         WHERE c.id_medico = 7 AND c.fecha >= '2026-03-01' AND c.fecha < '2026-04-01'
         ORDER BY c.fecha, c.hora;

-- Q2. Últimas 10 citas de un paciente (JOIN + ORDER BY ... DESC + LIMIT)
EXPLAIN SELECT c.fecha, c.hora, e.nombre AS estado, c.motivo
          FROM cita c JOIN estado_cita e ON e.id_estado = c.id_estado
         WHERE c.id_paciente = 1234
         ORDER BY c.fecha DESC LIMIT 10;
ANALYZE FORMAT=JSON SELECT c.fecha, c.hora, e.nombre AS estado, c.motivo
          FROM cita c JOIN estado_cita e ON e.id_estado = c.id_estado
         WHERE c.id_paciente = 1234
         ORDER BY c.fecha DESC LIMIT 10;

-- Q3. Citas de marzo por estado (rango de fechas + GROUP BY)
EXPLAIN SELECT id_estado, COUNT(*) AS total FROM cita
         WHERE fecha >= '2026-03-01' AND fecha < '2026-04-01' GROUP BY id_estado;
ANALYZE FORMAT=JSON SELECT id_estado, COUNT(*) AS total FROM cita
         WHERE fecha >= '2026-03-01' AND fecha < '2026-04-01' GROUP BY id_estado;

-- Q4. Citas de marzo con FUNCIONES sobre la columna fecha (anula cualquier índice)
EXPLAIN SELECT COUNT(*) FROM cita WHERE YEAR(fecha) = 2026 AND MONTH(fecha) = 3;
ANALYZE FORMAT=JSON SELECT COUNT(*) FROM cita WHERE YEAR(fecha) = 2026 AND MONTH(fecha) = 3;

-- Q5. Recordatorios pendientes cuya fecha de envío llegó (lo usa sp_enviar_recordatorios)
EXPLAIN SELECT id_recordatorio, id_cita, fecha_envio FROM recordatorio
         WHERE estado = 'Pendiente' AND fecha_envio <= NOW() + INTERVAL 30 DAY
         ORDER BY fecha_envio;
ANALYZE FORMAT=JSON SELECT id_recordatorio, id_cita, fecha_envio FROM recordatorio
         WHERE estado = 'Pendiente' AND fecha_envio <= NOW() + INTERVAL 30 DAY
         ORDER BY fecha_envio;

-- Q6. Atenciones de un centro en un trimestre (JOIN de 3 tablas + rango + GROUP BY)
EXPLAIN SELECT cs.nombre, COUNT(*) AS atendidas
          FROM cita c
          JOIN medico m        ON m.id_medico = c.id_medico
          JOIN centro_salud cs ON cs.id_centro = m.id_centro
         WHERE m.id_centro = 3 AND c.id_estado = 2
           AND c.fecha >= '2026-01-01' AND c.fecha < '2026-04-01'
         GROUP BY cs.nombre;
ANALYZE FORMAT=JSON SELECT cs.nombre, COUNT(*) AS atendidas
          FROM cita c
          JOIN medico m        ON m.id_medico = c.id_medico
          JOIN centro_salud cs ON cs.id_centro = m.id_centro
         WHERE m.id_centro = 3 AND c.id_estado = 2
           AND c.fecha >= '2026-01-01' AND c.fecha < '2026-04-01'
         GROUP BY cs.nombre;

-- Q7. Pacientes por apellido (LIKE con prefijo)
EXPLAIN SELECT id_paciente, nombre, apellido FROM paciente WHERE apellido LIKE 'Gar%' ORDER BY apellido, nombre;
ANALYZE FORMAT=JSON SELECT id_paciente, nombre, apellido FROM paciente WHERE apellido LIKE 'Gar%' ORDER BY apellido, nombre;

-- ---------------------------------------------------------------------
-- PASO 2. Crear los índices (mismos de 08_indices.sql; justificación allí)
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_cita_medico_fecha_hora    ON cita (id_medico, fecha, hora);
CREATE INDEX IF NOT EXISTS idx_cita_paciente_fecha       ON cita (id_paciente, fecha);
CREATE INDEX IF NOT EXISTS idx_cita_fecha_estado         ON cita (fecha, id_estado);
CREATE INDEX IF NOT EXISTS idx_recordatorio_estado_envio ON recordatorio (estado, fecha_envio);
CREATE INDEX IF NOT EXISTS idx_paciente_apellido_nombre  ON paciente (apellido, nombre);
-- Índices redundantes (prefijo de los compuestos): se eliminan
DROP INDEX IF EXISTS fk_cita_medico   ON cita;
DROP INDEX IF EXISTS fk_cita_paciente ON cita;
ANALYZE TABLE cita, recordatorio, paciente;
SHOW INDEX FROM cita;

-- ---------------------------------------------------------------------
-- PASO 3. DESPUÉS (con índices). Mismas consultas: repetir EXPLAIN y ANALYZE.
-- ---------------------------------------------------------------------
EXPLAIN SELECT c.fecha, c.hora, p.nombre, p.apellido
          FROM cita c JOIN paciente p ON p.id_paciente = c.id_paciente
         WHERE c.id_medico = 7 AND c.fecha >= '2026-03-01' AND c.fecha < '2026-04-01'
         ORDER BY c.fecha, c.hora;
ANALYZE FORMAT=JSON SELECT c.fecha, c.hora, p.nombre, p.apellido
          FROM cita c JOIN paciente p ON p.id_paciente = c.id_paciente
         WHERE c.id_medico = 7 AND c.fecha >= '2026-03-01' AND c.fecha < '2026-04-01'
         ORDER BY c.fecha, c.hora;

EXPLAIN SELECT c.fecha, c.hora, e.nombre AS estado, c.motivo
          FROM cita c JOIN estado_cita e ON e.id_estado = c.id_estado
         WHERE c.id_paciente = 1234
         ORDER BY c.fecha DESC LIMIT 10;
ANALYZE FORMAT=JSON SELECT c.fecha, c.hora, e.nombre AS estado, c.motivo
          FROM cita c JOIN estado_cita e ON e.id_estado = c.id_estado
         WHERE c.id_paciente = 1234
         ORDER BY c.fecha DESC LIMIT 10;

EXPLAIN SELECT id_estado, COUNT(*) AS total FROM cita
         WHERE fecha >= '2026-03-01' AND fecha < '2026-04-01' GROUP BY id_estado;
ANALYZE FORMAT=JSON SELECT id_estado, COUNT(*) AS total FROM cita
         WHERE fecha >= '2026-03-01' AND fecha < '2026-04-01' GROUP BY id_estado;

-- Q4 sigue lenta aunque exista el índice: la función sobre la columna lo anula
EXPLAIN SELECT COUNT(*) FROM cita WHERE YEAR(fecha) = 2026 AND MONTH(fecha) = 3;
-- Q4 REESCRITA: la columna indexada queda sola a un lado de la comparación
EXPLAIN SELECT COUNT(*) FROM cita WHERE fecha >= '2026-03-01' AND fecha < '2026-04-01';
ANALYZE FORMAT=JSON SELECT COUNT(*) FROM cita WHERE fecha >= '2026-03-01' AND fecha < '2026-04-01';

EXPLAIN SELECT id_recordatorio, id_cita, fecha_envio FROM recordatorio
         WHERE estado = 'Pendiente' AND fecha_envio <= NOW() + INTERVAL 30 DAY
         ORDER BY fecha_envio;
ANALYZE FORMAT=JSON SELECT id_recordatorio, id_cita, fecha_envio FROM recordatorio
         WHERE estado = 'Pendiente' AND fecha_envio <= NOW() + INTERVAL 30 DAY
         ORDER BY fecha_envio;

EXPLAIN SELECT cs.nombre, COUNT(*) AS atendidas
          FROM cita c
          JOIN medico m        ON m.id_medico = c.id_medico
          JOIN centro_salud cs ON cs.id_centro = m.id_centro
         WHERE m.id_centro = 3 AND c.id_estado = 2
           AND c.fecha >= '2026-01-01' AND c.fecha < '2026-04-01'
         GROUP BY cs.nombre;
ANALYZE FORMAT=JSON SELECT cs.nombre, COUNT(*) AS atendidas
          FROM cita c
          JOIN medico m        ON m.id_medico = c.id_medico
          JOIN centro_salud cs ON cs.id_centro = m.id_centro
         WHERE m.id_centro = 3 AND c.id_estado = 2
           AND c.fecha >= '2026-01-01' AND c.fecha < '2026-04-01'
         GROUP BY cs.nombre;

EXPLAIN SELECT id_paciente, nombre, apellido FROM paciente WHERE apellido LIKE 'Gar%' ORDER BY apellido, nombre;
ANALYZE FORMAT=JSON SELECT id_paciente, nombre, apellido FROM paciente WHERE apellido LIKE 'Gar%' ORDER BY apellido, nombre;

-- ---------------------------------------------------------------------
-- PASO 4. Costo de los índices en escritura y espacio
-- ---------------------------------------------------------------------
SELECT TABLE_NAME,
       ROUND(DATA_LENGTH  / 1024 / 1024, 2) AS datos_mb,
       ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS indices_mb
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA = 'proyecto_citas' AND TABLE_NAME IN ('cita', 'recordatorio', 'paciente');
