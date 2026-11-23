-- =====================================================================
-- 09_eventos.sql  -  Eventos programados (requieren event_scheduler = ON;
-- docker-compose.yml lo activa con --event-scheduler=ON)
--   ev_marcar_citas_vencidas : cada día a las 23:55 marca como "No asistio"
--                              las citas Programadas cuya fecha ya pasó
--   ev_enviar_recordatorios  : cada hora marca como Enviado los recordatorios
--                              pendientes cuya fecha de envío llegó
-- Ambos registran lo que hicieron en la tabla log_eventos.
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

DROP EVENT IF EXISTS ev_marcar_citas_vencidas;
DROP EVENT IF EXISTS ev_enviar_recordatorios;

CREATE EVENT ev_marcar_citas_vencidas
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATE + INTERVAL 23 HOUR + INTERVAL 55 MINUTE
COMMENT 'Marca como No asistio las citas Programadas con fecha pasada'
DO CALL sp_marcar_citas_vencidas();

CREATE EVENT ev_enviar_recordatorios
ON SCHEDULE EVERY 1 HOUR
STARTS NOW() + INTERVAL 1 HOUR
COMMENT 'Envia los recordatorios pendientes cuya fecha de envio llego'
DO CALL sp_enviar_recordatorios();

SHOW VARIABLES LIKE 'event_scheduler';
SELECT EVENT_NAME, STATUS, INTERVAL_VALUE, INTERVAL_FIELD, STARTS, LAST_EXECUTED
  FROM information_schema.EVENTS
 WHERE EVENT_SCHEMA = 'proyecto_citas';

-- ---------------------------------------------------------------------
-- DEMOSTRACIÓN (para la sustentación o las capturas): un evento que se ejecuta
-- cada 10 segundos y se detiene solo a los 2 minutos. Esperar ~30 s y consultar:
--   SELECT * FROM log_eventos ORDER BY id DESC LIMIT 5;
--   SELECT EVENT_NAME, STATUS, LAST_EXECUTED FROM information_schema.EVENTS
--    WHERE EVENT_SCHEMA = 'proyecto_citas';
-- También sirve para forzar un evento real: ALTER EVENT ev_enviar_recordatorios
--   ON SCHEDULE EVERY 10 SECOND;   (y después volver a EVERY 1 HOUR)
-- ---------------------------------------------------------------------
-- DROP EVENT IF EXISTS ev_demo_latido;
-- CREATE EVENT ev_demo_latido
-- ON SCHEDULE EVERY 10 SECOND
-- ENDS CURRENT_TIMESTAMP + INTERVAL 2 MINUTE
-- DO INSERT INTO log_eventos (evento, detalle)
--    VALUES ('ev_demo_latido', CONCAT('Citas programadas: ',
--            (SELECT COUNT(*) FROM cita WHERE id_estado = 1)));
