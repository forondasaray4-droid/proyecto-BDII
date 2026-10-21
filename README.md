# Sistema de gestión de citas - Centros de salud de Cartago

Proyecto de Bases de Datos II (COTECNOVA, 2026). Base de datos en MariaDB para gestionar pacientes, médicos, citas, historial médico y recordatorios automáticos en centros de salud del municipio de Cartago.

## Requisitos

- WSL con Ubuntu
- Docker y Docker Compose
- MySQL Workbench (opcional, para ver el modelo)

## Cómo levantar el entorno

```bash
git clone https://github.com/forondasaray4-droid/proyecto-BDII
cd proyecto-BDII
docker compose up -d --build
```

Servicios:
- **app**: PHP 8.2 + Apache → `http://localhost:8080`
- **db**: MariaDB 10.8 → puerto `3306`
- **phpmyadmin** → `http://localhost:8081` (usuario `root`, contraseña `root_password`)

## Cómo crear la base de datos

Ejecutar los scripts de la carpeta `sql/` **en este orden** (desde MySQL Workbench o phpMyAdmin):

1. `esquema.sql` – crea la base `proyecto_citas` y sus 7 tablas
2. `datos_prueba.sql` – inserta los datos de prueba (mínimo 10 registros por tabla)
3. `procedimientos.sql` – crea los procedimientos almacenados
4. `triggers.sql` – crea los triggers
5. `clase10_seguridad_citas.sql` – roles, vistas seguras, cifrado, auditoría, usuarios y políticas de contraseñas (Clase 10)

## Modelo de datos

| Tabla | Descripción |
|---|---|
| `centro_salud` | Centros de salud del municipio |
| `especialidad` | Especialidades médicas |
| `medico` | Médicos, su especialidad, centro y horario |
| `paciente` | Datos personales de los pacientes |
| `cita` | Citas agendadas y su estado |
| `historial_medico` | Diagnóstico y tratamiento de cada cita atendida (1:1 con cita) |
| `recordatorio` | Recordatorios de cita, generados por trigger |

El diagrama entidad-relación está en `modelado/MER.mwb`.

## Procedimientos almacenados

| Procedimiento | Parámetros | Descripción |
|---|---|---|
| `sp_registrar_paciente` | IN (datos) / OUT id | Registra un paciente y devuelve su id |
| `sp_agendar_cita` | IN (datos) / OUT id | Agenda una cita y devuelve su id |
| `sp_cancelar_cita` | IN id_cita | Cancela la cita y su recordatorio pendiente |
| `sp_reporte_atenciones_centro` | IN id_centro / OUT total | Lista las atenciones de un centro y devuelve el total |
| `sp_acumular_citas_paciente` | IN id_paciente / INOUT total | Acumula el número de citas de varios pacientes |

Ejemplo:
```sql
CALL sp_agendar_cita(4, 1, '2026-10-05', '09:00', 'Control general', @id);
SELECT @id;
```

## Triggers

- **trg_validar_cita** (BEFORE INSERT ON cita): impide agendar una cita si el médico ya está ocupado en esa fecha y hora, o si la hora está fuera de su horario de atención.
- **trg_generar_recordatorio** (AFTER INSERT ON cita): crea automáticamente un recordatorio para un día antes de cada cita nueva.

## Estructura del repositorio

```
proyecto-BDII/
├── docs/                # informe_avance.pdf
├── sql/                 # esquema, datos de prueba, procedimientos y triggers
├── modelado/            # MER.mwb
├── src/                 # index.php de prueba
├── docker-compose.yml
├── Dockerfile
└── README.md
```

## Autor

Saray Foronda Restrepo– Bases de Datos II, docente Jhon James Cano Sánchez

## Seguridad (Clase 10)

El script `sql/clase10_seguridad_citas.sql` agrega seguridad por capas sobre `proyecto_citas`: roles, vistas que enmascaran datos, hash y cifrado de datos sensibles, un procedimiento `SQL SECURITY DEFINER`, auditoría y políticas de cuentas. Se ejecuta como `root`, después de los scripts anteriores y de `Clase9/clase8_funciones_usuarios.sql`.

> Las contraseñas y la llave de cifrado del script son **solo de práctica**. En un sistema real se toman de variables de entorno o de un gestor de secretos y no se suben al repositorio.

### Matriz de seguridad

| Objeto | `rol_consulta_citas` | `rol_recepcion_citas` | `rol_admin_citas` |
|---|---|---|---|
| `vw_pacientes_publico` (vista, datos enmascarados) | SELECT | SELECT (heredado) | SELECT |
| `vw_citas_detalle` (vista, JOIN de 5 tablas) | SELECT | SELECT (heredado) | SELECT |
| `paciente`, `cita`, `historial_medico` (tablas) | — | — | SELECT, INSERT, UPDATE, DELETE |
| `medico`, `especialidad`, `centro_salud`, `recordatorio` (tablas) | — | — | SELECT, INSERT, UPDATE, DELETE |
| `auditoria_paciente` (tabla) | — | — | SELECT (solo lectura) |
| `sp_agendar_cita_segura` (DEFINER) | — | EXECUTE | EXECUTE |
| `sp_cancelar_cita` | — | EXECUTE | EXECUTE |
| `fn_validar_login_citas` | — | EXECUTE | EXECUTE |
| Demás procedimientos y funciones | — | — | EXECUTE |
| DROP TABLE / CREATE USER | — | — | — |

### Usuarios

| Usuario | Rol (por defecto) | Política de cuenta |
|---|---|---|
| `lector_citas` | `rol_consulta_citas` | La contraseña vence cada 90 días |
| `recepcion_citas` | `rol_recepcion_citas` | Máximo 2 conexiones y 500 consultas por hora |
| `gestor_citas` | `rol_admin_citas` | Sin restricciones adicionales |

La política `simple_password_check` exige mínimo 8 caracteres, un dígito, mayúscula y minúscula, y un carácter especial.

### Protección de datos sensibles

| Dato | Técnica |
|---|---|
| PIN del paciente (`paciente.pin_hash`) | SHA-256 con sal aleatoria por paciente (`paciente.sal`); se valida con `fn_validar_login_citas` |
| Observaciones médicas (`historial_medico.observaciones_cifrado`) | Cifrado AES con `AES_ENCRYPT` / `AES_DECRYPT` |
| Documento, teléfono y correo | Enmascarados en `vw_pacientes_publico` con `fn_enmascarar` |

### Auditoría

El trigger `trg_auditar_paciente_update` registra en `auditoria_paciente` el campo modificado, el valor anterior y el nuevo, `USER()`, `CURRENT_USER()` y la fecha. El PIN nunca se copia a la auditoría. El rol administrador solo tiene SELECT sobre esa tabla, por lo que no puede borrar la evidencia.

### Procedimiento de agendamiento seguro

`sp_agendar_cita_segura(documento, id_medico, fecha, hora, motivo)` valida con `SIGNAL SQLSTATE '45000'` que el paciente y el médico existan, que la fecha no sea pasada y que la hora esté dentro del horario del médico. Se ejecuta con los privilegios de su creador, de modo que el rol de recepción agenda citas sin tener INSERT sobre la tabla `cita`.
