# Guía de configuración

## 1. Requisitos

- PostgreSQL 14 o superior (probado con 16).
- `psql` (viene con el instalador de PostgreSQL) y, opcionalmente, pgAdmin.
- El repositorio clonado en la computadora.

En Windows, si `psql` no se reconoce en la terminal, agregar al PATH la
carpeta `C:\Program Files\PostgreSQL\<versión>\bin`.

## 2. Crear la base de datos

Desde la raíz del repositorio:

```bash
psql -U postgres -d postgres -f 03_scripts/init_database.sql
```

Crea la base `data_warehouse`, los esquemas `bronze`, `silver`, `gold` y
`audit`, y la tabla `audit.load_log`.

> **Ojo:** borra la base `data_warehouse` si ya existe.

**En pgAdmin:** abrir el archivo en el Query Tool conectado a la base
`postgres` y ejecutar solo la PARTE 1. Luego refrescar, abrir otro Query Tool
en `data_warehouse` y ejecutar la PARTE 2, sin la línea `\connect`.

## 3. Ejecutar el ETL

### Opción A: todo con psql (recomendada)

```bash
psql -U postgres -d data_warehouse -f 03_scripts/run_full_etl.sql
```

Crea las tablas, los procedimientos y las vistas, carga Bronze con `\copy` y
ejecuta `silver.load_silver()`. Debe ejecutarse **desde la raíz del
repositorio**, porque las rutas de los CSV son relativas.

### Opción B: con los procedimientos almacenados

1. Ejecutar en orden, conectado a `data_warehouse`:
   `bronze/ddl_bronze.sql`, `bronze/proc_load_bronze.sql`,
   `silver/ddl_silver.sql`, `silver/proc_load_silver.sql`,
   `gold/ddl_gold.sql`.
2. Cargar las capas:

   ```sql
   CALL bronze.load_bronze('C:/pg_datasets');   -- ruta a 01_datasets
   CALL silver.load_silver();
   ```

`bronze.load_bronze` usa `COPY` en el **servidor**, así que:

- El usuario debe ser superusuario (como `postgres`) o tener el rol
  `pg_read_server_files`.
- El servicio de PostgreSQL debe poder leer la carpeta. En Windows el servicio
  corre con una cuenta de sistema que normalmente **no** tiene acceso al
  Escritorio ni a OneDrive. Lo más simple es copiar `01_datasets` a una ruta
  como `C:\pg_datasets` y pasar esa ruta con `/`.
- Si aparece `Permission denied` o `could not open file`, usar la opción A.

## 4. Verificar

```bash
psql -U postgres -d data_warehouse -f 04_tests/quality_checks_silver.sql
psql -U postgres -d data_warehouse -f 04_tests/quality_checks_gold.sql
```

Cada consulta indica el resultado esperado (la mayoría: sin filas).

La bitácora de cargas queda en:

```sql
SELECT layer, table_name, rows_loaded, status,
       end_time - start_time AS duration, error_message
FROM   audit.load_log
ORDER BY log_id DESC;
```

## 5. Volver a cargar

Las capas Bronze y Silver hacen carga completa (truncate & insert), así que
basta con volver a ejecutar `run_full_etl.sql`, o `CALL bronze.load_bronze(...)`
y `CALL silver.load_silver()`. Gold son vistas y se actualizan solas.
