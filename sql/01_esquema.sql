-- =====================================================================
-- 01_esquema.sql  -  Esquema de la base de datos proyecto_citas
-- Proyecto: Sistema de gestión de citas - Centros de salud de Cartago
-- Autora:   Saray Foronda Restrepo  |  Bases de Datos II (COTECNOVA, 2026)
--
-- ATENCIÓN: recrea la base desde cero (DROP DATABASE). Úsese en la
-- instalación inicial o para reinstalar; borra los datos existentes.
-- =====================================================================
SET NAMES utf8mb4;

DROP DATABASE IF EXISTS proyecto_citas;
CREATE DATABASE proyecto_citas CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE proyecto_citas;

-- 1. Centros de salud
CREATE TABLE centro_salud (
  id_centro INT AUTO_INCREMENT PRIMARY KEY,
  nombre    VARCHAR(100) NOT NULL UNIQUE,
  direccion VARCHAR(150) NOT NULL,
  telefono  VARCHAR(15)
) ENGINE = InnoDB;

-- 2. Especialidades
CREATE TABLE especialidad (
  id_especialidad INT AUTO_INCREMENT PRIMARY KEY,
  nombre          VARCHAR(60) NOT NULL UNIQUE,
  descripcion     VARCHAR(255)
) ENGINE = InnoDB;

-- 3. Catálogo de estados de la cita (retroalimentación del Avance 1:
--    antes era un ENUM; ahora se pueden agregar estados sin alterar la tabla cita)
CREATE TABLE estado_cita (
  id_estado   TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(20)  NOT NULL UNIQUE,
  descripcion VARCHAR(100)
) ENGINE = InnoDB;

-- 4. Médicos (cada médico trabaja en un solo centro)
CREATE TABLE medico (
  id_medico       INT AUTO_INCREMENT PRIMARY KEY,
  documento       VARCHAR(15) NOT NULL UNIQUE,
  nombre          VARCHAR(50) NOT NULL,
  apellido        VARCHAR(50) NOT NULL,
  telefono        VARCHAR(15),
  correo          VARCHAR(100),
  id_especialidad INT NOT NULL,
  id_centro       INT NOT NULL,
  CONSTRAINT fk_medico_especialidad FOREIGN KEY (id_especialidad) REFERENCES especialidad (id_especialidad),
  CONSTRAINT fk_medico_centro       FOREIGN KEY (id_centro)       REFERENCES centro_salud (id_centro)
) ENGINE = InnoDB;

-- 5. Franjas horarias por médico (retroalimentación del Avance 1:
--    reemplaza el único horario_inicio/horario_fin; permite varias franjas por día)
--    dia_semana: 1 = lunes ... 7 = domingo (igual a WEEKDAY() + 1)
CREATE TABLE franja_horaria (
  id_franja   INT AUTO_INCREMENT PRIMARY KEY,
  id_medico   INT     NOT NULL,
  dia_semana  TINYINT NOT NULL,
  hora_inicio TIME    NOT NULL,
  hora_fin    TIME    NOT NULL,
  CONSTRAINT fk_franja_medico  FOREIGN KEY (id_medico) REFERENCES medico (id_medico),
  CONSTRAINT chk_franja_dia    CHECK (dia_semana BETWEEN 1 AND 7),
  CONSTRAINT chk_franja_horas  CHECK (hora_fin > hora_inicio),
  CONSTRAINT uq_franja         UNIQUE (id_medico, dia_semana, hora_inicio)
) ENGINE = InnoDB;

-- 6. Pacientes (sal y pin_hash: PIN del portal con hash SHA-256 y sal propia)
CREATE TABLE paciente (
  id_paciente      INT AUTO_INCREMENT PRIMARY KEY,
  documento        VARCHAR(15) NOT NULL UNIQUE,
  nombre           VARCHAR(50) NOT NULL,
  apellido         VARCHAR(50) NOT NULL,
  fecha_nacimiento DATE NOT NULL,
  telefono         VARCHAR(15),
  correo           VARCHAR(100),
  direccion        VARCHAR(150),
  sal              CHAR(16) NULL,
  pin_hash         CHAR(64) NULL
) ENGINE = InnoDB;

-- 7. Citas (tabla transaccional principal)
--    A propósito NO se declaran aquí índices adicionales a los que InnoDB crea
--    por cada llave foránea: los demás se crean y justifican en 08_indices.sql.
CREATE TABLE cita (
  id_cita     INT AUTO_INCREMENT PRIMARY KEY,
  id_paciente INT NOT NULL,
  id_medico   INT NOT NULL,
  fecha       DATE NOT NULL,
  hora        TIME NOT NULL,
  motivo      VARCHAR(255),
  id_estado   TINYINT UNSIGNED NOT NULL DEFAULT 1,   -- 1 = Programada
  CONSTRAINT fk_cita_paciente FOREIGN KEY (id_paciente) REFERENCES paciente (id_paciente),
  CONSTRAINT fk_cita_medico   FOREIGN KEY (id_medico)   REFERENCES medico (id_medico),
  CONSTRAINT fk_cita_estado   FOREIGN KEY (id_estado)   REFERENCES estado_cita (id_estado)
) ENGINE = InnoDB;

-- 8. Historial médico (1:1 con la cita atendida). Las observaciones se
--    guardan SOLO cifradas con AES (columna sensible).
CREATE TABLE historial_medico (
  id_historial          INT AUTO_INCREMENT PRIMARY KEY,
  id_cita               INT NOT NULL UNIQUE,
  diagnostico           VARCHAR(255) NOT NULL,
  tratamiento           VARCHAR(255),
  observaciones_cifrado VARBINARY(512) NULL,
  fecha_registro        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_historial_cita FOREIGN KEY (id_cita) REFERENCES cita (id_cita)
) ENGINE = InnoDB;

-- 9. Recordatorios (los genera el trigger trg_generar_recordatorio)
CREATE TABLE recordatorio (
  id_recordatorio INT AUTO_INCREMENT PRIMARY KEY,
  id_cita         INT NOT NULL,
  mensaje         VARCHAR(255) NOT NULL,
  fecha_envio     DATETIME NOT NULL,
  estado          ENUM('Pendiente', 'Enviado', 'Cancelado') NOT NULL DEFAULT 'Pendiente',
  CONSTRAINT fk_recordatorio_cita FOREIGN KEY (id_cita) REFERENCES cita (id_cita)
) ENGINE = InnoDB;

-- 10. Auditoría de cambios sobre paciente (sin llave foránea para conservar
--     el historial aunque el paciente se elimine). Es de SOLO LECTURA para el
--     administrador y está protegida por triggers (ver 05_triggers.sql).
CREATE TABLE auditoria_paciente (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  id_paciente         INT          NOT NULL,
  campo               VARCHAR(30)  NOT NULL,
  valor_anterior      VARCHAR(150),
  valor_nuevo         VARCHAR(150),
  usuario_sesion      VARCHAR(100) NOT NULL,
  usuario_privilegios VARCHAR(100) NOT NULL,
  fecha               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- 11. Errores capturados por los procedimientos transaccionales
CREATE TABLE log_errores (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  procedimiento VARCHAR(60) NOT NULL,
  codigo        INT,
  estado_sql    CHAR(5),
  mensaje       VARCHAR(255),
  usuario       VARCHAR(100) NOT NULL,
  fecha         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- 12. Registro de las tareas ejecutadas por los eventos programados
CREATE TABLE log_eventos (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  evento  VARCHAR(60) NOT NULL,
  detalle VARCHAR(255),
  fecha   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;
