-- =====================================================================
-- Clase 10 - Seguridad en MariaDB: roles, vistas seguras, cifrado,
--            auditoría y políticas de contraseñas
-- Proyecto : Sistema de gestión de citas - Centros de salud de Cartago
-- Base de datos: proyecto_citas
-- Autora   : Saray Foronda Restrepo
-- Asignatura: Bases de Datos II - Prof. Jhon James Cano Sánchez
--
-- REQUISITOS (ya existentes en el proyecto):
--   * Esquema, datos de prueba, procedimientos y triggers (carpeta sql/).
--   * Funciones de la clase 9: fn_clasificar_edad, fn_calcular_descuento,
--     fn_contar_citas_paciente (clase8_funciones_usuarios.sql).
--   * Plugin simple_password_check activo (ver Ejercicio 6).
--
-- Ejecutar como root, por secciones (cada ejercicio por separado).
-- Es repetible: usa IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE.
--
-- NOTA DE SEGURIDAD: la llave de cifrado y las contraseñas de este archivo
-- son SOLO DE PRÁCTICA. En un sistema real se toman de variables de entorno
-- o de un gestor de secretos y nunca se suben al repositorio.
-- =====================================================================

SET NAMES utf8mb4;
USE proyecto_citas;


-- =====================================================================
-- EJERCICIO 2 - Protección de datos sensibles
-- Columnas sensibles identificadas:
--   1) PIN de acceso del paciente (portal)    -> hash SHA2 + sal
--   2) historial_medico.observaciones         -> cifrado AES
--   3) documento, teléfono y correo           -> enmascarados en vistas (Ej. 3)
-- (El orden del archivo sigue las dependencias: las funciones y columnas
--  se crean antes de las vistas, el procedimiento y los permisos.)
-- =====================================================================

-- 2.1 Columnas nuevas (IF NOT EXISTS permite repetir el script)
ALTER TABLE paciente
  ADD COLUMN IF NOT EXISTS sal      CHAR(16) NULL,
  ADD COLUMN IF NOT EXISTS pin_hash CHAR(64) NULL;

ALTER TABLE historial_medico
  ADD COLUMN IF NOT EXISTS observaciones_cifrado VARBINARY(512) NULL;

-- 2.2 Hash con sal: cada paciente recibe una sal aleatoria propia.
--     (El WHERE incluye la llave primaria para que funcione con "Safe Updates" de Workbench.)
--     PIN de práctica para todos: 'Pin#2026' (con sal distinta, el hash es distinto).
UPDATE paciente SET sal = LEFT(SHA2(UUID(), 256), 16) WHERE id_paciente > 0 AND sal IS NULL;
UPDATE paciente SET pin_hash = SHA2(CONCAT(sal, 'Pin#2026'), 256) WHERE id_paciente > 0 AND pin_hash IS NULL;

-- Evidencia: el mismo PIN produce hashes distintos gracias a la sal
SELECT id_paciente, documento, sal, pin_hash FROM paciente ORDER BY id_paciente LIMIT 3;

-- 2.3 Función de validación de ingreso (compara hashes, nunca el PIN en claro)
DELIMITER $$
DROP FUNCTION IF EXISTS fn_validar_login_citas$$
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

-- Pruebas (usar un documento real de la tabla paciente):
--   SELECT documento FROM paciente LIMIT 1;
--   SELECT fn_validar_login_citas('<documento>', 'Pin#2026') AS pin_correcto,   -- 1
--          fn_validar_login_citas('<documento>', 'pin#2026') AS pin_incorrecto; -- 0

-- 2.4 Cifrado AES de las observaciones médicas
SET @llave = 'Cl4ve_Citas_Practica10';

UPDATE historial_medico
   SET observaciones_cifrado = AES_ENCRYPT(observaciones, @llave)
 WHERE id_historial > 0
   AND observaciones IS NOT NULL
   AND observaciones_cifrado IS NULL;

-- Así queda almacenado (ilegible):
SELECT id_historial, observaciones, HEX(observaciones_cifrado) AS observaciones_cifrado
  FROM historial_medico WHERE observaciones_cifrado IS NOT NULL LIMIT 3;

-- Descifrado con la llave correcta y con una incorrecta (retorna NULL):
SELECT id_historial, CAST(AES_DECRYPT(observaciones_cifrado, @llave) AS CHAR)             AS descifrado_correcto
  FROM historial_medico WHERE observaciones_cifrado IS NOT NULL LIMIT 3;
SELECT id_historial, CAST(AES_DECRYPT(observaciones_cifrado, 'llave_equivocada') AS CHAR) AS descifrado_incorrecto
  FROM historial_medico WHERE observaciones_cifrado IS NOT NULL LIMIT 3;

-- Para proteger de verdad, en producción se ELIMINA el texto en claro una vez cifrado:
--   UPDATE historial_medico SET observaciones = NULL WHERE id_historial > 0 AND observaciones_cifrado IS NOT NULL;
-- (aquí se deja comentado para no perder los datos de prueba).


-- =====================================================================
-- EJERCICIO 3 - Vistas seguras
-- Vista 1: enmascara datos personales con fn_enmascarar (+ clase 9)
-- Vista 2: combina cinco tablas con JOIN
-- =====================================================================
DELIMITER $$
DROP FUNCTION IF EXISTS fn_enmascarar$$
CREATE FUNCTION fn_enmascarar(p_texto VARCHAR(100), p_visibles INT)
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    RETURN CONCAT(REPEAT('*', GREATEST(CHAR_LENGTH(p_texto) - p_visibles, 0)),
                  RIGHT(p_texto, p_visibles));
END$$
DELIMITER ;

CREATE OR REPLACE SQL SECURITY DEFINER VIEW vw_pacientes_publico AS
SELECT id_paciente,
       nombre,
       apellido,
       fn_enmascarar(documento, 4) AS documento,
       fn_enmascarar(telefono, 4)  AS telefono,
       CONCAT(LEFT(correo, 2), '***', SUBSTRING(correo, LOCATE('@', correo))) AS correo,
       fn_clasificar_edad(TIMESTAMPDIFF(YEAR, fecha_nacimiento, CURDATE()))    AS categoria_edad
  FROM paciente;

CREATE OR REPLACE SQL SECURITY DEFINER VIEW vw_citas_detalle AS
SELECT c.id_cita,
       c.fecha,
       c.hora,
       c.estado,
       CONCAT(p.nombre, ' ', p.apellido) AS paciente,
       CONCAT(m.nombre, ' ', m.apellido) AS medico,
       e.nombre                          AS especialidad,
       cs.nombre                         AS centro_salud
  FROM cita c
 INNER JOIN paciente     p  ON p.id_paciente     = c.id_paciente
 INNER JOIN medico       m  ON m.id_medico       = c.id_medico
 INNER JOIN especialidad e  ON e.id_especialidad = m.id_especialidad
 INNER JOIN centro_salud cs ON cs.id_centro      = m.id_centro;

-- Pruebas
SELECT * FROM vw_pacientes_publico LIMIT 5;
SELECT * FROM vw_citas_detalle LIMIT 5;
SHOW FULL TABLES WHERE Table_type = 'VIEW';


-- =====================================================================
-- EJERCICIO 4 - Procedimiento con SQL SECURITY DEFINER
-- Operación principal: agendar una cita. Valida los datos con
-- SIGNAL SQLSTATE '45000'. El rol operativo solo recibe EXECUTE sobre este
-- procedimiento (no INSERT/UPDATE sobre cita). Al insertar la cita se
-- activan los triggers existentes (trg_validar_cita y trg_generar_recordatorio).
-- =====================================================================
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_agendar_cita_segura$$
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
    DECLARE v_id_paciente INT  DEFAULT NULL;
    DECLARE v_inicio      TIME DEFAULT NULL;
    DECLARE v_fin         TIME DEFAULT NULL;

    SELECT id_paciente INTO v_id_paciente
      FROM paciente WHERE documento = p_documento;

    SELECT horario_inicio, horario_fin INTO v_inicio, v_fin
      FROM medico WHERE id_medico = p_id_medico;

    IF v_id_paciente IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El paciente no existe';
    ELSEIF v_inicio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El medico no existe';
    ELSEIF p_fecha < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede agendar una cita en una fecha pasada';
    ELSEIF p_hora < v_inicio OR p_hora >= v_fin THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La hora esta fuera del horario de atencion del medico';
    END IF;

    INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo)
    VALUES (v_id_paciente, p_id_medico, p_fecha, p_hora, p_motivo);

    -- USER() = quien inició sesión; CURRENT_USER() = cuenta cuyos privilegios se usan (el creador)
    SELECT 'Cita agendada' AS mensaje, LAST_INSERT_ID() AS id_cita,
           USER() AS usuario_sesion, CURRENT_USER() AS usuario_privilegios;
END$$
DELIMITER ;

-- Ejemplos de ejecución (como root; usar un documento real y un médico existente):
--   CALL sp_agendar_cita_segura('<documento>', 1, '2026-12-15', '09:00', 'Control general'); -- Permitido
--   CALL sp_agendar_cita_segura('0000', 1, '2026-12-15', '09:30', 'X');             -- ERROR 1644: El paciente no existe
--   CALL sp_agendar_cita_segura('<documento>', 999, '2026-12-15', '09:30', 'X');    -- ERROR 1644: El medico no existe
--   CALL sp_agendar_cita_segura('<documento>', 1, '2020-01-01', '09:30', 'X');      -- ERROR 1644: fecha pasada
--   CALL sp_agendar_cita_segura('<documento>', 1, '2026-12-15', '23:00', 'X');      -- ERROR 1644: fuera de horario


-- =====================================================================
-- EJERCICIO 5 - Auditoría
-- Tabla más sensible: paciente (identidad, contacto y PIN). El trigger
-- registra el campo, el valor anterior y el nuevo, USER(), CURRENT_USER()
-- y la fecha. El PIN/hash nunca se copia a la auditoría.
-- =====================================================================
CREATE TABLE IF NOT EXISTS auditoria_paciente (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente         INT          NOT NULL,
    campo               VARCHAR(30)  NOT NULL,
    valor_anterior      VARCHAR(150),
    valor_nuevo         VARCHAR(150),
    usuario_sesion      VARCHAR(100) NOT NULL,
    usuario_privilegios VARCHAR(100) NOT NULL,
    fecha               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_auditar_paciente_update$$
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
DELIMITER ;

-- Ejemplo de ejecución (como root):
--   UPDATE paciente SET telefono = '3100000000' WHERE id_paciente = 1;
--   SELECT * FROM auditoria_paciente;   -- 1 fila: campo telefono, valor anterior y nuevo, usuario y fecha


-- =====================================================================
-- EJERCICIO 1 - Roles y matriz de seguridad (la matriz está en README.md)
-- Tres roles: consulta, operativo (recepción) y administrador.
-- Los privilegios del administrador se dan TABLA POR TABLA para que
-- auditoria_paciente sea de SOLO LECTURA (MariaDB no permite excluir una
-- tabla de un privilegio otorgado a toda la base de datos).
-- =====================================================================
DROP USER IF EXISTS 'lector_citas'@'%', 'recepcion_citas'@'%', 'gestor_citas'@'%';
DROP ROLE IF EXISTS rol_consulta_citas, rol_recepcion_citas, rol_admin_citas;

CREATE ROLE rol_consulta_citas;
CREATE ROLE rol_recepcion_citas;
CREATE ROLE rol_admin_citas;

-- rol_consulta_citas: solo lee las VISTAS (nunca las tablas)
GRANT SELECT ON proyecto_citas.vw_pacientes_publico TO rol_consulta_citas;
GRANT SELECT ON proyecto_citas.vw_citas_detalle     TO rol_consulta_citas;

-- rol_recepcion_citas (operativo): hereda consulta y solo EXECUTE de los procedimientos
GRANT rol_consulta_citas TO rol_recepcion_citas;
GRANT EXECUTE ON PROCEDURE proyecto_citas.sp_agendar_cita_segura TO rol_recepcion_citas;
GRANT EXECUTE ON PROCEDURE proyecto_citas.sp_cancelar_cita       TO rol_recepcion_citas;
GRANT EXECUTE ON FUNCTION  proyecto_citas.fn_validar_login_citas TO rol_recepcion_citas;

-- rol_admin_citas: administra los datos tabla por tabla; auditoría solo lectura
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.centro_salud      TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.especialidad      TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.medico            TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.paciente          TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.cita             TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.historial_medico  TO rol_admin_citas;
GRANT SELECT, INSERT, UPDATE, DELETE ON proyecto_citas.recordatorio      TO rol_admin_citas;
GRANT SELECT ON proyecto_citas.auditoria_paciente  TO rol_admin_citas;   -- solo lectura
GRANT SELECT ON proyecto_citas.vw_pacientes_publico TO rol_admin_citas;
GRANT SELECT ON proyecto_citas.vw_citas_detalle     TO rol_admin_citas;
GRANT EXECUTE ON proyecto_citas.*                   TO rol_admin_citas;


-- =====================================================================
-- EJERCICIO 6 - Usuarios por rol y políticas de cuentas
-- =====================================================================

-- 6.1 La política de contraseñas ya está activa (si no lo estuviera:
--     INSTALL SONAME 'simple_password_check';)
SHOW VARIABLES LIKE 'simple_password_check%';

-- Rechazo de una contraseña débil (ejecutar SOLA, debe fallar con ERROR 1819):
--   CREATE USER 'prueba_debil'@'%' IDENTIFIED BY '12345';
-- Contraseña que cumple la política (se crea):
--   CREATE USER 'prueba_fuerte'@'%' IDENTIFIED BY 'Prueba#2026';
--   DROP USER 'prueba_fuerte'@'%';

-- 6.2 Un usuario por rol, con vencimiento de 90 días y límites de recursos
CREATE USER 'lector_citas'@'%'    IDENTIFIED BY 'Lector#2026'
    PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER 'recepcion_citas'@'%' IDENTIFIED BY 'Recepcion#2026'
    WITH MAX_USER_CONNECTIONS 2 MAX_QUERIES_PER_HOUR 500;
CREATE USER 'gestor_citas'@'%'    IDENTIFIED BY 'Gestor#2026';

GRANT rol_consulta_citas  TO 'lector_citas'@'%';
GRANT rol_recepcion_citas TO 'recepcion_citas'@'%';
GRANT rol_admin_citas     TO 'gestor_citas'@'%';

SET DEFAULT ROLE rol_consulta_citas  FOR 'lector_citas'@'%';
SET DEFAULT ROLE rol_recepcion_citas FOR 'recepcion_citas'@'%';
SET DEFAULT ROLE rol_admin_citas     FOR 'gestor_citas'@'%';

FLUSH PRIVILEGES;

-- 6.3 Verificación (capturas de SHOW GRANTS de cada rol y cada usuario)
SELECT user, host, is_role FROM mysql.user
 WHERE user LIKE 'rol\_%citas' OR user IN ('lector_citas', 'recepcion_citas', 'gestor_citas');
SELECT * FROM mysql.roles_mapping WHERE Role LIKE '%citas';

SHOW GRANTS FOR rol_consulta_citas;
SHOW GRANTS FOR rol_recepcion_citas;
SHOW GRANTS FOR rol_admin_citas;
SHOW GRANTS FOR 'lector_citas'@'%';
SHOW GRANTS FOR 'recepcion_citas'@'%';
SHOW GRANTS FOR 'gestor_citas'@'%';

-- Configuración de vencimiento y límites:
SELECT User, Host,
       JSON_VALUE(Priv, '$.password_lifetime')    AS dias_vigencia_clave,
       JSON_VALUE(Priv, '$.max_user_connections') AS max_conexiones,
       JSON_VALUE(Priv, '$.max_questions')        AS max_consultas_hora
  FROM mysql.global_priv
 WHERE User IN ('lector_citas', 'recepcion_citas', 'gestor_citas');

-- ---------------------------------------------------------------------
-- 6.4 PRUEBAS DE CONEXIÓN (una conexión por usuario, puerto del contenedor).
-- Ejecutar primero lo permitido y, SOLAS, las denegadas.
--
-- Usuario lector_citas (Lector#2026):
--   SELECT CURRENT_USER(), CURRENT_ROLE();             -- lector_citas@% | rol_consulta_citas
--   SELECT * FROM vw_pacientes_publico LIMIT 5;        -- Permitido (datos enmascarados)
--   SELECT * FROM paciente;                            -- Denegado (ERROR 1142)
--   CALL sp_agendar_cita_segura('<doc>', 1, '2026-12-16', '09:00', 'X'); -- Denegado (ERROR 1370)
--
-- Usuario recepcion_citas (Recepcion#2026):
--   SELECT CURRENT_USER(), CURRENT_ROLE();             -- recepcion_citas@% | rol_recepcion_citas
--   CALL sp_agendar_cita_segura('<doc>', 1, '2026-12-16', '09:00', 'Control'); -- Permitido
--        (usuario_sesion = recepcion_citas@..., usuario_privilegios = root@localhost)
--   SELECT * FROM vw_citas_detalle ORDER BY id_cita DESC LIMIT 3; -- Permitido (rol heredado)
--   INSERT INTO cita (id_paciente, id_medico, fecha, hora) VALUES (1, 1, '2026-12-16', '10:00'); -- Denegado (ERROR 1142)
--   SET ROLE NONE;  SELECT * FROM vw_citas_detalle;    -- Denegado: los privilegios venían del rol
--   SET ROLE rol_recepcion_citas;  SELECT * FROM vw_citas_detalle; -- Permitido de nuevo
--
-- Usuario gestor_citas (Gestor#2026):
--   SELECT CURRENT_USER(), CURRENT_ROLE();             -- gestor_citas@% | rol_admin_citas
--   UPDATE paciente SET telefono = '3112223344' WHERE id_paciente = 2;  -- Permitido
--   SELECT * FROM auditoria_paciente;                  -- Permitido (aparece gestor_citas)
--   DELETE FROM auditoria_paciente;                    -- Denegado (ERROR 1142): no puede borrar la evidencia
--   DROP TABLE recordatorio;                           -- Denegado
--   CREATE USER 'intruso'@'%' IDENTIFIED BY 'Intruso#2026';  -- Denegado (ERROR 1227)
-- ---------------------------------------------------------------------

-- 6.5 Bloqueo y expiración (demostración opcional, como root):
--   ALTER USER 'lector_citas'@'%' ACCOUNT LOCK;     -- al entrar: ERROR 4151 (cuenta bloqueada)
--   ALTER USER 'lector_citas'@'%' ACCOUNT UNLOCK;


-- =====================================================================
-- EJERCICIO 7 - Lista de chequeo de seguridad del servidor
-- =====================================================================
-- 1. Cuentas que pueden conectarse desde cualquier host ('%')
SELECT user, host FROM mysql.user WHERE host = '%' AND is_role = 'N';

-- 2. Cuentas con privilegios globales diferentes de root
SELECT GRANTEE, PRIVILEGE_TYPE
  FROM information_schema.USER_PRIVILEGES
 WHERE GRANTEE NOT LIKE '''root''%'
   AND PRIVILEGE_TYPE <> 'USAGE';

-- 3. Cuentas con GRANT OPTION a nivel de base de datos
-- (En MariaDB el GRANT OPTION se ve en IS_GRANTABLE; filtrar por
--  PRIVILEGE_TYPE = 'GRANT', como en la guía, no devuelve filas.)
SELECT DISTINCT GRANTEE, TABLE_SCHEMA
  FROM information_schema.SCHEMA_PRIVILEGES
 WHERE IS_GRANTABLE = 'YES';

-- 4. Cuentas sin contraseña
SELECT user, host FROM mysql.user
 WHERE authentication_string = '' AND is_role = 'N' AND user <> 'mariadb.sys';

-- 5. Conexiones activas
SELECT ID, USER, HOST, DB, COMMAND, TIME FROM information_schema.PROCESSLIST;

-- 6. Variables de seguridad relevantes
SHOW VARIABLES WHERE Variable_name IN
  ('have_ssl', 'local_infile', 'skip_name_resolve', 'secure_file_priv',
   'disconnect_on_expired_password', 'default_password_lifetime');

-- ---------------------------------------------------------------------
-- REFLEXIÓN DE SEGURIDAD
-- La lista de chequeo muestra varios riesgos. Primero, varias cuentas (incluida
-- root) aceptan conexiones desde cualquier host ('%'); en producción se limitaría
-- a la IP de la aplicación o a localhost. Segundo, cuentas de clases anteriores
-- como admin_bbdd y admin_citas tienen GRANT OPTION y podrían entregar
-- privilegios a otros; se retiraría esa opción y se reservaría a un único DBA.
-- Tercero, have_ssl está deshabilitado, así que el tráfico viaja sin cifrar; se
-- habilitaría TLS y se exigiría con REQUIRE SSL. Cuarto, local_infile está
-- activo y existe una cuenta de desarrollo (dev_user) con contraseña débil creada
-- antes de la política; se desactivaría local_infile y se cambiaría la clave.
-- Quinto, la llave AES y las contraseñas de práctica están escritas en el script;
-- se tomarían de variables de entorno o un gestor de secretos y se rotarían.
-- Además se mantendrían copias de seguridad y la auditoría en un servidor aparte.
-- ---------------------------------------------------------------------
