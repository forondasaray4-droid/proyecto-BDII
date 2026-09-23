-- =========================================================
-- Archivo: datos_prueba.sql
-- Datos de prueba (mínimo 10 registros por tabla)
-- =========================================================
USE proyecto_citas;

-- 1. Centros de salud (nombres ficticios)
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
('Centro de Salud Modelo',       'Carrera 6 # 14-22, Modelo',     '6022110010');

-- 2. Especialidades
INSERT INTO especialidad (nombre, descripcion) VALUES
('Medicina General', 'Atención primaria y valoración general del paciente'),
('Pediatría',        'Atención médica de niños y adolescentes'),
('Cardiología',      'Diagnóstico y tratamiento de enfermedades del corazón'),
('Ginecología',      'Salud del sistema reproductor femenino'),
('Odontología',      'Diagnóstico y tratamiento de la salud oral'),
('Dermatología',     'Enfermedades de la piel, cabello y uñas'),
('Psicología',       'Atención en salud mental y emocional'),
('Nutrición',        'Planes de alimentación y control nutricional'),
('Oftalmología',     'Diagnóstico y tratamiento de enfermedades de los ojos'),
('Ortopedia',        'Lesiones y enfermedades del sistema musculoesquelético');

-- 3. Médicos
INSERT INTO medico (documento, nombre, apellido, telefono, correo, horario_inicio, horario_fin, id_especialidad, id_centro) VALUES
('1112000001', 'Andrés',    'Gómez',    '3104000001', 'andres.gomez@salud.com',     '07:00', '13:00', 1,  1),
('1112000002', 'Laura',     'Martínez', '3104000002', 'laura.martinez@salud.com',   '08:00', '12:00', 2,  2),
('1112000003', 'Carlos',    'Ramírez',  '3104000003', 'carlos.ramirez@salud.com',   '13:00', '18:00', 3,  3),
('1112000004', 'Diana',     'López',    '3104000004', 'diana.lopez@salud.com',      '07:00', '12:00', 4,  4),
('1112000005', 'Felipe',    'Torres',   '3104000005', 'felipe.torres@salud.com',    '08:00', '16:00', 5,  5),
('1112000006', 'Valentina', 'Rojas',    '3104000006', 'valentina.rojas@salud.com',  '14:00', '18:00', 6,  6),
('1112000007', 'Santiago',  'Herrera',  '3104000007', 'santiago.herrera@salud.com', '08:00', '14:00', 7,  7),
('1112000008', 'Camila',    'Castro',   '3104000008', 'camila.castro@salud.com',    '09:00', '15:00', 8,  8),
('1112000009', 'Julián',    'Moreno',   '3104000009', 'julian.moreno@salud.com',    '07:00', '11:00', 9,  9),
('1112000010', 'Paula',     'Vargas',   '3104000010', 'paula.vargas@salud.com',     '13:00', '19:00', 10, 10);

-- 4. Pacientes
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

-- 5. Citas (10 atendidas, 1 cancelada, 1 no asistió, 3 programadas)
INSERT INTO cita (id_paciente, id_medico, fecha, hora, motivo, estado) VALUES
(1,  1,  '2026-08-03', '08:00', 'Control general',        'Atendida'),
(2,  2,  '2026-08-05', '09:00', 'Fiebre persistente',     'Atendida'),
(3,  3,  '2026-08-10', '14:00', 'Dolor en el pecho',      'Atendida'),
(4,  4,  '2026-08-12', '08:30', 'Control prenatal',       'Atendida'),
(5,  5,  '2026-08-18', '10:00', 'Dolor de muela',         'Atendida'),
(6,  6,  '2026-08-24', '15:00', 'Brote en la piel',       'Atendida'),
(7,  7,  '2026-08-31', '09:00', 'Episodios de ansiedad',  'Atendida'),
(8,  8,  '2026-09-04', '11:00', 'Plan alimenticio',       'Atendida'),
(9,  9,  '2026-09-09', '07:30', 'Visión borrosa',         'Atendida'),
(10, 10, '2026-09-15', '16:00', 'Dolor de rodilla',       'Atendida'),
(1,  3,  '2026-09-17', '15:00', 'Control cardiológico',   'Cancelada'),
(3,  1,  '2026-09-18', '10:00', 'Chequeo de presión',     'No asistio'),
(5,  1,  '2026-09-28', '09:00', 'Control general',        'Programada'),
(2,  2,  '2026-09-30', '10:30', 'Control de crecimiento', 'Programada'),
(7,  7,  '2026-10-02', '11:00', 'Seguimiento',            'Programada');

-- 6. Historial médico (uno por cada cita atendida: citas 1 a 10)
INSERT INTO historial_medico (id_cita, diagnostico, tratamiento, observaciones, fecha_registro) VALUES
(1,  'Paciente sano',                     'Ninguno',                               'Se recomienda control anual',          '2026-08-03 08:30'),
(2,  'Infección respiratoria leve',       'Acetaminofén pediátrico cada 8 horas',  'Control si la fiebre persiste 3 días', '2026-08-05 09:30'),
(3,  'Angina estable',                    'Nitroglicerina sublingual',             'Se ordena electrocardiograma',         '2026-08-10 14:40'),
(4,  'Embarazo de 20 semanas sin riesgo', 'Ácido fólico y hierro',                 'Próximo control en 4 semanas',         '2026-08-12 09:00'),
(5,  'Caries en molar inferior',          'Obturación con resina',                 'Evitar alimentos duros por 24 horas',  '2026-08-18 10:45'),
(6,  'Dermatitis de contacto',            'Crema de hidrocortisona al 1%',         'Evitar detergentes fuertes',           '2026-08-24 15:30'),
(7,  'Trastorno de ansiedad leve',        'Terapia cognitivo-conductual semanal',  'Seguimiento en 1 mes',                 '2026-08-31 10:00'),
(8,  'Sobrepeso grado I',                 'Dieta hipocalórica y actividad física', 'Control de peso mensual',              '2026-09-04 11:40'),
(9,  'Miopía leve',                       'Uso de lentes formulados',              'Revisión en 1 año',                    '2026-09-09 08:00'),
(10, 'Esguince de rodilla grado I',       'Reposo, hielo y antiinflamatorio',      'Terapia física si no mejora',          '2026-09-15 16:45');

-- 7. Recordatorios (un día antes de cada cita)
INSERT INTO recordatorio (id_cita, mensaje, fecha_envio, estado) VALUES
(6,  'Recuerde su cita de Dermatología mañana a las 15:00',     '2026-08-23 15:00', 'Enviado'),
(7,  'Recuerde su cita de Psicología mañana a las 09:00',       '2026-08-30 09:00', 'Enviado'),
(8,  'Recuerde su cita de Nutrición mañana a las 11:00',        '2026-09-03 11:00', 'Enviado'),
(9,  'Recuerde su cita de Oftalmología mañana a las 07:30',     '2026-09-08 07:30', 'Enviado'),
(10, 'Recuerde su cita de Ortopedia mañana a las 16:00',        '2026-09-14 16:00', 'Enviado'),
(11, 'Recuerde su cita de Cardiología mañana a las 15:00',      '2026-09-16 15:00', 'Cancelado'),
(12, 'Recuerde su cita de Medicina General mañana a las 10:00', '2026-09-17 10:00', 'Enviado'),
(13, 'Recuerde su cita de Medicina General mañana a las 09:00', '2026-09-27 09:00', 'Pendiente'),
(14, 'Recuerde su cita de Pediatría mañana a las 10:30',        '2026-09-29 10:30', 'Pendiente'),
(15, 'Recuerde su cita de Psicología mañana a las 11:00',       '2026-10-01 11:00', 'Pendiente');