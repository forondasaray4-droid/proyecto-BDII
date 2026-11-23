-- =====================================================================
-- 08_indices.sql  -  Índices del proyecto (con su justificación)
-- La medición EXPLAIN / ANALYZE antes y después está en
-- sql/optimizacion_medicion.sql y la tabla comparativa en el README.
-- Repetible: usa IF NOT EXISTS / IF EXISTS.
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

-- 1. (id_medico, fecha, hora): agenda de un médico por rango de fechas y ordenada;
--    reporte por centro (JOIN medico-cita con rango de fecha); y las búsquedas de
--    disponibilidad de fn_medico_disponible y trg_validar_cita (igualdad en
--    id_medico, fecha y hora). Igualdad primero, luego el rango/orden.
CREATE INDEX IF NOT EXISTS idx_cita_medico_fecha_hora ON cita (id_medico, fecha, hora);

-- 2. (id_paciente, fecha): historial de citas de un paciente, más recientes primero.
--    Igualdad en id_paciente y orden por fecha: el índice entrega las filas ya ordenadas.
CREATE INDEX IF NOT EXISTS idx_cita_paciente_fecha ON cita (id_paciente, fecha);

-- 3. (fecha, id_estado): reportes por mes/rango de fechas y conteos por estado.
--    Es un índice cubriente para COUNT ... GROUP BY id_estado (Using index).
CREATE INDEX IF NOT EXISTS idx_cita_fecha_estado ON cita (fecha, id_estado);

-- 4. (estado, fecha_envio): recordatorios pendientes cuya fecha de envío llegó
--    (los usa sp_enviar_recordatorios, ejecutado por ev_enviar_recordatorios).
CREATE INDEX IF NOT EXISTS idx_recordatorio_estado_envio ON recordatorio (estado, fecha_envio);

-- 5. (apellido, nombre): búsqueda de pacientes por apellido (LIKE 'Gar%').
CREATE INDEX IF NOT EXISTS idx_paciente_apellido_nombre ON paciente (apellido, nombre);

-- Índices redundantes: los de una sola columna creados automáticamente por las
-- llaves foráneas son prefijo de los compuestos anteriores. InnoDB usa el
-- compuesto para validar la llave foránea, así que se eliminan (menos costo en escritura).
DROP INDEX IF EXISTS fk_cita_medico   ON cita;
DROP INDEX IF EXISTS fk_cita_paciente ON cita;

ANALYZE TABLE cita, recordatorio, paciente;
SHOW INDEX FROM cita;
