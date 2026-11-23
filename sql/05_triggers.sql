-- =====================================================================
-- 05_triggers.sql  -  Triggers de validación, automatización y auditoría
--   trg_validar_cita              BEFORE INSERT ON cita      (validación)
--   trg_generar_recordatorio      AFTER  INSERT ON cita      (automatización)
--   trg_auditar_paciente_update   AFTER  UPDATE ON paciente  (auditoría)
--   trg_proteger_auditoria_upd/del BEFORE UPDATE/DELETE ON auditoria_paciente
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

DROP TRIGGER IF EXISTS trg_validar_cita;
DROP TRIGGER IF EXISTS trg_generar_recordatorio;
DROP TRIGGER IF EXISTS trg_auditar_paciente_update;
DROP TRIGGER IF EXISTS trg_proteger_auditoria_upd;
DROP TRIGGER IF EXISTS trg_proteger_auditoria_del;

DELIMITER $$

-- 1. VALIDACIÓN. Impide agendar una cita si:
--    a) el médico ya tiene otra cita activa (no cancelada) a la misma fecha y hora
--    b) la hora queda fuera de sus franjas horarias de ese día de la semana
--    Es BEFORE porque debe rechazar el registro antes de guardarlo.
CREATE TRIGGER trg_validar_cita
BEFORE INSERT ON cita
FOR EACH ROW
BEGIN
  IF (SELECT COUNT(*) FROM cita
       WHERE id_medico = NEW.id_medico
         AND fecha = NEW.fecha
         AND hora = NEW.hora
         AND id_estado <> (SELECT id_estado FROM estado_cita WHERE nombre = 'Cancelada')) > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'El medico ya tiene una cita asignada en esa fecha y hora';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM franja_horaria
                  WHERE id_medico  = NEW.id_medico
                    AND dia_semana = WEEKDAY(NEW.fecha) + 1
                    AND NEW.hora >= hora_inicio
                    AND NEW.hora <  hora_fin) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'La hora de la cita esta fuera del horario de atencion del medico';
  END IF;
END$$

-- 2. AUTOMATIZACIÓN. Al agendar una cita crea su recordatorio para enviarse un
--    día antes, a la misma hora. Es AFTER porque necesita el id de la cita.
CREATE TRIGGER trg_generar_recordatorio
AFTER INSERT ON cita
FOR EACH ROW
BEGIN
  INSERT INTO recordatorio (id_cita, mensaje, fecha_envio, estado)
  VALUES (
    NEW.id_cita,
    CONCAT('Recuerde su cita del ', NEW.fecha, ' a las ', NEW.hora),
    DATE_SUB(CONCAT(NEW.fecha, ' ', NEW.hora), INTERVAL 1 DAY),
    'Pendiente'
  );
END$$

-- 3. AUDITORÍA. Registra campo, valor anterior y nuevo, USER(), CURRENT_USER() y
--    fecha cuando cambian datos sensibles del paciente. El PIN/hash nunca se copia.
CREATE TRIGGER trg_auditar_paciente_update
AFTER UPDATE ON paciente
FOR EACH ROW
BEGIN
  IF NOT (OLD.telefono <=> NEW.telefono) THEN
    INSERT INTO auditoria_paciente (id_paciente, campo, valor_anterior, valor_nuevo, usuario_sesion, usuario_privilegios)
    VALUES (NEW.id_paciente, 'telefono', OLD.telefono, NEW.telefono, USER(), CURRENT_USER());
  END IF;

  IF NOT (OLD.correo <=> NEW.correo) THEN
    INSERT INTO auditoria_paciente (id_paciente, campo, valor_anterior, valor_nuevo, usuario_sesion, usuario_privilegios)
    VALUES (NEW.id_paciente, 'correo', OLD.correo, NEW.correo, USER(), CURRENT_USER());
  END IF;

  IF NOT (OLD.direccion <=> NEW.direccion) THEN
    INSERT INTO auditoria_paciente (id_paciente, campo, valor_anterior, valor_nuevo, usuario_sesion, usuario_privilegios)
    VALUES (NEW.id_paciente, 'direccion', OLD.direccion, NEW.direccion, USER(), CURRENT_USER());
  END IF;

  IF NOT (OLD.pin_hash <=> NEW.pin_hash) THEN
    INSERT INTO auditoria_paciente (id_paciente, campo, valor_anterior, valor_nuevo, usuario_sesion, usuario_privilegios)
    VALUES (NEW.id_paciente, 'pin', '[oculto]', '[modificado]', USER(), CURRENT_USER());
  END IF;
END$$

-- 4. PROTECCIÓN DE LA AUDITORÍA. La tabla es solo de inserción: ni siquiera una
--    cuenta con privilegios puede modificar o borrar filas (el administrador del
--    negocio, además, solo tiene SELECT; ver 07_seguridad.sql).
CREATE TRIGGER trg_proteger_auditoria_upd
BEFORE UPDATE ON auditoria_paciente
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La auditoria no se puede modificar';
END$$

CREATE TRIGGER trg_proteger_auditoria_del
BEFORE DELETE ON auditoria_paciente
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La auditoria no se puede eliminar';
END$$

DELIMITER ;
