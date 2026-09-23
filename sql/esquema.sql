-- =========================================================
-- Proyecto: Sistema de gestión de citas - Centros de salud de Cartago
-- Archivo:  esquema.sql
-- =========================================================

CREATE DATABASE IF NOT EXISTS proyecto_citas;
USE proyecto_citas;

-- ---------------------------------------------------------
-- 1. Centros de salud
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS centro_salud (
  id_centro INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  direccion VARCHAR(150) NOT NULL,
  telefono VARCHAR(15)
);

-- ---------------------------------------------------------
-- 2. Especialidades
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS especialidad (
  id_especialidad INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL UNIQUE,
  descripcion VARCHAR(255)
);

-- ---------------------------------------------------------
-- 3. Médicos (cada médico trabaja en un solo centro)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS medico (
  id_medico INT AUTO_INCREMENT PRIMARY KEY,
  documento VARCHAR(15) NOT NULL UNIQUE,
  nombre VARCHAR(50) NOT NULL,
  apellido VARCHAR(50) NOT NULL,
  telefono VARCHAR(15),
  correo VARCHAR(100),
  horario_inicio TIME NOT NULL,
  horario_fin TIME NOT NULL,
  id_especialidad INT NOT NULL,
  id_centro INT NOT NULL,
  CONSTRAINT fk_medico_especialidad FOREIGN KEY (id_especialidad) REFERENCES especialidad (id_especialidad),
  CONSTRAINT fk_medico_centro FOREIGN KEY (id_centro) REFERENCES centro_salud (id_centro)
);

-- ---------------------------------------------------------
-- 4. Pacientes
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS paciente (
  id_paciente INT AUTO_INCREMENT PRIMARY KEY,
  documento VARCHAR(15) NOT NULL UNIQUE,
  nombre VARCHAR(50) NOT NULL,
  apellido VARCHAR(50) NOT NULL,
  fecha_nacimiento DATE NOT NULL,
  telefono VARCHAR(15),
  correo VARCHAR(100),
  direccion VARCHAR(150)
);

-- ---------------------------------------------------------
-- 5. Citas
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS cita (
  id_cita INT AUTO_INCREMENT PRIMARY KEY,
  id_paciente INT NOT NULL,
  id_medico INT NOT NULL,
  fecha DATE NOT NULL,
  hora TIME NOT NULL,
  motivo VARCHAR(255),
  estado ENUM('Programada', 'Atendida', 'Cancelada', 'No asistio') NOT NULL DEFAULT 'Programada',
  CONSTRAINT fk_cita_paciente FOREIGN KEY (id_paciente) REFERENCES paciente (id_paciente),
  CONSTRAINT fk_cita_medico FOREIGN KEY (id_medico) REFERENCES medico (id_medico)
);

-- ---------------------------------------------------------
-- 6. Historial médico (cada cita atendida genera un historial)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS historial_medico (
  id_historial INT AUTO_INCREMENT PRIMARY KEY,
  id_cita INT NOT NULL UNIQUE,
  diagnostico VARCHAR(255) NOT NULL,
  tratamiento VARCHAR(255),
  observaciones VARCHAR(255),
  fecha_registro DATETIME NOT NULL,
  CONSTRAINT fk_historial_cita FOREIGN KEY (id_cita) REFERENCES cita (id_cita)
);

-- ---------------------------------------------------------
-- 7. Recordatorios (los generará un trigger al agendar una cita)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS recordatorio (
  id_recordatorio INT AUTO_INCREMENT PRIMARY KEY,
  id_cita INT NOT NULL,
  mensaje VARCHAR(255) NOT NULL,
  fecha_envio DATETIME NOT NULL,
  estado ENUM('Pendiente', 'Enviado', 'Cancelado') NOT NULL DEFAULT 'Pendiente',
  CONSTRAINT fk_recordatorio_cita FOREIGN KEY (id_cita) REFERENCES cita (id_cita)
);