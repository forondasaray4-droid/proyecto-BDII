-- =====================================================================
-- 03_funciones.sql  -  Funciones almacenadas
--   fn_clasificar_edad, fn_contar_citas_paciente, fn_medico_disponible,
--   fn_enmascarar, fn_validar_login_citas
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

DROP FUNCTION IF EXISTS fn_clasificar_edad;
DROP FUNCTION IF EXISTS fn_contar_citas_paciente;
DROP FUNCTION IF EXISTS fn_medico_disponible;
DROP FUNCTION IF EXISTS fn_enmascarar;
DROP FUNCTION IF EXISTS fn_validar_login_citas;

DELIMITER $$

-- 1. Clasifica una edad: Niño, Adolescente, Adulto, Adulto mayor (NULL si es inválida).
--    Se usa en la vista vw_pacientes_publico.
CREATE FUNCTION fn_clasificar_edad(p_edad INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
  DECLARE v_categoria VARCHAR(20);

  IF p_edad IS NULL OR p_edad < 0 THEN
    SET v_categoria = NULL;
  ELSEIF p_edad < 12 THEN
    SET v_categoria = 'Niño';
  ELSEIF p_edad <= 17 THEN
    SET v_categoria = 'Adolescente';
  ELSEIF p_edad <= 59 THEN
    SET v_categoria = 'Adulto';
  ELSE
    SET v_categoria = 'Adulto mayor';
  END IF;

  RETURN v_categoria;
END$$

-- 2. Cuenta las citas de un paciente a partir de su documento (0 si no existe).
CREATE FUNCTION fn_contar_citas_paciente(p_documento VARCHAR(15))
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_total INT;

  SELECT COUNT(*) INTO v_total
    FROM cita c
   INNER JOIN paciente p ON c.id_paciente = p.id_paciente
   WHERE p.documento = p_documento;

  RETURN v_total;
END$$

-- 3. Devuelve 1 si el médico atiende a esa fecha y hora (según su franja
--    horaria del día de la semana) y no tiene otra cita activa; 0 si no.
CREATE FUNCTION fn_medico_disponible(p_id_medico INT, p_fecha DATE, p_hora TIME)
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE v_en_franja INT;
  DECLARE v_ocupado   INT;

  SELECT COUNT(*) INTO v_en_franja
    FROM franja_horaria
   WHERE id_medico  = p_id_medico
     AND dia_semana = WEEKDAY(p_fecha) + 1
     AND p_hora >= hora_inicio
     AND p_hora <  hora_fin;

  IF v_en_franja = 0 THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*) INTO v_ocupado
    FROM cita c
   INNER JOIN estado_cita e ON e.id_estado = c.id_estado
   WHERE c.id_medico = p_id_medico
     AND c.fecha = p_fecha
     AND c.hora  = p_hora
     AND e.nombre <> 'Cancelada';

  RETURN IF(v_ocupado = 0, 1, 0);
END$$

-- 4. Oculta un dato dejando visibles solo los últimos caracteres
--    (enmascaramiento de datos; se usa en vw_pacientes_publico).
CREATE FUNCTION fn_enmascarar(p_texto VARCHAR(100), p_visibles INT)
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
  RETURN CONCAT(REPEAT('*', GREATEST(CHAR_LENGTH(p_texto) - p_visibles, 0)),
                RIGHT(p_texto, p_visibles));
END$$

-- 5. Valida el PIN de un paciente comparando hashes con sal (nunca el PIN en claro).
CREATE FUNCTION fn_validar_login_citas(p_documento VARCHAR(15), p_pin VARCHAR(50))
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE v_valido TINYINT DEFAULT 0;

  SELECT COUNT(*) INTO v_valido
    FROM paciente
   WHERE documento = p_documento
     AND pin_hash = SHA2(CONCAT(sal, p_pin), 256);

  RETURN v_valido;
END$$

DELIMITER ;
