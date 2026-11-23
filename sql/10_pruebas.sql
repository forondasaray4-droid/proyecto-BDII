-- =====================================================================
-- 10_pruebas.sql  -  Casos de prueba: operación, resultado esperado y obtenido
-- Se ejecuta aparte de la instalación:   ./instalar.sh --pruebas
-- (necesita @llave_aes y @pin_demo; instalar.sh los define desde .respaldo.env).
-- Es repetible: crea citas con motivo 'PRUEBA...' y las elimina al terminar.
-- Al final, la sección B muestra las pruebas de CONCURRENCIA con dos sesiones
-- y la sección C las pruebas de SEGURIDAD con los tres usuarios (manuales).
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

-- ---------------------------------------------------------------------
-- Preparación: tabla de resultados y procedimiento auxiliar de prueba
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS res_pruebas;
CREATE TEMPORARY TABLE res_pruebas (
  n         INT AUTO_INCREMENT PRIMARY KEY,
  caso      VARCHAR(95),
  esperado  VARCHAR(120),
  obtenido  VARCHAR(255),
  resultado VARCHAR(6)
);

DROP PROCEDURE IF EXISTS pt_ejecutar;
DELIMITER $$
-- Ejecuta una sentencia (CALL, INSERT...) capturando el error; compara el mensaje
-- obtenido con el esperado ('OK' = debe ejecutarse sin error).
CREATE PROCEDURE pt_ejecutar(IN p_caso VARCHAR(95), IN p_sql TEXT, IN p_esperado VARCHAR(120))
BEGIN
  DECLARE v_msg VARCHAR(255) DEFAULT 'OK';
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
  SET @sql_pt = p_sql;
  PREPARE st FROM @sql_pt;
  EXECUTE st;
  DEALLOCATE PREPARE st;
  INSERT INTO res_pruebas (caso, esperado, obtenido, resultado)
  VALUES (p_caso, p_esperado, v_msg,
          IF(p_esperado = 'OK', IF(v_msg = 'OK', 'OK', 'FALLO'),
             IF(v_msg LIKE CONCAT('%', p_esperado, '%'), 'OK', 'FALLO')));
END$$

-- Compara un valor obtenido con el esperado
CREATE PROCEDURE pt_comparar(IN p_caso VARCHAR(95), IN p_esperado VARCHAR(120), IN p_obtenido VARCHAR(255))
BEGIN
  INSERT INTO res_pruebas (caso, esperado, obtenido, resultado)
  VALUES (p_caso, p_esperado, p_obtenido,
          IF(p_esperado <=> p_obtenido, 'OK', 'FALLO'));
END$$
DELIMITER ;

-- Limpieza de restos de ejecuciones anteriores
DELETE h FROM historial_medico h JOIN cita c USING (id_cita) WHERE c.motivo LIKE 'PRUEBA%';
DELETE r FROM recordatorio r JOIN cita c USING (id_cita) WHERE c.motivo LIKE 'PRUEBA%';
DELETE FROM cita WHERE motivo LIKE 'PRUEBA%';

-- Un lunes futuro (al menos dos semanas adelante) para no chocar con datos reales
SET @lun = CURDATE() + INTERVAL (7 - WEEKDAY(CURDATE())) DAY + INTERVAL 14 DAY;
SET @sab = @lun + INTERVAL 5 DAY;
SET @llave_original = @llave_aes;

-- ---------------------------------------------------------------------
-- A. PROCEDIMIENTOS TRANSACCIONALES
-- ---------------------------------------------------------------------
-- sp_agendar_cita: éxito y errores controlados (médico 1: lunes a viernes 07:00-13:00)
CALL pt_ejecutar('sp_agendar_cita: cita valida (medico 1, lunes 07:00)',
  CONCAT('CALL sp_agendar_cita(1, 1, ''', @lun, ''', ''07:00'', ''PRUEBA agendar'', @c1)'), 'OK');
CALL pt_ejecutar('sp_agendar_cita: otra cita valida (lunes 08:00)',
  CONCAT('CALL sp_agendar_cita(2, 1, ''', @lun, ''', ''08:00'', ''PRUEBA agendar'', @c2)'), 'OK');
CALL pt_ejecutar('sp_agendar_cita: misma hora del mismo medico',
  CONCAT('CALL sp_agendar_cita(3, 1, ''', @lun, ''', ''07:00'', ''PRUEBA choque'', @cx)'), 'no esta disponible');
CALL pt_ejecutar('sp_agendar_cita: hora fuera de la franja (15:00)',
  CONCAT('CALL sp_agendar_cita(3, 1, ''', @lun, ''', ''15:00'', ''PRUEBA fuera'', @cx)'), 'no esta disponible');
CALL pt_ejecutar('sp_agendar_cita: dia sin franja (medico 2 un sabado)',
  CONCAT('CALL sp_agendar_cita(3, 2, ''', @sab, ''', ''09:00'', ''PRUEBA sabado'', @cx)'), 'no esta disponible');
CALL pt_ejecutar('sp_agendar_cita: medico inexistente',
  CONCAT('CALL sp_agendar_cita(3, 999, ''', @lun, ''', ''09:00'', ''PRUEBA'', @cx)'), 'El medico no existe');
CALL pt_ejecutar('sp_agendar_cita: paciente inexistente',
  CONCAT('CALL sp_agendar_cita(999999, 1, ''', @lun, ''', ''09:00'', ''PRUEBA'', @cx)'), 'El paciente no existe');
CALL pt_ejecutar('sp_agendar_cita: fecha pasada',
  'CALL sp_agendar_cita(3, 1, ''2020-01-06'', ''09:00'', ''PRUEBA'', @cx)', 'no puede ser pasada');
CALL pt_ejecutar('sp_agendar_cita: fecha nula',
  'CALL sp_agendar_cita(3, 1, NULL, ''09:00'', ''PRUEBA'', @cx)', 'obligatorias');
CALL pt_comparar('trg_generar_recordatorio: la cita 1 tiene recordatorio Pendiente', '1',
  (SELECT CAST(COUNT(*) AS CHAR) FROM recordatorio WHERE id_cita = @c1 AND estado = 'Pendiente'));

-- Triggers de validación probados directamente con INSERT (sin procedimiento)
CALL pt_ejecutar('trg_validar_cita: INSERT en horario ocupado',
  CONCAT('INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo) VALUES (3, 1, ''', @lun, ''', ''07:00'', ''PRUEBA trigger'')'),
  'ya tiene una cita asignada');
CALL pt_ejecutar('trg_validar_cita: INSERT fuera del horario del medico',
  CONCAT('INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo) VALUES (3, 1, ''', @lun, ''', ''20:00'', ''PRUEBA trigger'')'),
  'fuera del horario');

-- sp_cancelar_cita
CALL pt_ejecutar('sp_cancelar_cita: cita programada', 'CALL sp_cancelar_cita(@c2)', 'OK');
CALL pt_comparar('sp_cancelar_cita: estado Cancelada y recordatorio Cancelado', 'Cancelada/Cancelado',
  (SELECT CONCAT(e.nombre, '/', r.estado) FROM cita c JOIN estado_cita e USING (id_estado)
     JOIN recordatorio r ON r.id_cita = c.id_cita WHERE c.id_cita = @c2));
CALL pt_ejecutar('sp_cancelar_cita: cancelar de nuevo', 'CALL sp_cancelar_cita(@c2)', 'Solo se pueden cancelar');
CALL pt_ejecutar('sp_cancelar_cita: cita inexistente', 'CALL sp_cancelar_cita(99999999)', 'La cita no existe');
CALL pt_ejecutar('sp_agendar_cita: el horario liberado por la cancelacion se puede reutilizar',
  CONCAT('CALL sp_agendar_cita(2, 1, ''', @lun, ''', ''08:00'', ''PRUEBA reutilizar'', @c2)'), 'OK');

-- sp_reprogramar_cita: ATOMICIDAD. @c2 (08:00) se intenta mover a las 07:00, ocupada por @c1.
CALL pt_ejecutar('sp_reprogramar_cita: nuevo horario ocupado (falla en la 2.a operacion)',
  CONCAT('CALL sp_reprogramar_cita(@c2, ''', @lun, ''', ''07:00'', @cn)'), 'ya tiene una cita asignada');
CALL pt_comparar('ATOMICIDAD: la cita original sigue Programada tras el ROLLBACK', 'Programada',
  (SELECT e.nombre FROM cita c JOIN estado_cita e USING (id_estado) WHERE c.id_cita = @c2));
CALL pt_comparar('ATOMICIDAD: su recordatorio sigue Pendiente', 'Pendiente',
  (SELECT estado FROM recordatorio WHERE id_cita = @c2));
CALL pt_ejecutar('sp_reprogramar_cita: nuevo horario libre (09:00)',
  CONCAT('CALL sp_reprogramar_cita(@c2, ''', @lun, ''', ''09:00'', @cn)'), 'OK');
CALL pt_comparar('sp_reprogramar_cita: la anterior queda Cancelada', 'Cancelada',
  (SELECT e.nombre FROM cita c JOIN estado_cita e USING (id_estado) WHERE c.id_cita = @c2));
CALL pt_comparar('sp_reprogramar_cita: la nueva queda Programada a las 09:00', 'Programada/09:00:00',
  (SELECT CONCAT(e.nombre, '/', c.hora) FROM cita c JOIN estado_cita e USING (id_estado) WHERE c.id_cita = @cn));
CALL pt_ejecutar('sp_reprogramar_cita: cita ya cancelada', 'CALL sp_reprogramar_cita(@c2, @lun, ''10:00'', @cx)',
  'Solo se pueden reprogramar');

-- sp_registrar_atencion (historial cifrado + estado Atendida en una transaccion)
CALL pt_ejecutar('sp_registrar_atencion: cita programada',
  'CALL sp_registrar_atencion(@cn, ''Gripe comun'', ''Reposo'', ''Observacion de prueba'')', 'OK');
CALL pt_comparar('sp_registrar_atencion: la cita queda Atendida', 'Atendida',
  (SELECT e.nombre FROM cita c JOIN estado_cita e USING (id_estado) WHERE c.id_cita = @cn));
CALL pt_comparar('Cifrado AES: observaciones ilegibles en la tabla y legibles con la llave', 'Observacion de prueba',
  (SELECT CAST(AES_DECRYPT(observaciones_cifrado, @llave_aes) AS CHAR) FROM historial_medico WHERE id_cita = @cn));
CALL pt_comparar('Cifrado AES: con llave incorrecta devuelve NULL', NULL,
  (SELECT CAST(AES_DECRYPT(observaciones_cifrado, 'llave_incorrecta') AS CHAR) FROM historial_medico WHERE id_cita = @cn));
CALL pt_ejecutar('sp_registrar_atencion: atender dos veces',
  'CALL sp_registrar_atencion(@cn, ''X'', ''X'', ''X'')', 'Solo se puede atender');
CALL pt_ejecutar('sp_registrar_atencion: diagnostico vacio',
  'CALL sp_registrar_atencion(@c1, '' '', ''X'', ''X'')', 'diagnostico es obligatorio');
SET @llave_aes = NULL;
CALL pt_ejecutar('sp_registrar_atencion: sin llave de cifrado',
  'CALL sp_registrar_atencion(@c1, ''Gripe'', ''X'', ''X'')', '@llave_aes');
SET @llave_aes = @llave_original;
CALL pt_comparar('sp_registrar_atencion: tras el error la cita sigue Programada', 'Programada',
  (SELECT e.nombre FROM cita c JOIN estado_cita e USING (id_estado) WHERE c.id_cita = @c1));

-- Otros procedimientos
CALL pt_ejecutar('sp_registrar_paciente: paciente nuevo',
  'CALL sp_registrar_paciente(''PRUEBA001'', ''Prueba'', ''Temporal'', ''1990-01-01'', ''3000000000'', ''p@mail.com'', ''Calle 1'', @pn)', 'OK');
CALL pt_ejecutar('sp_registrar_paciente: documento duplicado',
  'CALL sp_registrar_paciente(''PRUEBA001'', ''Prueba'', ''Temporal'', ''1990-01-01'', NULL, NULL, NULL, @px)', 'Ya existe un paciente');
CALL pt_ejecutar('sp_registrar_paciente: fecha de nacimiento futura',
  'CALL sp_registrar_paciente(''PRUEBA002'', ''Prueba'', ''Temporal'', ''2999-01-01'', NULL, NULL, NULL, @px)', 'fecha de nacimiento');
SET @total = 0;
CALL pt_ejecutar('sp_acumular_citas_paciente (INOUT): paciente 1', 'CALL sp_acumular_citas_paciente(1, @total)', 'OK');
CALL pt_comparar('sp_acumular_citas_paciente: el total coincide con el conteo directo',
  (SELECT CAST(COUNT(*) AS CHAR) FROM cita WHERE id_paciente = 1), CAST(@total AS CHAR));
CALL pt_ejecutar('sp_agendar_cita_segura: por documento', CONCAT('CALL sp_agendar_cita_segura(''1112345601'', 1, ''', @lun, ''', ''10:00'', ''PRUEBA segura'')'), 'OK');
CALL pt_ejecutar('sp_agendar_cita_segura: documento inexistente', CONCAT('CALL sp_agendar_cita_segura(''0000'', 1, ''', @lun, ''', ''11:00'', ''PRUEBA'')'), 'El paciente no existe');
CALL pt_ejecutar('sp_reporte_atenciones_centro (OUT): centro 1', 'CALL sp_reporte_atenciones_centro(1, @tot)', 'OK');

-- Registro de errores: los errores de los procedimientos transaccionales quedaron en log_errores
CALL pt_comparar('log_errores: registra los errores de los procedimientos', 'SI',
  (SELECT IF(COUNT(*) >= 10, 'SI', 'NO') FROM log_errores WHERE procedimiento LIKE 'sp\_%'));

-- ---------------------------------------------------------------------
-- A.2 FUNCIONES, VISTAS, AUDITORÍA Y EVENTOS
-- ---------------------------------------------------------------------
CALL pt_comparar('fn_clasificar_edad(8)',  'Niño',         fn_clasificar_edad(8));
CALL pt_comparar('fn_clasificar_edad(70)', 'Adulto mayor', fn_clasificar_edad(70));
CALL pt_comparar('fn_enmascarar(1234567890, 4)', '******7890', fn_enmascarar('1234567890', 4));
CALL pt_comparar('fn_validar_login_citas con el PIN correcto', '1', CAST(fn_validar_login_citas('1112345601', @pin_demo) AS CHAR));
CALL pt_comparar('fn_validar_login_citas con un PIN incorrecto', '0', CAST(fn_validar_login_citas('1112345601', 'incorrecto') AS CHAR));
CALL pt_comparar('fn_medico_disponible: lunes 12:00 libre', '1', CAST(fn_medico_disponible(1, @lun, '12:00') AS CHAR));
CALL pt_comparar('fn_medico_disponible: lunes 07:00 ocupado', '0', CAST(fn_medico_disponible(1, @lun, '07:00') AS CHAR));
CALL pt_comparar('fn_contar_citas_paciente = conteo directo',
  (SELECT CAST(COUNT(*) AS CHAR) FROM cita WHERE id_paciente = 1), CAST(fn_contar_citas_paciente('1112345601') AS CHAR));

CALL pt_comparar('Hash con sal: dos pacientes con el mismo PIN tienen hash distinto', 'SI',
  (SELECT IF(a.pin_hash <> b.pin_hash, 'SI', 'NO') FROM paciente a, paciente b WHERE a.id_paciente = 1 AND b.id_paciente = 2));
CALL pt_comparar('vw_pacientes_publico: el documento sale enmascarado', 'SI',
  (SELECT IF(documento LIKE '******%', 'SI', 'NO') FROM vw_pacientes_publico WHERE id_paciente = 1));
CALL pt_comparar('vw_citas_detalle: una fila por cita', (SELECT CAST(COUNT(*) AS CHAR) FROM cita),
  (SELECT CAST(COUNT(*) AS CHAR) FROM vw_citas_detalle));
CALL pt_comparar('vw_resumen_centro: la suma de citas coincide', (SELECT CAST(COUNT(*) AS CHAR) FROM cita),
  (SELECT CAST(SUM(total_citas) AS CHAR) FROM vw_resumen_centro));

-- Auditoría (trg_auditar_paciente_update) y su protección
SET @aud_antes = (SELECT COUNT(*) FROM auditoria_paciente);
UPDATE paciente SET telefono = '3999999999' WHERE id_paciente = 1;
CALL pt_comparar('trg_auditar_paciente_update: el cambio de telefono queda auditado', '1',
  CAST((SELECT COUNT(*) FROM auditoria_paciente) - @aud_antes AS CHAR));
CALL pt_ejecutar('Auditoria protegida: DELETE rechazado', 'DELETE FROM auditoria_paciente WHERE id > 0', 'no se puede eliminar');
CALL pt_ejecutar('Auditoria protegida: UPDATE rechazado', 'UPDATE auditoria_paciente SET campo = ''x'' WHERE id > 0', 'no se puede modificar');

-- Procedimientos que ejecutan los eventos programados
SET @ev_antes = (SELECT COUNT(*) FROM log_eventos);
CALL pt_ejecutar('sp_marcar_citas_vencidas', 'CALL sp_marcar_citas_vencidas()', 'OK');
CALL pt_ejecutar('sp_enviar_recordatorios',  'CALL sp_enviar_recordatorios()', 'OK');
CALL pt_comparar('Eventos: ambos procedimientos registran en log_eventos', '2',
  CAST((SELECT COUNT(*) FROM log_eventos) - @ev_antes AS CHAR));
CALL pt_comparar('Eventos programados existentes', '2',
  (SELECT CAST(COUNT(*) AS CHAR) FROM information_schema.EVENTS WHERE EVENT_SCHEMA = 'proyecto_citas'));

-- ---------------------------------------------------------------------
-- RESULTADO
-- ---------------------------------------------------------------------
SELECT n, caso, esperado, obtenido, resultado FROM res_pruebas ORDER BY n;
SELECT resultado, COUNT(*) AS casos FROM res_pruebas GROUP BY resultado;

-- Limpieza: se eliminan los datos de prueba (la auditoría y log_errores se conservan
-- como evidencia; la auditoría no se puede borrar por diseño)
DELETE h FROM historial_medico h JOIN cita c USING (id_cita) WHERE c.motivo LIKE 'PRUEBA%';
DELETE r FROM recordatorio r JOIN cita c USING (id_cita) WHERE c.motivo LIKE 'PRUEBA%';
DELETE FROM cita WHERE motivo LIKE 'PRUEBA%';
DELETE FROM paciente WHERE documento LIKE 'PRUEBA%';
UPDATE paciente SET telefono = '3151000001' WHERE id_paciente = 1;
DROP PROCEDURE pt_ejecutar;
DROP PROCEDURE pt_comparar;

-- =====================================================================
-- B. CONCURRENCIA con dos sesiones (manual; capturas para el informe)
-- Abrir dos terminales (SESION A y SESION B) y en cada una:
--   docker exec -it citas_mariadb mariadb -u root -p proyecto_citas
-- (las sesiones de Workbench en una misma conexion comparten sesion: no sirven).
-- Reemplazar <LUNES> por un lunes futuro (p. ej. el que imprime:
--   SELECT CURDATE() + INTERVAL (7 - WEEKDAY(CURDATE())) DAY + INTERVAL 21 DAY; )
--
-- B.1 Recurso en disputa: LA CITA. Una recepcionista cancela la cita mientras el
--     medico registra su atencion. Se prepara una cita:
--       CALL sp_agendar_cita(1, 1, '<LUNES>', '12:00', 'PRUEBA conc', @id);  SELECT @id;   -- X
--
--   SIN bloqueo (el problema: actualizacion perdida)
--   [1] SESION A:  START TRANSACTION;
--                  SELECT id_estado FROM cita WHERE id_cita = X;          -- 1 (Programada)
--   [2] SESION B:  START TRANSACTION;
--                  SELECT id_estado FROM cita WHERE id_cita = X;          -- 1 (Programada)
--   [3] SESION A:  UPDATE cita SET id_estado = 3 WHERE id_cita = X;       -- Cancelada
--                  COMMIT;
--   [4] SESION B:  INSERT INTO historial_medico (id_cita, diagnostico) VALUES (X, 'Gripe');
--                  UPDATE cita SET id_estado = 2 WHERE id_cita = X;       -- Atendida
--                  COMMIT;
--   [5] SELECT c.id_cita, e.nombre FROM cita c JOIN estado_cita e USING (id_estado) WHERE id_cita = X;
--                  -- Atendida: se perdio la cancelacion y hay un historial de una cita cancelada
--       (limpiar: DELETE FROM historial_medico WHERE id_cita = X; DELETE FROM recordatorio
--        WHERE id_cita = X; DELETE FROM cita WHERE id_cita = X;  y crear otra cita)
--
--   CON bloqueo (la solucion: SELECT ... FOR UPDATE dentro de los procedimientos)
--   [1] SESION A:  START TRANSACTION;
--                  SELECT id_estado FROM cita WHERE id_cita = X FOR UPDATE;   -- A bloquea la fila
--   [2] SESION B:  SET @llave_aes = '<la llave de .respaldo.env>';
--                  SET SESSION innodb_lock_wait_timeout = 30;
--                  CALL sp_registrar_atencion(X, 'Gripe', 'Reposo', 'Observacion');  -- queda ESPERANDO
--   [3] SESION A:  UPDATE cita SET id_estado = 3 WHERE id_cita = X;  COMMIT;   -- libera el bloqueo
--   [4] SESION B:  termina con ERROR 1644: Solo se puede atender una cita en estado Programada
--                  (vio la cancelacion ya confirmada; no se creo el historial)
--   [5] SELECT * FROM log_errores ORDER BY id DESC LIMIT 1;   -- el error de B quedo registrado
--   Si A no confirma en 30 s, B recibe ERROR 1205 (Lock wait timeout exceeded).
--
-- B.2 Recurso en disputa: LA AGENDA DEL MEDICO (ultimo cupo de un horario).
--     sp_agendar_cita bloquea la fila del medico con FOR UPDATE antes de revisar
--     la disponibilidad, de modo que las reservas del mismo medico se atienden de a una.
--   [1] SESION A:  START TRANSACTION;
--                  SELECT id_medico FROM medico WHERE id_medico = 1 FOR UPDATE;   -- A toma la agenda
--   [2] SESION B:  SET SESSION innodb_lock_wait_timeout = 30;
--                  CALL sp_agendar_cita(2, 1, '<LUNES>', '11:00', 'PRUEBA B', @id);  -- queda ESPERANDO
--   [3] SESION A:  INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo)
--                  VALUES (1, 1, '<LUNES>', '11:00', 'PRUEBA A');
--                  COMMIT;
--   [4] SESION B:  termina con ERROR 1644: El medico no esta disponible en esa fecha y hora...
--   [5] SELECT id_cita, hora, motivo FROM cita WHERE id_medico = 1 AND fecha = '<LUNES>' AND hora = '11:00';
--                  -- una sola cita (la de A)
--
-- =====================================================================
-- C. SEGURIDAD con tres usuarios de roles distintos (manual; capturas).
-- Las contraseñas están en scripts/.respaldo.env. Conectar con:
--   docker exec -it citas_mariadb mariadb -u <usuario> -p proyecto_citas
--
-- lector_citas (rol_consulta_citas):
--   SELECT CURRENT_USER(), CURRENT_ROLE();
--   SELECT * FROM vw_pacientes_publico LIMIT 5;     -- Permitido (datos enmascarados)
--   SELECT * FROM paciente;                          -- Denegado (ERROR 1142)
--   CALL sp_cancelar_cita(1);                        -- Denegado (ERROR 1370)
-- recepcion_citas (rol_recepcion_citas):
--   CALL sp_agendar_cita_segura('1112345601', 1, '<LUNES>', '12:00', 'Control');  -- Permitido
--   SELECT * FROM vw_citas_detalle ORDER BY id_cita DESC LIMIT 3;                 -- Permitido
--   INSERT INTO cita (id_paciente,id_medico,fecha,hora) VALUES (1,1,'<LUNES>','12:30');  -- Denegado (ERROR 1142)
--   SELECT documento FROM paciente;                  -- Denegado (solo ve la vista enmascarada)
-- gestor_citas (rol_admin_citas):
--   UPDATE paciente SET telefono = '3112223344' WHERE id_paciente = 2;  -- Permitido (queda auditado)
--   SELECT * FROM auditoria_paciente ORDER BY id DESC LIMIT 3;          -- Permitido (aparece gestor_citas)
--   DELETE FROM auditoria_paciente;                  -- Denegado (ERROR 1142): no puede borrar la evidencia
--   TRUNCATE auditoria_paciente;                     -- Denegado (sin privilegio DROP)
--   DROP TABLE recordatorio;                         -- Denegado
--   CREATE USER 'intruso'@'%' IDENTIFIED BY 'Intruso#2026';  -- Denegado (ERROR 1227)
-- Política de contraseñas (como root; debe fallar con ERROR 1819):
--   CREATE USER 'prueba_debil'@'%' IDENTIFIED BY '12345';
-- =====================================================================
