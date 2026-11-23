-- =====================================================================
-- 07_seguridad.sql  -  Roles, usuarios, privilegios y políticas de contraseña
--
-- Las contraseñas de los usuarios salen de las variables de sesión
-- @pass_lector, @pass_recepcion y @pass_gestor (las define instalar.sh a
-- partir de scripts/.respaldo.env, archivo que NO se sube al repositorio).
-- Los datos sensibles ya quedaron protegidos en 02_datos.sql:
--   paciente.pin_hash (SHA-256 + sal) e historial_medico.observaciones_cifrado (AES).
-- Para ejecutar este archivo solo: SET @pass_lector='...'; etc. (ver README).
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

DELIMITER $$
CREATE PROCEDURE sp_tmp_verificar_variables()
BEGIN
  IF @pass_lector IS NULL OR @pass_recepcion IS NULL OR @pass_gestor IS NULL THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Defina @pass_lector, @pass_recepcion y @pass_gestor (ver scripts/respaldo.env.ejemplo)';
  END IF;
END$$
DELIMITER ;
CALL sp_tmp_verificar_variables();
DROP PROCEDURE sp_tmp_verificar_variables;

-- Política de contraseñas: plugin simple_password_check (mínimo 8 caracteres,
-- un dígito, mayúscula y minúscula, y un carácter especial). Si no está cargado:
--   INSTALL SONAME 'simple_password_check';
SHOW VARIABLES LIKE 'simple_password_check%';

-- ---------------------------------------------------------------------
-- Roles (repetible: se eliminan y recrean)
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'lector_citas'@'%', 'recepcion_citas'@'%', 'gestor_citas'@'%';
DROP ROLE IF EXISTS rol_consulta_citas, rol_recepcion_citas, rol_admin_citas;

CREATE ROLE rol_consulta_citas;
CREATE ROLE rol_recepcion_citas;
CREATE ROLE rol_admin_citas;

-- rol_consulta_citas: solo lee las VISTAS (nunca las tablas)
GRANT SELECT ON proyecto_citas.vw_pacientes_publico TO rol_consulta_citas;
GRANT SELECT ON proyecto_citas.vw_citas_detalle     TO rol_consulta_citas;
GRANT SELECT ON proyecto_citas.vw_resumen_centro    TO rol_consulta_citas;

-- rol_recepcion_citas (operativo): hereda consulta y solo recibe EXECUTE de los procedimientos
GRANT rol_consulta_citas TO rol_recepcion_citas;
GRANT EXECUTE ON PROCEDURE proyecto_citas.sp_agendar_cita_segura TO rol_recepcion_citas;
GRANT EXECUTE ON PROCEDURE proyecto_citas.sp_cancelar_cita       TO rol_recepcion_citas;
GRANT EXECUTE ON PROCEDURE proyecto_citas.sp_reprogramar_cita    TO rol_recepcion_citas;
GRANT EXECUTE ON FUNCTION  proyecto_citas.fn_validar_login_citas TO rol_recepcion_citas;

-- rol_admin_citas: administra los datos TABLA POR TABLA (MariaDB no permite excluir
-- una tabla de un privilegio dado a toda la base) para que las tablas de auditoría y
-- de registro queden en SOLO LECTURA: el administrador no puede borrar la evidencia.
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.centro_salud     TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.especialidad     TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.estado_cita      TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.medico           TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.franja_horaria   TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.paciente         TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.cita             TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.historial_medico TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.recordatorio     TO rol_admin_citas;
GRANT SELECT ON proyecto_citas.auditoria_paciente  TO rol_admin_citas;   -- solo lectura
GRANT SELECT ON proyecto_citas.log_errores         TO rol_admin_citas;   -- solo lectura
GRANT SELECT ON proyecto_citas.log_eventos         TO rol_admin_citas;   -- solo lectura
GRANT SELECT ON proyecto_citas.vw_pacientes_publico TO rol_admin_citas;
GRANT SELECT ON proyecto_citas.vw_citas_detalle     TO rol_admin_citas;
GRANT SELECT ON proyecto_citas.vw_resumen_centro    TO rol_admin_citas;
GRANT EXECUTE ON proyecto_citas.*                   TO rol_admin_citas;
-- Sin DROP, ALTER, CREATE USER ni GRANT OPTION.

-- ---------------------------------------------------------------------
-- Usuarios (uno por rol). La contraseña se arma con una sentencia preparada
-- para no escribirla en el código. Deben cumplir la política (si no: ERROR 1819).
-- ---------------------------------------------------------------------
SET @sql = CONCAT("CREATE USER 'lector_citas'@'%' IDENTIFIED BY '", @pass_lector,
                  "' PASSWORD EXPIRE INTERVAL 90 DAY");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = CONCAT("CREATE USER 'recepcion_citas'@'%' IDENTIFIED BY '", @pass_recepcion,
                  "' WITH MAX_USER_CONNECTIONS 2 MAX_QUERIES_PER_HOUR 500");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = CONCAT("CREATE USER 'gestor_citas'@'%' IDENTIFIED BY '", @pass_gestor, "'");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @sql = NULL;

GRANT rol_consulta_citas  TO 'lector_citas'@'%';
GRANT rol_recepcion_citas TO 'recepcion_citas'@'%';
GRANT rol_admin_citas     TO 'gestor_citas'@'%';

SET DEFAULT ROLE rol_consulta_citas  FOR 'lector_citas'@'%';
SET DEFAULT ROLE rol_recepcion_citas FOR 'recepcion_citas'@'%';
SET DEFAULT ROLE rol_admin_citas     FOR 'gestor_citas'@'%';

FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------
-- Verificación (capturas de SHOW GRANTS de cada rol y de cada usuario)
-- ---------------------------------------------------------------------
SELECT user, host, is_role FROM mysql.user
 WHERE user LIKE 'rol\_%citas' OR user IN ('lector_citas', 'recepcion_citas', 'gestor_citas');
SHOW GRANTS FOR rol_consulta_citas;
SHOW GRANTS FOR rol_recepcion_citas;
SHOW GRANTS FOR rol_admin_citas;
SHOW GRANTS FOR 'lector_citas'@'%';
SHOW GRANTS FOR 'recepcion_citas'@'%';
SHOW GRANTS FOR 'gestor_citas'@'%';
