-- =========================================================
-- Archivo: triggers.sql
-- Triggers de validación y automatización
-- =========================================================
USE proyecto_citas;

DROP TRIGGER IF EXISTS trg_validar_cita;
DROP TRIGGER IF EXISTS trg_generar_recordatorio;

-- ---------------------------------------------------------
-- 1. trg_validar_cita (BEFORE INSERT ON cita)
-- Impide agendar una cita si:
--   a) el médico ya tiene otra cita activa a la misma fecha y hora
--   b) la hora está fuera del horario de atención del médico
-- ---------------------------------------------------------
DELIMITER $$

CREATE TRIGGER trg_validar_cita
BEFORE INSERT ON cita
FOR EACH ROW
BEGIN
  -- a) Médico ocupado (no cuentan las citas canceladas)
  IF (SELECT COUNT(*) FROM cita
      WHERE id_medico = NEW.id_medico
        AND fecha = NEW.fecha
        AND hora = NEW.hora
        AND estado <> 'Cancelada') > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'El medico ya tiene una cita asignada en esa fecha y hora';
  END IF;

  -- b) Hora fuera del horario del médico
  IF NEW.hora < (SELECT horario_inicio FROM medico WHERE id_medico = NEW.id_medico)
     OR NEW.hora >= (SELECT horario_fin FROM medico WHERE id_medico = NEW.id_medico) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'La hora de la cita esta fuera del horario de atencion del medico';
  END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------
-- 2. trg_generar_recordatorio (AFTER INSERT ON cita)
-- Al agendar una cita, crea automáticamente su recordatorio
-- para enviarse un día antes, a la misma hora.
-- ---------------------------------------------------------
DELIMITER $$

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

DELIMITER ;