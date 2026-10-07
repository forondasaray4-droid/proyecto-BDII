-- =========================================================
-- Archivo: actividad_clase7.sql
-- Bases de Datos II - Clase 7: Procedimientos con estructuras de control
-- Proyecto: Sistema de gestión de citas - Centros de salud de Cartago
-- Nota: los ejercicios 1 a 4 no dependen de tablas; el 5 usa el esquema del proyecto.
-- =========================================================
USE proyecto_citas;

DELIMITER $$

-- ---------------------------------------------------------
-- Ejercicio 1: procedimiento sin parámetros
-- ---------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_hola_mundo$$
CREATE PROCEDURE sp_hola_mundo()
BEGIN
  SELECT '¡Hola mundo!' AS mensaje;
END$$

-- ---------------------------------------------------------
-- Ejercicio 2: clasificación de números (IF)
-- ---------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_clasificar_numero$$
CREATE PROCEDURE sp_clasificar_numero(IN p_numero DOUBLE)
BEGIN
  IF p_numero > 0 THEN
    SELECT 'El número es POSITIVO' AS mensaje;
  ELSEIF p_numero < 0 THEN
    SELECT 'El número es NEGATIVO' AS mensaje;
  ELSE
    SELECT 'El número es CERO' AS mensaje;
  END IF;
END$$

-- ---------------------------------------------------------
-- Ejercicio 3: clasificación de notas
-- Convención de rangos: [0,5) [5,6) [6,7) [7,9) [9,10]
-- 3a. Versión con IF
-- ---------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_nota_alumno$$
CREATE PROCEDURE sp_nota_alumno(IN p_nota DECIMAL(4,2))
BEGIN
  IF p_nota >= 0 AND p_nota < 5 THEN
    SELECT 'Insuficiente' AS clasificacion;
  ELSEIF p_nota >= 5 AND p_nota < 6 THEN
    SELECT 'Aprobado' AS clasificacion;
  ELSEIF p_nota >= 6 AND p_nota < 7 THEN
    SELECT 'Bien' AS clasificacion;
  ELSEIF p_nota >= 7 AND p_nota < 9 THEN
    SELECT 'Notable' AS clasificacion;
  ELSEIF p_nota >= 9 AND p_nota <= 10 THEN
    SELECT 'Sobresaliente' AS clasificacion;
  ELSE
    SELECT 'Nota no válida' AS clasificacion;
  END IF;
END$$

-- 3b. Versión con CASE
DROP PROCEDURE IF EXISTS sp_nota_alumno_case$$
CREATE PROCEDURE sp_nota_alumno_case(IN p_nota DECIMAL(4,2))
BEGIN
  CASE
    WHEN p_nota >= 0 AND p_nota < 5   THEN SELECT 'Insuficiente' AS clasificacion;
    WHEN p_nota >= 5 AND p_nota < 6   THEN SELECT 'Aprobado' AS clasificacion;
    WHEN p_nota >= 6 AND p_nota < 7   THEN SELECT 'Bien' AS clasificacion;
    WHEN p_nota >= 7 AND p_nota < 9   THEN SELECT 'Notable' AS clasificacion;
    WHEN p_nota >= 9 AND p_nota <= 10 THEN SELECT 'Sobresaliente' AS clasificacion;
    ELSE SELECT 'Nota no válida' AS clasificacion;
  END CASE;
END$$

-- ---------------------------------------------------------
-- Ejercicio 4: día de la semana (CASE simple)
-- ---------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_dia_semana$$
CREATE PROCEDURE sp_dia_semana(IN p_numero INT)
BEGIN
  DECLARE v_dia VARCHAR(30);

  CASE p_numero
    WHEN 1 THEN SET v_dia = 'Lunes';
    WHEN 2 THEN SET v_dia = 'Martes';
    WHEN 3 THEN SET v_dia = 'Miércoles';
    WHEN 4 THEN SET v_dia = 'Jueves';
    WHEN 5 THEN SET v_dia = 'Viernes';
    WHEN 6 THEN SET v_dia = 'Sábado';
    WHEN 7 THEN SET v_dia = 'Domingo';
    ELSE SET v_dia = 'Número no válido (use 1 a 7)';
  END CASE;

  SELECT v_dia AS dia;
END$$

-- ---------------------------------------------------------
-- Ejercicio 5: aplicado al proyecto (citas médicas)
-- Cuenta las citas de un paciente y devuelve un mensaje según
-- la cantidad (CASE), con una alerta por inasistencias (IF).
-- ---------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_resumen_citas_paciente$$
CREATE PROCEDURE sp_resumen_citas_paciente(
  IN  p_id_paciente INT,
  OUT p_mensaje VARCHAR(200)
)
BEGIN
  DECLARE v_existe     INT DEFAULT 0;
  DECLARE v_total      INT DEFAULT 0;
  DECLARE v_no_asistio INT DEFAULT 0;

  SELECT COUNT(*) INTO v_existe
  FROM paciente
  WHERE id_paciente = p_id_paciente;

  IF v_existe = 0 THEN
    SET p_mensaje = 'Paciente no encontrado';
  ELSE
    SELECT COUNT(*) INTO v_total
    FROM cita
    WHERE id_paciente = p_id_paciente;

    SELECT COUNT(*) INTO v_no_asistio
    FROM cita
    WHERE id_paciente = p_id_paciente AND estado = 'No asistio';

    CASE
      WHEN v_total = 0 THEN
        SET p_mensaje = 'El paciente no tiene citas registradas';
      WHEN v_total = 1 THEN
        SET p_mensaje = 'Paciente con una sola cita';
      WHEN v_total <= 3 THEN
        SET p_mensaje = CONCAT('Paciente regular: ', v_total, ' citas');
      ELSE
        SET p_mensaje = CONCAT('Paciente frecuente: ', v_total, ' citas');
    END CASE;

    IF v_no_asistio >= 2 THEN
      SET p_mensaje = CONCAT(p_mensaje, '. Alerta: ', v_no_asistio, ' inasistencias');
    END IF;
  END IF;
END$$

DELIMITER ;

-- =========================================================
-- EJEMPLOS DE EJECUCIÓN
-- =========================================================
CALL sp_hola_mundo();

CALL sp_clasificar_numero(10);
CALL sp_clasificar_numero(-5);
CALL sp_clasificar_numero(0);

CALL sp_nota_alumno(4.5);
CALL sp_nota_alumno(6.5);
CALL sp_nota_alumno(9.8);
CALL sp_nota_alumno(11);
CALL sp_nota_alumno_case(4.5);
CALL sp_nota_alumno_case(6.5);
CALL sp_nota_alumno_case(9.8);
CALL sp_nota_alumno_case(11);

CALL sp_dia_semana(1);
CALL sp_dia_semana(7);
CALL sp_dia_semana(9);

CALL sp_resumen_citas_paciente(8, @msg);    SELECT @msg AS mensaje;
CALL sp_resumen_citas_paciente(1, @msg);    SELECT @msg AS mensaje;
CALL sp_resumen_citas_paciente(9999, @msg); SELECT @msg AS mensaje;
