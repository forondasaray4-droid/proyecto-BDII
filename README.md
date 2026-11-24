# Sistema de gestión de citas - Centros de salud de Cartago

Proyecto final de Bases de Datos II (COTECNOVA, 2026). Base de datos relacional en **MariaDB** que soporta
la gestión de pacientes, médicos, franjas horarias, citas, historial médico y recordatorios automáticos
para los centros de salud del municipio de Cartago (Valle del Cauca).

- **Autora:** Saray Foronda Restrepo
- **Docente:** Jhon James Cano Sánchez
- **Etiqueta del proyecto final:** `final`
- **Informe:** `docs/InformeFinal_Foronda_Saray.pdf` · **Presentación:** `docs/Presentacion.pdf`

## Requisitos (programas que deben estar instalados antes)

| Programa | Para qué se usa | Cómo comprobarlo |
|---|---|---|
| Windows 10/11 con **WSL 2** y una distribución **Ubuntu** | Terminal donde se ejecutan los scripts (`.sh`) | `wsl -l -v` (en PowerShell) |
| **Docker Desktop** con la integración de WSL activada (Settings → Resources → WSL integration) y **Docker Compose v2** | Levanta MariaDB 10.8, PHP/Apache y phpMyAdmin | `docker --version` y `docker compose version` (en Ubuntu) |
| **Git** | Clonar el repositorio | `git --version` |
| `cron` (en Ubuntu) | Respaldo automático | `sudo service cron start` |
| *Opcional:* MySQL Workbench | Ver el modelo (`docs/MER.mwb`) y consultar la base | — |

Además:
- Docker Desktop debe estar **abierto y en estado "running"** antes de empezar.
- Los puertos **3306** (MariaDB), **8080** (app PHP) y **8081** (phpMyAdmin) deben estar libres. Si otro programa usa el 3306 (por ejemplo un MySQL de Windows), deténgalo o cambie el mapeo en `docker-compose.yml` (por ejemplo `"3307:3306"`).
- No hace falta instalar MariaDB ni PHP en el equipo: corren dentro de los contenedores.

## Instalación (desde cero)

Todos los comandos se ejecutan en la terminal de **Ubuntu (WSL)**, no en PowerShell.

```bash
# 1. Clonar el repositorio
git clone https://github.com/forondasaray4-droid/proyecto-BDII.git
cd proyecto-BDII

# 2. Credenciales (el archivo real NO se sube al repositorio: está en .gitignore)
cp scripts/respaldo.env.ejemplo scripts/.respaldo.env
chmod 600 scripts/.respaldo.env
nano scripts/.respaldo.env            # cambiar todos los valores CAMBIAR_... (Ctrl+O, Enter, Ctrl+X)

# 3. Levantar los contenedores (MariaDB 10.8, PHP/Apache y phpMyAdmin)
docker compose --env-file scripts/.respaldo.env up -d --build
docker ps                             # deben verse citas_mariadb, citas_app y citas_phpmyadmin

# 4. Crear TODA la base de datos desde cero (esquema, datos, rutinas, triggers,
#    vistas, seguridad, índices y eventos). Termina con un resumen de objetos.
./instalar.sh

# 5. (Recomendado) Ejecutar los 60 casos de prueba: resultado esperado vs obtenido
./instalar.sh --pruebas               # al final debe mostrar: OK 60
```

Resultado esperado de `./instalar.sh`: 12 tablas, 3 vistas, 10 procedimientos, 5 funciones, 5 triggers,
2 eventos y 10.015 citas.

**Accesos**
- MariaDB: `127.0.0.1:3306`, usuario `root`, contraseña `DB_PASS` (de `scripts/.respaldo.env`).
- phpMyAdmin: `http://localhost:8081` · App PHP de prueba: `http://localhost:8080`.

**Apagar y volver a instalar**
```bash
docker compose --env-file scripts/.respaldo.env down        # apaga (conserva los datos)
docker compose --env-file scripts/.respaldo.env down -v     # apaga y BORRA la base; luego repetir los pasos 3 a 5
```
(`--env-file` es necesario porque `docker-compose.yml` exige `DB_PASS`.)

**Problemas frecuentes**
- `required variable DB_PASS is missing a value`: falta `--env-file scripts/.respaldo.env` o el archivo no existe (paso 2).
- `Ports are not available` / `port is already allocated`: otro programa usa el 3306, 8080 u 8081.
- `ERROR 1045 Access denied` al instalar: el volumen guarda una contraseña de `root` anterior. Use esa en `DB_PASS` o ejecute `down -v` y repita los pasos 3 a 5.
- Si el contenedor de la base tiene otro nombre: `CONTENEDOR=nombre ./instalar.sh`.
- `instalar.sh` **borra y recrea** la base `proyecto_citas`; es repetible.
- Los valores del `.respaldo.env` no deben llevar comillas simples ni espacios. Las contraseñas de usuario deben cumplir la política (8+ caracteres, dígito, mayúscula, minúscula y símbolo).

## Usuarios de prueba y su rol

Las contraseñas están en `scripts/.respaldo.env` (`PASS_LECTOR`, `PASS_RECEPCION`, `PASS_GESTOR`).

| Usuario | Rol | Para qué sirve | Política de cuenta |
|---|---|---|---|
| `lector_citas` | `rol_consulta_citas` | Solo consulta las vistas (datos enmascarados) | La contraseña vence cada 90 días |
| `recepcion_citas` | `rol_recepcion_citas` | Agenda, cancela y reprograma citas con procedimientos | Máx. 2 conexiones y 500 consultas por hora |
| `gestor_citas` | `rol_admin_citas` | Administra los datos; la auditoría es solo lectura | Sin restricciones adicionales |

El PIN de práctica de los pacientes (portal) es `PIN_DEMO` del mismo archivo; se valida con `fn_validar_login_citas`.

## Estructura del repositorio

```
proyecto-BDII/
├── docker-compose.yml        MariaDB 10.8 + PHP 8.2/Apache + phpMyAdmin
├── Dockerfile                Imagen de la app PHP
├── instalar.sh               Ejecuta sql/01..09 en orden (con --pruebas: sql/10)
├── README.md
├── .gitignore                Excluye .respaldo.env y respaldos/
├── sql/
│   ├── 01_esquema.sql        Base y 12 tablas
│   ├── 02_datos.sql          Datos de prueba (10.015 citas), hash con sal y cifrado AES
│   ├── 03_funciones.sql      5 funciones
│   ├── 04_procedimientos.sql 10 procedimientos (4 transaccionales)
│   ├── 05_triggers.sql       Validación, automatización y auditoría
│   ├── 06_vistas.sql         3 vistas (enmascarada, reporte JOIN, resumen)
│   ├── 07_seguridad.sql      Roles, usuarios, privilegios y política de contraseñas
│   ├── 08_indices.sql        Índices justificados
│   ├── 09_eventos.sql        2 eventos programados
│   ├── 10_pruebas.sql        60 casos de prueba + guiones de concurrencia y seguridad
│   └── optimizacion_medicion.sql   EXPLAIN / ANALYZE antes y después
├── scripts/
│   ├── respaldar.sh          Respaldo de la base y de usuarios (cron)
│   ├── restaurar_simulacro.sh  Simulacro de recuperación verificado con CHECKSUM
│   ├── restaurar.sh          Restauración real de la base y los usuarios
│   └── respaldo.env.ejemplo  Plantilla de credenciales (el real no se sube)
├── docs/MER.mwb, MER.png     Modelo editable en MySQL Workbench y su imagen
├── docs/                     MER, informes y presentación
├── capturas/                 Evidencias por clase y de este final
└── src/                      Página PHP de prueba
```

## Descripción de cada script

| Script | Qué hace |
|---|---|
| `01_esquema.sql` | Recrea `proyecto_citas` con 12 tablas InnoDB, llaves, `UNIQUE`, `CHECK` y catálogo `estado_cita` |
| `02_datos.sql` | 20 centros, 20 especialidades, 20 médicos con sus franjas, 2.010 pacientes, **10.015 citas**, 8.010 historiales y 10.015 recordatorios. Calcula el hash con sal del PIN y cifra las observaciones médicas |
| `03_funciones.sql` | `fn_clasificar_edad`, `fn_contar_citas_paciente`, `fn_medico_disponible`, `fn_enmascarar`, `fn_validar_login_citas` |
| `04_procedimientos.sql` | Procedimientos de la operación principal (ver tabla de transacciones) y los que usan los eventos |
| `05_triggers.sql` | `trg_validar_cita` (BEFORE), `trg_generar_recordatorio` (AFTER), `trg_auditar_paciente_update` y la protección de la auditoría |
| `06_vistas.sql` | `vw_pacientes_publico` (enmascara), `vw_citas_detalle` (JOIN de 6 tablas), `vw_resumen_centro` (JOIN + GROUP BY) |
| `07_seguridad.sql` | 3 roles, 3 usuarios, privilegios, vencimiento y límites de cuenta. Las contraseñas llegan por variables de sesión |
| `08_indices.sql` | 5 índices compuestos y eliminación de los redundantes |
| `09_eventos.sql` | `ev_marcar_citas_vencidas` (diario 23:55) y `ev_enviar_recordatorios` (cada hora) |
| `10_pruebas.sql` | Casos de prueba automáticos y guiones manuales de concurrencia y seguridad |
| `optimizacion_medicion.sql` | Mide 7 consultas antes y después de los índices |
| `instalar.sh` | Orquesta la instalación en el contenedor; pasa las credenciales como variables de sesión |
| `respaldar.sh` | Respaldo comprimido de la base y de usuarios/roles, verificación, retención y registro |
| `restaurar_simulacro.sh` | Restaura en una base nueva y compara objetos y `CHECKSUM TABLE` |
| `restaurar.sh` | Restaura de verdad la base y los usuarios desde los respaldos |

## Modelo de datos

Normalizado hasta 3FN (MER en `docs/MER.png` y `modelado/MER.mwb`).

| Tabla | Descripción |
|---|---|
| `centro_salud`, `especialidad` | Catálogos de centros y especialidades |
| `estado_cita` | Catálogo de estados (Programada, Atendida, Cancelada, No asistio) |
| `medico` | Médicos, con su especialidad y su centro |
| `franja_horaria` | Franjas de atención por médico y día de la semana |
| `paciente` | Datos personales; `sal` y `pin_hash` (PIN con hash SHA-256 y sal) |
| `cita` | Tabla transaccional principal (10.015 filas) |
| `historial_medico` | 1:1 con la cita atendida; `observaciones_cifrado` (AES) |
| `recordatorio` | Generados por trigger un día antes de la cita |
| `auditoria_paciente` | Cambios sobre datos sensibles del paciente |
| `log_errores`, `log_eventos` | Errores de los procedimientos y tareas de los eventos |

## Seguridad

> Las contraseñas y la llave AES **no están en el repositorio**: se leen de `scripts/.respaldo.env`.

**Matriz de seguridad**

| Objeto | `rol_consulta_citas` | `rol_recepcion_citas` | `rol_admin_citas` |
|---|---|---|---|
| Vistas `vw_pacientes_publico`, `vw_citas_detalle`, `vw_resumen_centro` | SELECT | SELECT (heredado) | SELECT |
| Tablas del negocio (`paciente`, `cita`, `medico`, `franja_horaria`, `historial_medico`, ...) | - | - | SELECT, INSERT, UPDATE, DELETE |
| `auditoria_paciente`, `log_errores`, `log_eventos` | - | - | **SELECT (solo lectura)** |
| `sp_agendar_cita_segura`, `sp_cancelar_cita`, `sp_reprogramar_cita` | - | EXECUTE | EXECUTE |
| `fn_validar_login_citas` | - | EXECUTE | EXECUTE |
| Demás procedimientos y funciones | - | - | EXECUTE |
| DROP / TRUNCATE / ALTER / CREATE USER / GRANT OPTION | - | - | - |

**Protección de datos sensibles**

| Dato | Técnica |
|---|---|
| PIN del paciente (`paciente.pin_hash`) | SHA-256 con sal aleatoria por paciente (`paciente.sal`); `fn_validar_login_citas` compara hashes |
| Observaciones médicas (`historial_medico.observaciones_cifrado`) | Cifrado AES (`AES_ENCRYPT` / `AES_DECRYPT`); la llave solo existe como variable de sesión |
| Documento, teléfono y correo | Enmascarados en `vw_pacientes_publico` con `fn_enmascarar` |

**Política de contraseñas:** plugin `simple_password_check` (8+ caracteres, dígito, mayúscula, minúscula y símbolo);
una contraseña como `12345` se rechaza con el error 1819. Vencimiento de 90 días y límites de recursos por usuario.

**Auditoría que el administrador no puede borrar:** `gestor_citas` solo tiene `SELECT` sobre `auditoria_paciente`
(`DELETE` y `TRUNCATE` dan error 1142) y además dos triggers `BEFORE UPDATE/DELETE` impiden modificarla incluso a
cuentas con privilegios. Cada fila guarda campo, valor anterior y nuevo, `USER()`, `CURRENT_USER()` y fecha.

## Transacciones y concurrencia

Todos usan `START TRANSACTION`, `EXIT HANDLER FOR SQLEXCEPTION` con `ROLLBACK`, registro del error en `log_errores`
(con `GET DIAGNOSTICS`) y `RESIGNAL` para que quien llama reciba el error original. Las reglas de negocio se validan con
`SIGNAL SQLSTATE '45000'`.

| Procedimiento | Operaciones que agrupa | Errores que controla |
|---|---|---|
| `sp_agendar_cita` | Bloquea la agenda del médico (`FOR UPDATE`), valida y inserta la cita; el trigger crea el recordatorio | Médico o paciente inexistente, fecha nula o pasada, médico no disponible (fuera de franja u ocupado) |
| `sp_cancelar_cita` | Bloquea la cita, la pasa a Cancelada y cancela su recordatorio | Cita inexistente o que no está Programada |
| `sp_reprogramar_cita` | Bloquea cita y médico, cancela la anterior y crea la nueva | Cita inexistente o no Programada, nueva fecha inválida, nuevo horario ocupado o fuera de franja (deshace todo) |
| `sp_registrar_atencion` | Bloquea la cita, inserta el historial con observaciones cifradas y pasa la cita a Atendida | Cita inexistente o no Programada, diagnóstico vacío, falta `@llave_aes` |

**Prueba de atomicidad** (`10_pruebas.sql`, casos 18 a 20): `sp_reprogramar_cita` cancela la cita original y luego intenta
crear la nueva en un horario ocupado; el trigger rechaza el INSERT, el `ROLLBACK` deshace la cancelación y la cita
original sigue **Programada** con su recordatorio **Pendiente**.

**Prueba de concurrencia** (dos sesiones; guion en `10_pruebas.sql`, sección B). Recurso protegido: la cita y la agenda del médico.

| Escenario | Sin bloqueo | Con `SELECT ... FOR UPDATE` |
|---|---|---|
| Una sesión cancela la cita mientras otra registra la atención | La cita queda **Atendida** aunque se canceló (actualización perdida) | La segunda sesión espera, ve la cancelación y falla con "Solo se puede atender una cita en estado Programada" |
| Dos sesiones reservan al mismo médico | - | La segunda espera a que la primera confirme y recibe "El medico no esta disponible..." |

## Optimización

Se generaron 10.015 citas (`seq_1_to_10000`) y se midieron 7 consultas frecuentes con `EXPLAIN` y `ANALYZE FORMAT=JSON`
(una ejecución por consulta; por debajo de 1 ms las diferencias son ruido) con `sql/optimizacion_medicion.sql`. Antes solo existían los índices que InnoDB crea por cada llave foránea.


| # | Consulta | type / key antes | Filas antes | Tiempo antes | Índice creado | type / key después | Filas después | Tiempo después |
|---|---|---|---|---|---|---|---|---|
| Q1 | Agenda de un médico en un mes (JOIN + rango + ORDER BY) | ref / fk_cita_medico | 502 | 1.11 ms | `idx_cita_medico_fecha_hora` | range / idx_cita_medico_fecha_hora | 88 | 0.39 ms |
| Q2 | Últimas 10 citas de un paciente (ORDER BY DESC + LIMIT) | ref / fk_cita_paciente | 5 | 0.055 ms | `idx_cita_paciente_fecha` | ref / idx_cita_paciente_fecha | 5 | 0.083 ms |
| Q3 | Citas de marzo por estado (rango + GROUP BY) | index / fk_cita_estado | 9853 | 12.90 ms | `idx_cita_fecha_estado` | range / idx_cita_fecha_estado | 1760 | 0.97 ms |
| Q4 | Citas de marzo con `YEAR()/MONTH()` → reescrita con rango | ALL / NULL | 9853 | 2.67 ms | `idx_cita_fecha_estado` | range / idx_cita_fecha_estado | 1760 | 0.56 ms |
| Q5 | Recordatorios pendientes (WHERE + ORDER BY) | ALL / NULL | 9815 | 3.31 ms | `idx_recordatorio_estado_envio` | range / idx_recordatorio_estado_envio | 3 | 0.045 ms |
| Q6 | Atenciones de un centro en un trimestre (JOIN 3 tablas) | ref / fk_cita_medico | 246 | 0.75 ms | `idx_cita_medico_fecha_hora` | ref / idx_cita_medico_fecha_hora | 246 | 0.54 ms |
| Q7 | Pacientes por apellido (`LIKE 'Gar%'`) | ALL / NULL | 1982 | 0.92 ms | `idx_paciente_apellido_nombre` | range / idx_paciente_apellido_nombre | 100 | 0.063 ms |

**Justificación de los índices** (igualdad primero, rango u orden después):

- `(id_medico, fecha, hora)`: agenda de un médico por rango y orden (Q1, Q6) y búsquedas de disponibilidad de `fn_medico_disponible` y `trg_validar_cita`. Elimina el `Using filesort` de Q1.
- `(id_paciente, fecha)`: historial de un paciente más reciente primero (Q2); el índice ya entrega las filas ordenadas (desaparece el `Using filesort`; con solo 5 filas por paciente el tiempo no cambia).
- `(fecha, id_estado)`: reportes por rango de fechas (Q3, Q4); es un índice cubriente para el conteo por estado (`Using index`).
- `(estado, fecha_envio)`: recordatorios pendientes (Q5), que consulta `sp_enviar_recordatorios`. Muy selectivo: pasa de leer 9.815 filas a 3.
- `(apellido, nombre)`: búsqueda de pacientes por prefijo de apellido (Q7).
- **Redundantes eliminados:** `fk_cita_medico` y `fk_cita_paciente` (prefijo de los compuestos; InnoDB usa el compuesto para la llave foránea).
- **Consulta reescrita (Q4):** `YEAR(fecha) = 2026 AND MONTH(fecha) = 3` anula el índice (sigue recorriendo 9.853 filas); `fecha >= '2026-03-01' AND fecha < '2026-04-01'` lo usa. Regla: la columna indexada debe quedar sola a un lado de la comparación.
- **Costo:** cada índice ocupa espacio y hace más lentos los INSERT/UPDATE; por eso solo se crearon 5, no se indexó `estado` de la cita (pocos valores distintos) y se retiraron los redundantes.

## Respaldo y recuperación

| Aspecto | Plan |
|---|---|
| **Qué se respalda** | Base `proyecto_citas` completa (estructura, datos, procedimientos, funciones, triggers, vistas y eventos) y, aparte, usuarios, roles y privilegios (`mariadb-dump --system=users`) |
| **Herramienta** | `scripts/respaldar.sh` (`mariadb-dump --single-transaction`, comprimido con gzip) |
| **Frecuencia** | Diaria a las 10:00 p. m. con cron |
| **Ubicación** | `respaldos/` (primera copia, fuera del repositorio) y una segunda copia en `DIR_COPIA` (USB o carpeta en la nube) para cumplir la regla 3-2-1 |
| **Retención** | 7 días; el script elimina los respaldos más antiguos |
| **Verificación** | El script comprueba que el archivo termina con `Dump completed`; cada ejecución queda en `respaldos/respaldos.log` |
| **Protección** | Los archivos de respaldo (con hashes de contraseñas) quedan con permisos `600` y no se suben a GitHub |
| **RPO** | 24 horas: con un respaldo diario se podrían perder hasta las transacciones de un día. Mejora posible: activar el registro binario para recuperar a un punto en el tiempo |
| **RTO** | Menos de 30 minutos (restaurar, verificar y volver a abrir el servicio). El simulacro lo mide: ver `restaurar_simulacro.sh` |

**Programar con cron** (en WSL: `sudo service cron start`, luego `crontab -e`):

```cron
# Demostración: cada 2 minutos
*/2 * * * * /ruta/al/repo/scripts/respaldar.sh >> /ruta/al/repo/respaldos/cron.log 2>&1
# Uso real: todos los días a las 10:00 p. m.
0 22 * * * /ruta/al/repo/scripts/respaldar.sh >> /ruta/al/repo/respaldos/cron.log 2>&1
```

Evidencias: `cat respaldos/respaldos.log` (varias ejecuciones automáticas) y `crontab -l`. Si el contenedor se llama distinto, anteponer `CONTENEDOR=nombre`.

**Evento programado:** `ev_marcar_citas_vencidas` y `ev_enviar_recordatorios` (`09_eventos.sql`) corren dentro del motor
(`--event-scheduler=ON` en `docker-compose.yml`) y registran su trabajo en `log_eventos`. Comprobar con:
`SELECT EVENT_NAME, STATUS, LAST_EXECUTED FROM information_schema.EVENTS WHERE EVENT_SCHEMA='proyecto_citas';`

**Simulacro de recuperación** (no toca la base real):

```bash
./scripts/restaurar_simulacro.sh
```

Genera un respaldo, lo restaura en `proyecto_citas_restaurada`, compara el número de tablas, vistas, rutinas, triggers y eventos
y el `CHECKSUM TABLE` de cada tabla, simula el desastre (`DROP DATABASE` de la copia), la recupera de nuevo y mide el tiempo.

**Pasos para restaurar de verdad** (la base se perdió o se dañó):

```bash
./scripts/restaurar.sh                                  # usa los respaldos más recientes (pide confirmar con SI)
# o con archivos concretos:
./scripts/restaurar.sh respaldos/proyecto_citas_AAAAMMDD_HHMMSS.sql.gz respaldos/usuarios_AAAAMMDD_HHMMSS.sql.gz
```

Equivale a: `gunzip -c respaldo.sql.gz | docker exec -i -e MYSQL_PWD=... citas_mariadb mariadb -u root` para la base, y a restaurar
el archivo de usuarios con `--force` desactivando temporalmente `strict_password_validation` (MariaDB rechaza las contraseñas
ya convertidas en hash mientras la política de contraseñas está activa).

## Pruebas

`./instalar.sh --pruebas` ejecuta 60 casos (operación, resultado esperado y resultado obtenido): procedimientos y sus errores,
atomicidad, triggers, funciones, vistas, cifrado, hash con sal, auditoría protegida y eventos; al final muestra el conteo de
`OK` y `FALLO`. Los guiones manuales de concurrencia (dos sesiones) y de seguridad (tres usuarios) están al final de `sql/10_pruebas.sql`.

## Cambios desde el Avance 2 (retroalimentación atendida)

| Observación del docente | Cómo se atendió |
|---|---|
| Convertir los estados de la cita en una tabla independiente | Nueva tabla `estado_cita`; `cita.id_estado` es llave foránea. Se agregan estados sin alterar `cita` |
| Agregar franjas horarias por médico | Nueva tabla `franja_horaria` (día de la semana, hora de inicio y de fin) que reemplaza el único horario; la usan `fn_medico_disponible` y `trg_validar_cita` |

Además: procedimientos transaccionales con manejo de errores, control de concurrencia, vistas y funciones nuevas, índices,
eventos, respaldo automático con simulacro de recuperación, y credenciales fuera del repositorio.
