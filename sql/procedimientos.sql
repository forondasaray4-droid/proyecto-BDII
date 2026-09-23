-- =========================================================
-- Archivo: procedimientos.sql
-- Procedimientos almacenados (IN, OUT, INOUT)
-- =========================================================
USE proyecto_citas;

DROP PROCEDURE IF EXISTS sp_registrar_paciente;
DROP PROCEDURE IF EXISTS sp_agendar_cita;
DROP PROCEDURE IF EXISTS sp_cancelar_cita;
DROP PROCEDURE IF EXISTS sp_reporte_atenciones_centro;
DROP PROCEDURE IF EXISTS sp_acumular_citas_paciente;

DELIMITER $$

-- ---------------------------------------------------------
-- 1. Registrar un paciente (IN + OUT)
-- Recibe los datos del paciente y devuelve el id asignado.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_registrar_paciente(
  IN p_documento VARCHAR(15),
  IN p_nombre VARCHAR(50),
  IN p_apellido VARCHAR(50),
  IN p_fecha_nacimiento DATE,
  IN p_telefono VARCHAR(15),
  IN p_correo VARCHAR(100),
  IN p_direccion VARCHAR(150),
  OUT p_id_paciente INT
)
BEGIN
  INSERT INTO paciente (documento, nombre, apellido, fecha_nacimiento, telefono, correo, direccion)
  VALUES (p_documento, p_nombre, p_apellido, p_fecha_nacimiento, p_telefono, p_correo, p_direccion);

  SELECT id_paciente INTO p_id_paciente
  FROM paciente
  WHERE documento = p_documento;
END$$

-- ---------------------------------------------------------
-- 2. Agendar una cita (IN + OUT)
-- Crea la cita en estado 'Programada' y devuelve su id.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_agendar_cita(
  IN p_id_paciente INT,
  IN p_id_medico INT,
  IN p_fecha DATE,
  IN p_hora TIME,
  IN p_motivo VARCHAR(255),
  OUT p_id_cita INT
)
BEGIN
  INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo)
  VALUES (p_id_paciente, p_id_medico, p_fecha, p_hora, p_motivo);

  SELECT MAX(id_cita) INTO p_id_cita
  FROM cita;
END$$

-- ---------------------------------------------------------
-- 3. Cancelar una cita (IN)
-- Cambia el estado de la cita y cancela su recordatorio pendiente.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_cancelar_cita(
  IN p_id_cita INT
)
BEGIN
  UPDATE cita
  SET estado = 'Cancelada'
  WHERE id_cita = p_id_cita;

  UPDATE recordatorio
  SET estado = 'Cancelado'
  WHERE id_cita = p_id_cita AND estado = 'Pendiente';
END$$

-- ---------------------------------------------------------
-- 4. Reporte de atenciones por centro de salud (IN + OUT)
-- Lista las citas atendidas de un centro y devuelve el total.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_reporte_atenciones_centro(
  IN p_id_centro INT,
  OUT p_total_atendidas INT
)
BEGIN
  SELECT cs.nombre AS centro,
         c.fecha,
         p.nombre AS paciente, p.apellido AS apellido_paciente,
         m.nombre AS medico, m.apellido AS apellido_medico,
         e.nombre AS especialidad,
         h.diagnostico
  FROM cita c
  INNER JOIN medico m ON c.id_medico = m.id_medico
  INNER JOIN centro_salud cs ON m.id_centro = cs.id_centro
  INNER JOIN especialidad e ON m.id_especialidad = e.id_especialidad
  INNER JOIN paciente p ON c.id_paciente = p.id_paciente
  INNER JOIN historial_medico h ON h.id_cita = c.id_cita
  WHERE cs.id_centro = p_id_centro AND c.estado = 'Atendida';

  SELECT COUNT(*) INTO p_total_atendidas
  FROM cita c
  INNER JOIN medico m ON c.id_medico = m.id_medico
  WHERE m.id_centro = p_id_centro AND c.estado = 'Atendida';
END$$

-- ---------------------------------------------------------
-- 5. Acumular citas de varios pacientes (IN + INOUT)
-- Suma al total recibido las citas del paciente indicado.
-- Ejemplo de uso: total de citas de un grupo familiar.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_acumular_citas_paciente(
  IN p_id_paciente INT,
  INOUT p_total INT
)
BEGIN
  SELECT p_total + COUNT(*) INTO p_total
  FROM cita
  WHERE id_paciente = p_id_paciente;
END$$

DELIMITER ;