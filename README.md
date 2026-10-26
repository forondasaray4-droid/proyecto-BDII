# Sistema de gestión de citas - Centros de salud de Cartago

Proyecto de Bases de Datos II (COTECNOVA, 2026). Base de datos en MariaDB para gestionar pacientes, médicos, citas, historial médico y recordatorios automáticos en los centros de salud del municipio de Cartago.

- **Autora:** Saray Foronda Restrepo
- **Docente:** Jhon James Cano Sánchez
- **Avance 2 (segundo corte):** etiqueta `avance-2`
- **Video de sustentación:** https://drive.google.com/file/d/1HNi2bk2MWJ6LJHqQXN-8wpyttmbwKF1h/view?usp=drive_link
- **Informe:** `docs/Avance2_Foronda_Saray.pdf`

## Requisitos

- WSL con Ubuntu
- Docker y Docker Compose
- MySQL Workbench (opcional, para ver el modelo y probar usuarios)

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

## Cómo crear la base de datos desde cero

Opción rápida (carga todo en el orden correcto y muestra un resumen):

```bash
chmod +x cargar_bd.sh
./cargar_bd.sh
```

Opción manual: ejecutar los scripts de `sql/` **en este orden**:

| # | Script | Contenido |
|---|---|---|
| 1 | `esquema.sql` | Crea la base `proyecto_citas` y sus 7 tablas |
| 2 | `datos_prueba.sql` | Datos de prueba (mínimo 10 registros por tabla) |
| 3 | `procedimientos.sql` | 5 procedimientos almacenados con validaciones `SIGNAL` |
| 4 | `triggers.sql` | Triggers de validación y recordatorio automático |
| 5 | `funciones.sql` | Funciones almacenadas |
| 6 | `clase10_seguridad_citas.sql` | Seguridad: roles, usuarios, vistas, cifrado, hash con sal y auditoría |

> `clase10_seguridad_citas.sql` requiere el plugin `simple_password_check` (el script `cargar_bd.sh` lo activa; manualmente: `INSTALL SONAME 'simple_password_check';`).

## Modelo de datos

El diagrama entidad-relación actualizado está en `capturas/avance2/MER_avance2.png` y el modelo editable en `modelado/MER.mwb`.

| Tabla | Descripción |
|---|---|
| `centro_salud` | Centros de salud del municipio |
| `especialidad` | Especialidades médicas |
| `medico` | Médicos, su especialidad, centro y horario |
| `paciente` | Datos personales; incluye `sal` y `pin_hash` (PIN con hash y sal) |
| `cita` | Citas agendadas y su estado |
| `historial_medico` | Diagnóstico y tratamiento por cita atendida (1:1 con cita); `observaciones_cifrado` guarda las observaciones con AES |
| `recordatorio` | Recordatorios de cita, generados por trigger |
| `auditoria_paciente` | Registro de cambios sobre `paciente` (sin llave foránea, para conservar el historial) |

## Procedimientos almacenados

| Procedimiento | Parámetros | Validaciones (`SIGNAL SQLSTATE '45000'`) |
|---|---|---|
| `sp_registrar_paciente` | IN datos / OUT id | Datos obligatorios, documento duplicado, fecha de nacimiento futura |
| `sp_agendar_cita` | IN datos / OUT id | Paciente o médico inexistente, fecha pasada |
| `sp_cancelar_cita` | IN id_cita | Cita inexistente o que no está Programada |
| `sp_reporte_atenciones_centro` | IN id_centro / OUT total | - |
| `sp_acumular_citas_paciente` | IN id_paciente / INOUT total | - |
| `sp_agendar_cita_segura` | IN documento, médico, fecha, hora, motivo | Paciente o médico inexistente, fecha pasada, fuera de horario (`SQL SECURITY DEFINER`) |

Ejemplo:
```sql
CALL sp_agendar_cita(4, 1, '2026-12-15', '09:00', 'Control general', @id);
SELECT @id;
```

## Funciones almacenadas

| Función | Descripción |
|---|---|
| `fn_clasificar_edad(edad)` | Devuelve Niño, Adolescente, Adulto o Adulto mayor |
| `fn_contar_citas_paciente(documento)` | Número de citas de un paciente |
| `fn_medico_disponible(id_medico, fecha, hora)` | 1 si el médico atiende a esa hora y no tiene otra cita activa; 0 si no |
| `fn_enmascarar(texto, visibles)` | Oculta un dato dejando visibles los últimos caracteres |
| `fn_validar_login_citas(documento, pin)` | Valida el PIN comparando hashes con sal |

## Triggers

| Trigger | Evento | Descripción |
|---|---|---|
| `trg_validar_cita` | BEFORE INSERT ON cita | Impide citas con médico ocupado o fuera de su horario |
| `trg_generar_recordatorio` | AFTER INSERT ON cita | Crea el recordatorio un día antes de la cita |
| `trg_auditar_paciente_update` | AFTER UPDATE ON paciente | Auditoría: campo, valor anterior y nuevo, `USER()`, `CURRENT_USER()` y fecha |

## Vistas

| Vista | Descripción |
|---|---|
| `vw_citas_detalle` | Une cita, paciente, médico, especialidad y centro de salud (JOIN de 5 tablas) |
| `vw_pacientes_publico` | Enmascara documento, teléfono y correo del paciente |

## Seguridad

> Las contraseñas y la llave de cifrado de los scripts son **solo de práctica**. En un sistema real se toman de variables de entorno o de un gestor de secretos y no se suben al repositorio.

### Matriz de seguridad

| Objeto | `rol_consulta_citas` | `rol_recepcion_citas` | `rol_admin_citas` |
|---|---|---|---|
| `vw_pacientes_publico` (datos enmascarados) | SELECT | SELECT (heredado) | SELECT |
| `vw_citas_detalle` (JOIN de 5 tablas) | SELECT | SELECT (heredado) | SELECT |
| `paciente`, `cita`, `historial_medico` | - | - | SELECT, INSERT, UPDATE, DELETE |
| `medico`, `especialidad`, `centro_salud`, `recordatorio` | - | - | SELECT, INSERT, UPDATE, DELETE |
| `auditoria_paciente` | - | - | SELECT (solo lectura) |
| `sp_agendar_cita_segura` (DEFINER) | - | EXECUTE | EXECUTE |
| `sp_cancelar_cita` | - | EXECUTE | EXECUTE |
| `fn_validar_login_citas` | - | EXECUTE | EXECUTE |
| Demás procedimientos y funciones | - | - | EXECUTE |
| DROP TABLE / CREATE USER | - | - | - |

### Usuarios

| Usuario | Rol por defecto | Política de cuenta |
|---|---|---|
| `lector_citas` | `rol_consulta_citas` | La contraseña vence cada 90 días |
| `recepcion_citas` | `rol_recepcion_citas` | Máximo 2 conexiones y 500 consultas por hora |
| `gestor_citas` | `rol_admin_citas` | Sin restricciones adicionales |

La política `simple_password_check` exige mínimo 8 caracteres, un dígito, mayúscula y minúscula, y un carácter especial.

### Protección de datos sensibles

| Dato | Técnica |
|---|---|
| PIN del paciente (`paciente.pin_hash`) | SHA-256 con sal aleatoria por paciente (`paciente.sal`) |
| Observaciones médicas (`historial_medico.observaciones_cifrado`) | Cifrado AES con `AES_ENCRYPT` / `AES_DECRYPT` |
| Documento, teléfono y correo | Enmascarados en `vw_pacientes_publico` con `fn_enmascarar` |

## Cambios desde el primer avance

- Se agregaron funciones almacenadas, vistas, roles, usuarios, cifrado, hash con sal y auditoría.
- Los procedimientos `sp_registrar_paciente`, `sp_agendar_cita` y `sp_cancelar_cita` ahora validan con `SIGNAL`; `sp_agendar_cita` usa `LAST_INSERT_ID()` en lugar de `MAX()`.
- Los scripts se ejecutan desde cero con `cargar_bd.sh`.

## Mejoras planeadas para el proyecto final

Retroalimentación del docente en el primer avance:
- Convertir los estados de la cita en una tabla independiente (`estado_cita`), para agregar o eliminar estados sin modificar la estructura de `cita`.
- Agregar franjas horarias por médico (`franja_horaria`) en lugar de un único horario de inicio y fin.

## Estructura del repositorio

```
proyecto-BDII/
├── capturas/
│   ├── clase10/        # evidencias de la clase 10
│   └── avance2/        # evidencias del Avance 2 y MER_avance2.png
├── docs/               # informes en PDF
├── modelado/           # MER.mwb
├── sql/                # scripts de la base de datos
├── src/                # index.php de prueba
├── cargar_bd.sh        # crea la base desde cero
├── docker-compose.yml
├── Dockerfile
└── README.md
```
