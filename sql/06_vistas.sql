-- =====================================================================
-- 06_vistas.sql  -  Vistas
--   vw_pacientes_publico : enmascara documento, teléfono y correo
--   vw_citas_detalle     : reporte con JOIN de 6 tablas
--   vw_resumen_centro    : citas por centro de salud y estado (JOIN + GROUP BY)
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

-- 1. Vista con enmascaramiento de datos (usa fn_enmascarar y fn_clasificar_edad)
CREATE OR REPLACE SQL SECURITY DEFINER VIEW vw_pacientes_publico AS
SELECT p.id_paciente,
       p.nombre,
       p.apellido,
       fn_enmascarar(p.documento, 4) AS documento,
       fn_enmascarar(p.telefono, 4)  AS telefono,
       CONCAT(LEFT(p.correo, 2), '***', SUBSTRING(p.correo, LOCATE('@', p.correo))) AS correo,
       fn_clasificar_edad(TIMESTAMPDIFF(YEAR, p.fecha_nacimiento, CURDATE()))       AS categoria_edad
  FROM paciente p;

-- 2. Vista de reporte: une cita, estado, paciente, médico, especialidad y centro
CREATE OR REPLACE SQL SECURITY DEFINER VIEW vw_citas_detalle AS
SELECT c.id_cita,
       c.fecha,
       c.hora,
       e.nombre                          AS estado,
       CONCAT(p.nombre, ' ', p.apellido) AS paciente,
       CONCAT(m.nombre, ' ', m.apellido) AS medico,
       esp.nombre                        AS especialidad,
       cs.nombre                         AS centro_salud
  FROM cita c
 INNER JOIN estado_cita  e   ON e.id_estado        = c.id_estado
 INNER JOIN paciente     p   ON p.id_paciente      = c.id_paciente
 INNER JOIN medico       m   ON m.id_medico        = c.id_medico
 INNER JOIN especialidad esp ON esp.id_especialidad = m.id_especialidad
 INNER JOIN centro_salud cs  ON cs.id_centro       = m.id_centro;

-- 3. Vista de gestión: cuántas citas tiene cada centro según su estado
CREATE OR REPLACE SQL SECURITY DEFINER VIEW vw_resumen_centro AS
SELECT cs.id_centro,
       cs.nombre AS centro_salud,
       e.nombre  AS estado,
       COUNT(*)  AS total_citas
  FROM cita c
 INNER JOIN medico       m  ON m.id_medico = c.id_medico
 INNER JOIN centro_salud cs ON cs.id_centro = m.id_centro
 INNER JOIN estado_cita  e  ON e.id_estado = c.id_estado
 GROUP BY cs.id_centro, cs.nombre, e.nombre;
