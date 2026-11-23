-- =====================================================================
-- 04_procedimientos.sql  -  Procedimientos almacenados
--
-- Transaccionales (START TRANSACTION + EXIT HANDLER + ROLLBACK + log_errores
-- + RESIGNAL, con SELECT ... FOR UPDATE donde hay recurso en disputa):
--   sp_agendar_cita, sp_cancelar_cita, sp_reprogramar_cita, sp_registrar_atencion
-- Otros: sp_registrar_paciente, sp_agendar_cita_segura (DEFINER),
--   sp_reporte_atenciones_centro, sp_acumular_citas_paciente,
--   sp_marcar_citas_vencidas, sp_enviar_recordatorios (usados por los eventos)
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

DROP PROCEDURE IF EXISTS sp_registrar_paciente;
DROP PROCEDURE IF EXISTS sp_agendar_cita;
DROP PROCEDURE IF EXISTS sp_agendar_cita_segura;
DROP PROCEDURE IF EXISTS sp_cancelar_cita;
DROP PROCEDURE IF EXISTS sp_reprogramar_cita;
DROP PROCEDURE IF EXISTS sp_registrar_atencion;
DROP PROCEDURE IF EXISTS sp_reporte_atenciones_centro;
DROP PROCEDURE IF EXISTS sp_acumular_citas_paciente;
DROP PROCEDURE IF EXISTS sp_marcar_citas_vencidas;
DROP PROCEDURE IF EXISTS sp_enviar_recordatorios;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. sp_registrar_paciente (IN + OUT)
-- Errores (SIGNAL 45000): datos obligatorios vacíos, documento ya registrado,
-- fecha de nacimiento futura.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_paciente(
  IN  p_documento        VARCHAR(15),
  IN  p_nombre           VARCHAR(50),
  IN  p_apellido         VARCHAR(50),
  IN  p_fecha_nacimiento DATE,
  IN  p_telefono         VARCHAR(15),
  IN  p_correo           VARCHAR(100),
  IN  p_direccion        VARCHAR(150),
  OUT p_id_paciente      INT
)
BEGIN
  IF p_documento IS NULL OR TRIM(p_documento) = ''
     OR p_nombre IS NULL OR TRIM(p_nombre) = ''
     OR p_apellido IS NULL OR TRIM(p_apellido) = '' THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Documento, nombre y apellido son obligatorios';
  END IF;

  IF EXISTS (SELECT 1 FROM paciente WHERE documento = p_documento) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Ya existe un paciente con ese documento';
  END IF;

  IF p_fecha_nacimiento IS NULL OR p_fecha_nacimiento > CURDATE() THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'La fecha de nacimiento no es valida';
  END IF;

  INSERT INTO paciente (documento, nombre, apellido, fecha_nacimiento, telefono, correo, direccion)
  VALUES (p_documento, p_nombre, p_apellido, p_fecha_nacimiento, p_telefono, p_correo, p_direccion);

  SET p_id_paciente = LAST_INSERT_ID();
END$$

-- ---------------------------------------------------------------------
-- 2. sp_agendar_cita (TRANSACCIONAL, IN + OUT)
-- Agrupa: bloqueo de la agenda del médico (FOR UPDATE) + validaciones +
-- INSERT de la cita (el trigger trg_generar_recordatorio crea el recordatorio
-- dentro de la misma transacción).
-- Recurso en disputa: la agenda del médico. Se bloquea su fila ANTES de leer
-- las citas, de modo que dos usuarios no puedan tomar el mismo horario.
-- Errores controlados: médico/paciente inexistente, datos vacíos, fecha pasada,
-- médico no disponible (fuera de franja u ocupado), cualquier otro error SQL.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_agendar_cita(
  IN  p_id_paciente INT,
  IN  p_id_medico   INT,
  IN  p_fecha       DATE,
  IN  p_hora        TIME,
  IN  p_motivo      VARCHAR(255),
  OUT p_id_cita     INT
)
MODIFIES SQL DATA
BEGIN
  DECLARE v_medico INT DEFAULT NULL;
  DECLARE v_codigo INT DEFAULT NULL;
  DECLARE v_estado CHAR(5) DEFAULT NULL;
  DECLARE v_texto  VARCHAR(255) DEFAULT NULL;

  -- Ante CUALQUIER error: deshacer, registrar y devolver el error original
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
      v_codigo = MYSQL_ERRNO, v_estado = RETURNED_SQLSTATE, v_texto = MESSAGE_TEXT;
    ROLLBACK;
    INSERT INTO log_errores (procedimiento, codigo, estado_sql, mensaje, usuario)
    VALUES ('sp_agendar_cita', v_codigo, v_estado, v_texto, USER());
    RESIGNAL;
  END;

  SET p_id_cita = NULL;

  START TRANSACTION;

  -- Bloquea la agenda del médico: otra sesión que agende con el mismo médico espera aquí
  SELECT id_medico INTO v_medico FROM medico WHERE id_medico = p_id_medico FOR UPDATE;

  IF v_medico IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El medico no existe';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM paciente WHERE id_paciente = p_id_paciente) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El paciente no existe';
  END IF;
  IF p_fecha IS NULL OR p_hora IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha y la hora son obligatorias';
  END IF;
  IF p_fecha < CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha de la cita no puede ser pasada';
  END IF;
  IF fn_medico_disponible(p_id_medico, p_fecha, p_hora) = 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'El medico no esta disponible en esa fecha y hora (fuera de su franja o con otra cita)';
  END IF;

  INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo)
  VALUES (p_id_paciente, p_id_medico, p_fecha, p_hora, p_motivo);

  SET p_id_cita = LAST_INSERT_ID();

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 3. sp_agendar_cita_segura (SQL SECURITY DEFINER)
-- Versión para el rol de recepción: recibe el documento del paciente y delega
-- en sp_agendar_cita. El rol solo necesita EXECUTE; no tiene INSERT sobre cita.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_agendar_cita_segura(
  IN p_documento VARCHAR(15),
  IN p_id_medico INT,
  IN p_fecha     DATE,
  IN p_hora      TIME,
  IN p_motivo    VARCHAR(255)
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
  DECLARE v_id_paciente INT DEFAULT NULL;
  DECLARE v_id_cita     INT DEFAULT NULL;

  SELECT id_paciente INTO v_id_paciente FROM paciente WHERE documento = p_documento;

  IF v_id_paciente IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El paciente no existe';
  END IF;

  CALL sp_agendar_cita(v_id_paciente, p_id_medico, p_fecha, p_hora, p_motivo, v_id_cita);

  -- USER() = quien inició sesión; CURRENT_USER() = cuenta cuyos privilegios se usan (el creador)
  SELECT 'Cita agendada' AS mensaje, v_id_cita AS id_cita,
         USER() AS usuario_sesion, CURRENT_USER() AS usuario_privilegios;
END$$

-- ---------------------------------------------------------------------
-- 4. sp_cancelar_cita (TRANSACCIONAL)
-- Agrupa: bloqueo de la cita + cambio de estado a Cancelada + cancelación de su
-- recordatorio pendiente. Errores: cita inexistente o que no está Programada.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_cancelar_cita(
  IN p_id_cita INT
)
MODIFIES SQL DATA
BEGIN
  DECLARE v_estado_actual VARCHAR(20) DEFAULT NULL;
  DECLARE v_codigo INT DEFAULT NULL;
  DECLARE v_estado CHAR(5) DEFAULT NULL;
  DECLARE v_texto  VARCHAR(255) DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
      v_codigo = MYSQL_ERRNO, v_estado = RETURNED_SQLSTATE, v_texto = MESSAGE_TEXT;
    ROLLBACK;
    INSERT INTO log_errores (procedimiento, codigo, estado_sql, mensaje, usuario)
    VALUES ('sp_cancelar_cita', v_codigo, v_estado, v_texto, USER());
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT e.nombre INTO v_estado_actual
    FROM cita c
   INNER JOIN estado_cita e ON e.id_estado = c.id_estado
   WHERE c.id_cita = p_id_cita
     FOR UPDATE;

  IF v_estado_actual IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cita no existe';
  ELSEIF v_estado_actual <> 'Programada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden cancelar citas en estado Programada';
  END IF;

  UPDATE cita
     SET id_estado = (SELECT id_estado FROM estado_cita WHERE nombre = 'Cancelada')
   WHERE id_cita = p_id_cita;

  UPDATE recordatorio SET estado = 'Cancelado'
   WHERE id_cita = p_id_cita AND estado = 'Pendiente';

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 5. sp_reprogramar_cita (TRANSACCIONAL, IN + OUT)
-- Agrupa: bloqueo de la cita y del médico + cancelación de la cita anterior
-- (y de su recordatorio) + creación de la nueva cita. Si la nueva no se puede
-- crear (médico ocupado o fuera de franja, lo valida trg_validar_cita), el
-- ROLLBACK deja la cita original intacta: es la prueba de atomicidad.
-- Orden de bloqueos: primero la cita y luego el médico (siempre igual).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_reprogramar_cita(
  IN  p_id_cita        INT,
  IN  p_nueva_fecha    DATE,
  IN  p_nueva_hora     TIME,
  OUT p_id_cita_nueva  INT
)
MODIFIES SQL DATA
BEGIN
  DECLARE v_estado_actual VARCHAR(20) DEFAULT NULL;
  DECLARE v_id_paciente   INT DEFAULT NULL;
  DECLARE v_id_medico     INT DEFAULT NULL;
  DECLARE v_motivo        VARCHAR(255) DEFAULT NULL;
  DECLARE v_medico_lock   INT DEFAULT NULL;
  DECLARE v_codigo INT DEFAULT NULL;
  DECLARE v_estado CHAR(5) DEFAULT NULL;
  DECLARE v_texto  VARCHAR(255) DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
      v_codigo = MYSQL_ERRNO, v_estado = RETURNED_SQLSTATE, v_texto = MESSAGE_TEXT;
    ROLLBACK;
    INSERT INTO log_errores (procedimiento, codigo, estado_sql, mensaje, usuario)
    VALUES ('sp_reprogramar_cita', v_codigo, v_estado, v_texto, USER());
    RESIGNAL;
  END;

  SET p_id_cita_nueva = NULL;

  IF p_nueva_fecha IS NULL OR p_nueva_hora IS NULL OR p_nueva_fecha < CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La nueva fecha es obligatoria y no puede ser pasada';
  END IF;

  START TRANSACTION;

  SELECT e.nombre, c.id_paciente, c.id_medico, c.motivo
    INTO v_estado_actual, v_id_paciente, v_id_medico, v_motivo
    FROM cita c
   INNER JOIN estado_cita e ON e.id_estado = c.id_estado
   WHERE c.id_cita = p_id_cita
     FOR UPDATE;

  IF v_estado_actual IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cita no existe';
  ELSEIF v_estado_actual <> 'Programada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden reprogramar citas en estado Programada';
  END IF;

  SELECT id_medico INTO v_medico_lock FROM medico WHERE id_medico = v_id_medico FOR UPDATE;

  -- Operación 1: cancelar la cita anterior y su recordatorio
  UPDATE cita
     SET id_estado = (SELECT id_estado FROM estado_cita WHERE nombre = 'Cancelada')
   WHERE id_cita = p_id_cita;
  UPDATE recordatorio SET estado = 'Cancelado'
   WHERE id_cita = p_id_cita AND estado = 'Pendiente';

  -- Operación 2: crear la nueva cita (trg_validar_cita puede rechazarla)
  INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo)
  VALUES (v_id_paciente, v_id_medico, p_nueva_fecha, p_nueva_hora, v_motivo);

  SET p_id_cita_nueva = LAST_INSERT_ID();

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 6. sp_registrar_atencion (TRANSACCIONAL)
-- Agrupa: bloqueo de la cita + INSERT del historial (observaciones cifradas
-- con AES) + cambio de estado a Atendida. Requiere la variable de sesión
-- @llave_aes. Errores: cita inexistente o no Programada, diagnóstico vacío,
-- llave no definida.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_atencion(
  IN p_id_cita       INT,
  IN p_diagnostico   VARCHAR(255),
  IN p_tratamiento   VARCHAR(255),
  IN p_observaciones VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
  DECLARE v_estado_actual VARCHAR(20) DEFAULT NULL;
  DECLARE v_codigo INT DEFAULT NULL;
  DECLARE v_estado CHAR(5) DEFAULT NULL;
  DECLARE v_texto  VARCHAR(255) DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
      v_codigo = MYSQL_ERRNO, v_estado = RETURNED_SQLSTATE, v_texto = MESSAGE_TEXT;
    ROLLBACK;
    INSERT INTO log_errores (procedimiento, codigo, estado_sql, mensaje, usuario)
    VALUES ('sp_registrar_atencion', v_codigo, v_estado, v_texto, USER());
    RESIGNAL;
  END;

  IF @llave_aes IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Defina la variable de sesion @llave_aes para cifrar las observaciones';
  END IF;

  START TRANSACTION;

  SELECT e.nombre INTO v_estado_actual
    FROM cita c
   INNER JOIN estado_cita e ON e.id_estado = c.id_estado
   WHERE c.id_cita = p_id_cita
     FOR UPDATE;

  IF v_estado_actual IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cita no existe';
  ELSEIF v_estado_actual <> 'Programada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede atender una cita en estado Programada';
  END IF;

  IF p_diagnostico IS NULL OR TRIM(p_diagnostico) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El diagnostico es obligatorio';
  END IF;

  INSERT INTO historial_medico (id_cita, diagnostico, tratamiento, observaciones_cifrado)
  VALUES (p_id_cita, p_diagnostico, p_tratamiento, AES_ENCRYPT(p_observaciones, @llave_aes));

  UPDATE cita
     SET id_estado = (SELECT id_estado FROM estado_cita WHERE nombre = 'Atendida')
   WHERE id_cita = p_id_cita;

  COMMIT;

  SELECT 'Atencion registrada' AS mensaje, p_id_cita AS id_cita;
END$$

-- ---------------------------------------------------------------------
-- 7. sp_reporte_atenciones_centro (IN + OUT)
-- Lista las citas atendidas de un centro (JOIN de 6 tablas) y devuelve el total.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_reporte_atenciones_centro(
  IN  p_id_centro       INT,
  OUT p_total_atendidas INT
)
BEGIN
  SELECT cs.nombre AS centro,
         c.fecha,
         p.nombre AS paciente, p.apellido AS apellido_paciente,
         m.nombre AS medico,   m.apellido AS apellido_medico,
         e.nombre AS especialidad,
         h.diagnostico
    FROM cita c
   INNER JOIN estado_cita  ec ON c.id_estado = ec.id_estado
   INNER JOIN medico       m  ON c.id_medico = m.id_medico
   INNER JOIN centro_salud cs ON m.id_centro = cs.id_centro
   INNER JOIN especialidad e  ON m.id_especialidad = e.id_especialidad
   INNER JOIN paciente     p  ON c.id_paciente = p.id_paciente
   INNER JOIN historial_medico h ON h.id_cita = c.id_cita
   WHERE cs.id_centro = p_id_centro AND ec.nombre = 'Atendida'
   ORDER BY c.fecha DESC
   LIMIT 50;

  SELECT COUNT(*) INTO p_total_atendidas
    FROM cita c
   INNER JOIN estado_cita ec ON c.id_estado = ec.id_estado
   INNER JOIN medico m ON c.id_medico = m.id_medico
   WHERE m.id_centro = p_id_centro AND ec.nombre = 'Atendida';
END$$

-- ---------------------------------------------------------------------
-- 8. sp_acumular_citas_paciente (IN + INOUT)
-- Suma al total recibido las citas del paciente indicado (p. ej. un grupo familiar).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_acumular_citas_paciente(
  IN    p_id_paciente INT,
  INOUT p_total       INT
)
BEGIN
  SELECT p_total + COUNT(*) INTO p_total
    FROM cita
   WHERE id_paciente = p_id_paciente;
END$$

-- ---------------------------------------------------------------------
-- 9. sp_marcar_citas_vencidas (lo ejecuta el evento ev_marcar_citas_vencidas)
-- Las citas Programadas cuya fecha ya pasó se marcan como 'No asistio'.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_marcar_citas_vencidas()
MODIFIES SQL DATA
BEGIN
  DECLARE v_filas INT DEFAULT 0;

  UPDATE cita
     SET id_estado = (SELECT id_estado FROM estado_cita WHERE nombre = 'No asistio')
   WHERE id_estado = (SELECT id_estado FROM estado_cita WHERE nombre = 'Programada')
     AND fecha < CURDATE();
  SET v_filas = ROW_COUNT();

  INSERT INTO log_eventos (evento, detalle)
  VALUES ('ev_marcar_citas_vencidas', CONCAT('Citas marcadas como No asistio: ', v_filas));
END$$

-- ---------------------------------------------------------------------
-- 10. sp_enviar_recordatorios (lo ejecuta el evento ev_enviar_recordatorios)
-- Marca como Enviado los recordatorios Pendientes cuya fecha de envío llegó.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_enviar_recordatorios()
MODIFIES SQL DATA
BEGIN
  DECLARE v_filas INT DEFAULT 0;

  UPDATE recordatorio
     SET estado = 'Enviado'
   WHERE estado = 'Pendiente'
     AND fecha_envio <= NOW();
  SET v_filas = ROW_COUNT();

  INSERT INTO log_eventos (evento, detalle)
  VALUES ('ev_enviar_recordatorios', CONCAT('Recordatorios enviados: ', v_filas));
END$$

DELIMITER ;
