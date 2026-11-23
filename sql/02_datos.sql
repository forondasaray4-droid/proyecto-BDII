-- =====================================================================
-- 02_datos.sql  -  Datos de prueba (nombres ficticios)
--   20 centros, 20 especialidades, 20 médicos, 2.010 pacientes (tablas maestras)
--   10.015 citas (tabla transaccional principal), sus recordatorios e historiales
--
-- Requiere las variables de sesión @llave_aes y @pin_demo (las define
-- instalar.sh a partir de scripts/.respaldo.env; no se escriben en el código).
-- En este punto aún no existen triggers: los datos se generan ya válidos
-- (dentro de la franja del médico y sin choques de agenda).
-- =====================================================================
SET NAMES utf8mb4;
USE proyecto_citas;

DELIMITER $$
CREATE PROCEDURE sp_tmp_verificar_variables()
BEGIN
  IF @llave_aes IS NULL OR @pin_demo IS NULL THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Defina @llave_aes y @pin_demo (ver scripts/respaldo.env.ejemplo)';
  END IF;
END$$
DELIMITER ;
CALL sp_tmp_verificar_variables();
DROP PROCEDURE sp_tmp_verificar_variables;

-- ---------------------------------------------------------------------
-- Catálogo de estados de la cita (los ids se usan como DEFAULT en cita)
-- ---------------------------------------------------------------------
INSERT INTO estado_cita (id_estado, nombre, descripcion) VALUES
(1, 'Programada', 'Cita agendada, pendiente de atención'),
(2, 'Atendida',   'El paciente fue atendido y tiene historial'),
(3, 'Cancelada',  'Cancelada o reprogramada; libera el horario del médico'),
(4, 'No asistio', 'El paciente no asistió a la cita');

-- ---------------------------------------------------------------------
-- Tablas maestras
-- ---------------------------------------------------------------------
INSERT INTO centro_salud (nombre, direccion, telefono) VALUES
('Centro de Salud San Jerónimo', 'Calle 10 # 5-20, San Jerónimo', '6022110001'),
('Centro de Salud El Prado',     'Carrera 4 # 18-35, El Prado',   '6022110002'),
('Centro de Salud Santa Ana',    'Calle 13 # 7-40, Santa Ana',    '6022110003'),
('Centro de Salud Zaragoza',     'Vía Principal, Zaragoza',       '6022110004'),
('Centro de Salud Guadalupe',    'Calle 22 # 3-15, Guadalupe',    '6022110005'),
('Centro de Salud Bellavista',   'Carrera 9 # 30-12, Bellavista', '6022110006'),
('Centro de Salud La Ortez',     'Calle 5 # 1-60, La Ortez',      '6022110007'),
('Centro de Salud Samaria',      'Carrera 12 # 25-08, Samaria',   '6022110008'),
('Centro de Salud El Llano',     'Calle 16 # 11-45, El Llano',    '6022110009'),
('Centro de Salud Modelo',       'Carrera 6 # 14-22, Modelo',     '6022110010'),
('Centro de Salud Altozano',     'Calle 8 # 20-14, Altozano',     '6022110011'),
('Centro de Salud Las Colinas',  'Carrera 2 # 9-31, Las Colinas', '6022110012'),
('Centro de Salud Villa Colombia','Calle 27 # 4-18, Villa Colombia','6022110013'),
('Centro de Salud Los Andes',    'Carrera 14 # 17-26, Los Andes', '6022110014'),
('Centro de Salud San Vicente',  'Calle 19 # 8-52, San Vicente',  '6022110015'),
('Centro de Salud Piedras de Moler','Vía Piedras de Moler km 2',  '6022110016'),
('Centro de Salud Coloradas',    'Calle 31 # 6-09, Coloradas',    '6022110017'),
('Centro de Salud Cauca Viejo',  'Carrera 8 # 33-47, Cauca Viejo','6022110018'),
('Centro de Salud La Grecia',    'Calle 12 # 15-60, La Grecia',   '6022110019'),
('Centro de Salud Pueblo Nuevo', 'Carrera 10 # 21-13, Pueblo Nuevo','6022110020');

INSERT INTO especialidad (nombre, descripcion) VALUES
('Medicina General',   'Atención primaria y valoración general del paciente'),
('Pediatría',          'Atención médica de niños y adolescentes'),
('Cardiología',        'Diagnóstico y tratamiento de enfermedades del corazón'),
('Ginecología',        'Salud del sistema reproductor femenino'),
('Odontología',        'Diagnóstico y tratamiento de la salud oral'),
('Dermatología',       'Enfermedades de la piel, cabello y uñas'),
('Psicología',         'Atención en salud mental y emocional'),
('Nutrición',          'Planes de alimentación y control nutricional'),
('Oftalmología',       'Diagnóstico y tratamiento de enfermedades de los ojos'),
('Ortopedia',          'Lesiones y enfermedades del sistema musculoesquelético'),
('Neurología',         'Enfermedades del sistema nervioso'),
('Urología',           'Salud del sistema urinario y reproductor masculino'),
('Otorrinolaringología','Oído, nariz y garganta'),
('Gastroenterología',  'Enfermedades del aparato digestivo'),
('Endocrinología',     'Trastornos hormonales y metabólicos'),
('Neumología',         'Enfermedades de los pulmones y vías respiratorias'),
('Reumatología',       'Enfermedades de articulaciones y autoinmunes'),
('Psiquiatría',        'Diagnóstico y tratamiento de trastornos mentales'),
('Fisioterapia',       'Rehabilitación física y del movimiento'),
('Medicina Interna',   'Atención integral del adulto');

INSERT INTO medico (documento, nombre, apellido, telefono, correo, id_especialidad, id_centro) VALUES
('1112000001', 'Andrés',    'Gómez',    '3104000001', 'andres.gomez@salud.com',     1,  1),
('1112000002', 'Laura',     'Martínez', '3104000002', 'laura.martinez@salud.com',   2,  2),
('1112000003', 'Carlos',    'Ramírez',  '3104000003', 'carlos.ramirez@salud.com',   3,  3),
('1112000004', 'Diana',     'López',    '3104000004', 'diana.lopez@salud.com',      4,  4),
('1112000005', 'Felipe',    'Torres',   '3104000005', 'felipe.torres@salud.com',    5,  5),
('1112000006', 'Valentina', 'Rojas',    '3104000006', 'valentina.rojas@salud.com',  6,  6),
('1112000007', 'Santiago',  'Herrera',  '3104000007', 'santiago.herrera@salud.com', 7,  7),
('1112000008', 'Camila',    'Castro',   '3104000008', 'camila.castro@salud.com',    8,  8),
('1112000009', 'Julián',    'Moreno',   '3104000009', 'julian.moreno@salud.com',    9,  9),
('1112000010', 'Paula',     'Vargas',   '3104000010', 'paula.vargas@salud.com',     10, 10),
('1112000011', 'Mateo',     'Zapata',   '3104000011', 'mateo.zapata@salud.com',     11, 11),
('1112000012', 'Lucía',     'Duque',    '3104000012', 'lucia.duque@salud.com',      12, 12),
('1112000013', 'Sebastián', 'Parra',    '3104000013', 'sebastian.parra@salud.com',  13, 13),
('1112000014', 'Mariana',   'Ocampo',   '3104000014', 'mariana.ocampo@salud.com',   14, 14),
('1112000015', 'Nicolás',   'Bedoya',   '3104000015', 'nicolas.bedoya@salud.com',   15, 15),
('1112000016', 'Elena',     'Cifuentes','3104000016', 'elena.cifuentes@salud.com',  16, 16),
('1112000017', 'Tomás',     'Aguirre',  '3104000017', 'tomas.aguirre@salud.com',    17, 17),
('1112000018', 'Gabriela',  'Londoño',  '3104000018', 'gabriela.londono@salud.com', 18, 18),
('1112000019', 'Esteban',   'Marín',    '3104000019', 'esteban.marin@salud.com',    19, 19),
('1112000020', 'Alejandra', 'Soto',     '3104000020', 'alejandra.soto@salud.com',   20, 20);

-- Franjas horarias: lunes a viernes (días 1 a 5) con el horario de cada médico
INSERT INTO franja_horaria (id_medico, dia_semana, hora_inicio, hora_fin)
SELECT h.id_medico, d.seq, h.ini, h.fin
  FROM (SELECT  1 AS id_medico, '07:00' AS ini, '13:00' AS fin UNION ALL
        SELECT  2, '08:00', '12:00' UNION ALL SELECT  3, '13:00', '18:00' UNION ALL
        SELECT  4, '07:00', '12:00' UNION ALL SELECT  5, '08:00', '16:00' UNION ALL
        SELECT  6, '14:00', '18:00' UNION ALL SELECT  7, '08:00', '14:00' UNION ALL
        SELECT  8, '09:00', '15:00' UNION ALL SELECT  9, '07:00', '11:00' UNION ALL
        SELECT 10, '13:00', '19:00' UNION ALL
        SELECT 11, '07:00', '11:00' UNION ALL SELECT 11, '14:00', '18:00' UNION ALL
        SELECT 12, '07:00', '11:00' UNION ALL SELECT 12, '14:00', '18:00' UNION ALL
        SELECT 13, '07:00', '11:00' UNION ALL SELECT 13, '14:00', '18:00' UNION ALL
        SELECT 14, '07:00', '11:00' UNION ALL SELECT 14, '14:00', '18:00' UNION ALL
        SELECT 15, '07:00', '11:00' UNION ALL SELECT 15, '14:00', '18:00' UNION ALL
        SELECT 16, '08:00', '12:00' UNION ALL SELECT 17, '08:00', '12:00' UNION ALL
        SELECT 18, '08:00', '12:00' UNION ALL SELECT 19, '08:00', '12:00' UNION ALL
        SELECT 20, '08:00', '12:00') h
  CROSS JOIN seq_1_to_5 d;

-- Franjas de los sábados (días 6) para dos médicos
INSERT INTO franja_horaria (id_medico, dia_semana, hora_inicio, hora_fin) VALUES
(1, 6, '08:00', '12:00'),
(16, 6, '08:00', '12:00');

-- ---------------------------------------------------------------------
-- Pacientes: 10 con datos propios + 2.000 generados
-- ---------------------------------------------------------------------
INSERT INTO paciente (documento, nombre, apellido, fecha_nacimiento, telefono, correo, direccion) VALUES
('1112345601', 'Juan',     'Pérez',    '1985-03-12', '3151000001', 'juan.perez@mail.com',       'Calle 8 # 4-10, Cartago'),
('1112345602', 'Sofía',    'Ospina',   '2019-06-25', '3151000002', 'acudiente.ospina@mail.com', 'Carrera 5 # 20-15, Cartago'),
('1112345603', 'Luis',     'Cardona',  '1958-11-02', '3151000003', 'luis.cardona@mail.com',     'Calle 12 # 9-30, Cartago'),
('1112345604', 'María',    'Giraldo',  '1994-01-18', '3151000004', 'maria.giraldo@mail.com',    'Carrera 7 # 15-22, Cartago'),
('1112345605', 'Jorge',    'Valencia', '1976-09-09', '3151000005', 'jorge.valencia@mail.com',   'Calle 20 # 6-18, Cartago'),
('1112345606', 'Natalia',  'Restrepo', '2001-04-30', '3151000006', 'natalia.restrepo@mail.com', 'Carrera 3 # 11-40, Cartago'),
('1112345607', 'Daniel',   'Quintero', '1990-12-05', '3151000007', 'daniel.quintero@mail.com',  'Calle 25 # 10-05, Cartago'),
('1112345608', 'Carolina', 'Muñoz',    '1988-07-14', '3151000008', 'carolina.munoz@mail.com',   'Carrera 11 # 8-33, Cartago'),
('1112345609', 'Hernando', 'Salazar',  '1950-02-21', '3151000009', NULL,                        'Vereda Zaragoza, Cartago'),
('1112345610', 'Isabela',  'Arango',   '1999-10-08', '3151000010', 'isabela.arango@mail.com',   'Calle 30 # 12-50, Cartago');

INSERT INTO paciente (documento, nombre, apellido, fecha_nacimiento, telefono, correo, direccion)
SELECT CONCAT('1100', LPAD(seq, 6, '0')),
       ELT(1 + seq % 20, 'Carlos','Ana','Miguel','Laura','Pedro','Marta','Andrés','Paula','Diego','Sara',
                         'Camilo','Juliana','Felipe','Daniela','Mauricio','Viviana','Óscar','Lina','Iván','Karen'),
       ELT(1 + (seq * 7) % 20, 'García','Rodríguez','López','Martínez','Gómez','Díaz','Hernández','Vargas',
                               'Ramírez','Torres','Castro','Rojas','Ortiz','Cardona','Arias','Suárez',
                               'Mejía','Bedoya','Osorio','Franco'),
       DATE('1940-01-01') + INTERVAL ((seq * 37) % 27000) DAY,
       CONCAT('315', LPAD(seq, 7, '0')),
       CONCAT('paciente', seq, '@mail.com'),
       CONCAT('Calle ', 1 + seq % 40, ' # ', 1 + seq % 20, '-', 10 + seq % 80, ', Cartago')
  FROM seq_1_to_2000;

-- Datos sensibles: PIN con hash SHA-256 y sal aleatoria por paciente.
-- (El PIN de práctica sale de @pin_demo; con sal distinta cada hash es distinto.)
UPDATE paciente SET sal = LEFT(SHA2(CONCAT(UUID(), id_paciente), 256), 16) WHERE id_paciente > 0;
UPDATE paciente SET pin_hash = SHA2(CONCAT(sal, @pin_demo), 256) WHERE id_paciente > 0;

-- ---------------------------------------------------------------------
-- Citas con datos propios (estados: 1 Programada, 2 Atendida, 3 Cancelada, 4 No asistio)
-- ---------------------------------------------------------------------
INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo, id_estado) VALUES
(1,  1,  '2026-08-03', '08:00', 'Control general',        2),
(2,  2,  '2026-08-05', '09:00', 'Fiebre persistente',     2),
(3,  3,  '2026-08-10', '14:00', 'Dolor en el pecho',      2),
(4,  4,  '2026-08-12', '08:30', 'Control prenatal',       2),
(5,  5,  '2026-08-18', '10:00', 'Dolor de muela',         2),
(6,  6,  '2026-08-24', '15:00', 'Brote en la piel',       2),
(7,  7,  '2026-08-31', '09:00', 'Episodios de ansiedad',  2),
(8,  8,  '2026-09-04', '11:00', 'Plan alimenticio',       2),
(9,  9,  '2026-09-09', '07:30', 'Visión borrosa',         2),
(10, 10, '2026-09-15', '16:00', 'Dolor de rodilla',       2),
(1,  3,  '2026-09-17', '15:00', 'Control cardiológico',   3),
(3,  1,  '2026-09-18', '10:00', 'Chequeo de presión',     4),
(5,  1,  '2026-12-01', '09:00', 'Control general',        1),
(2,  2,  '2026-12-02', '10:30', 'Control de crecimiento', 1),
(7,  7,  '2026-12-04', '11:00', 'Seguimiento',            1);

-- ---------------------------------------------------------------------
-- 10.000 citas generadas con seq_1_to_10000 (enero a junio de 2026).
-- Cada médico recibe 4 citas por día hábil, a horas consecutivas dentro de
-- su primera franja, de modo que ninguna cita choca ni queda fuera de horario.
-- Estados: 80 % Atendida, 10 % Cancelada, 10 % No asistio.
-- ---------------------------------------------------------------------
INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo, id_estado)
SELECT 1 + (s.seq * 7919) % 2010,
       f.id_medico,
       DATE('2026-01-05')
         + INTERVAL ((((s.seq - 1) DIV 80) DIV 5) * 7 + (((s.seq - 1) DIV 80) % 5)) DAY,
       ADDTIME(f.ini, SEC_TO_TIME((((s.seq - 1) DIV 20) % 4) * 3600)),
       ELT(1 + s.seq % 5, 'Control general', 'Dolor de cabeza', 'Revisión de resultados',
                          'Seguimiento', 'Síntomas respiratorios'),
       CASE s.seq % 10 WHEN 0 THEN 4 WHEN 1 THEN 3 ELSE 2 END
  FROM seq_1_to_10000 s
  JOIN (SELECT id_medico, MIN(hora_inicio) AS ini
          FROM franja_horaria GROUP BY id_medico) f
    ON f.id_medico = 1 + (s.seq - 1) % 20
 ORDER BY s.seq;

-- ---------------------------------------------------------------------
-- Historial médico: una fila por cada cita atendida (observaciones cifradas)
-- ---------------------------------------------------------------------
INSERT INTO historial_medico (id_cita, diagnostico, tratamiento, observaciones_cifrado, fecha_registro) VALUES
(1,  'Paciente sano',                     'Ninguno',                               AES_ENCRYPT('Se recomienda control anual',          @llave_aes), '2026-08-03 08:30'),
(2,  'Infección respiratoria leve',       'Acetaminofén pediátrico cada 8 horas',  AES_ENCRYPT('Control si la fiebre persiste 3 días', @llave_aes), '2026-08-05 09:30'),
(3,  'Angina estable',                    'Nitroglicerina sublingual',             AES_ENCRYPT('Se ordena electrocardiograma',         @llave_aes), '2026-08-10 14:40'),
(4,  'Embarazo de 20 semanas sin riesgo', 'Ácido fólico y hierro',                 AES_ENCRYPT('Próximo control en 4 semanas',         @llave_aes), '2026-08-12 09:00'),
(5,  'Caries en molar inferior',          'Obturación con resina',                 AES_ENCRYPT('Evitar alimentos duros por 24 horas',  @llave_aes), '2026-08-18 10:45'),
(6,  'Dermatitis de contacto',            'Crema de hidrocortisona al 1%',         AES_ENCRYPT('Evitar detergentes fuertes',           @llave_aes), '2026-08-24 15:30'),
(7,  'Trastorno de ansiedad leve',        'Terapia cognitivo-conductual semanal',  AES_ENCRYPT('Seguimiento en 1 mes',                 @llave_aes), '2026-08-31 10:00'),
(8,  'Sobrepeso grado I',                 'Dieta hipocalórica y actividad física', AES_ENCRYPT('Control de peso mensual',              @llave_aes), '2026-09-04 11:40'),
(9,  'Miopía leve',                       'Uso de lentes formulados',              AES_ENCRYPT('Revisión en 1 año',                    @llave_aes), '2026-09-09 08:00'),
(10, 'Esguince de rodilla grado I',       'Reposo, hielo y antiinflamatorio',      AES_ENCRYPT('Terapia física si no mejora',          @llave_aes), '2026-09-15 16:45');

INSERT INTO historial_medico (id_cita, diagnostico, tratamiento, observaciones_cifrado, fecha_registro)
SELECT c.id_cita,
       ELT(1 + c.id_cita % 8, 'Control sin hallazgos', 'Hipertensión arterial leve', 'Gripe común',
                              'Gastritis', 'Lumbalgia mecánica', 'Rinitis alérgica',
                              'Cefalea tensional', 'Faringitis aguda'),
       ELT(1 + c.id_cita % 4, 'Reposo e hidratación', 'Medicación formulada', 'Dieta y ejercicio', 'Ninguno'),
       AES_ENCRYPT(CONCAT('Control en ', 1 + c.id_cita % 4, ' semanas'), @llave_aes),
       TIMESTAMP(c.fecha, c.hora) + INTERVAL 30 MINUTE
  FROM cita c
 WHERE c.id_cita > 15 AND c.id_estado = 2;

-- ---------------------------------------------------------------------
-- Recordatorios: uno por cita, un día antes (igual que lo haría el trigger).
-- Programada -> Pendiente | Cancelada -> Cancelado | resto -> Enviado
-- ---------------------------------------------------------------------
INSERT INTO recordatorio (id_cita, mensaje, fecha_envio, estado)
SELECT id_cita,
       CONCAT('Recuerde su cita del ', fecha, ' a las ', hora),
       TIMESTAMP(fecha, hora) - INTERVAL 1 DAY,
       CASE id_estado WHEN 1 THEN 'Pendiente' WHEN 3 THEN 'Cancelado' ELSE 'Enviado' END
  FROM cita;

-- Resumen de la carga
SELECT 'centro_salud' AS tabla, COUNT(*) AS filas FROM centro_salud UNION ALL
SELECT 'especialidad', COUNT(*) FROM especialidad UNION ALL
SELECT 'medico', COUNT(*) FROM medico UNION ALL
SELECT 'paciente', COUNT(*) FROM paciente UNION ALL
SELECT 'cita', COUNT(*) FROM cita UNION ALL
SELECT 'historial_medico', COUNT(*) FROM historial_medico UNION ALL
SELECT 'recordatorio', COUNT(*) FROM recordatorio;
