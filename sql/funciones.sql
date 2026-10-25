-- =========================================================
-- Archivo: funciones.sql
-- Funciones almacenadas del proyecto de citas
-- =========================================================
SET NAMES utf8mb4;
USE proyecto_citas;

DROP FUNCTION IF EXISTS fn_clasificar_edad;
DROP FUNCTION IF EXISTS fn_contar_citas_paciente;
DROP FUNCTION IF EXISTS fn_medico_disponible;

DELIMITER $$

-- 1. Clasifica una edad: Niño, Adolescente, Adulto, Adulto mayor (NULL si es inválida)
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

-- 2. Cuenta las citas de un paciente a partir de su documento (0 si no existe)
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

-- 3. Devuelve 1 si el médico atiende a esa hora y no tiene otra cita activa; 0 si no
CREATE FUNCTION fn_medico_disponible(p_id_medico INT, p_fecha DATE, p_hora TIME)
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE v_inicio TIME;
  DECLARE v_fin TIME;
  DECLARE v_ocupado INT;

  SELECT horario_inicio, horario_fin INTO v_inicio, v_fin
  FROM medico WHERE id_medico = p_id_medico;

  IF v_inicio IS NULL OR p_hora < v_inicio OR p_hora >= v_fin THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*) INTO v_ocupado
  FROM cita
  WHERE id_medico = p_id_medico
    AND fecha = p_fecha
    AND hora = p_hora
    AND estado <> 'Cancelada';

  RETURN IF(v_ocupado = 0, 1, 0);
END$$

DELIMITER ;
