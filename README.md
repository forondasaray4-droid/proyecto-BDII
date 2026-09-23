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