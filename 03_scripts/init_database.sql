/*
=============================================================================
 init_database.sql
 Crea la base de datos data_warehouse, sus esquemas (bronze, silver, gold)
 y el esquema audit para la bitácora de cargas.

 ADVERTENCIA: elimina la base data_warehouse si ya existe. Todos sus datos
 se pierden. Ejecutar solo al iniciar el proyecto.

 Ejecución (psql, conectado a la base postgres):
     psql -U postgres -d postgres -f 03_scripts/init_database.sql

 En pgAdmin: ejecutar la PARTE 1 conectado a la base "postgres" y la PARTE 2
 conectado a "data_warehouse" (pgAdmin no entiende el comando \connect).
=============================================================================
*/

-- ---------------------------------------------------------------- PARTE 1
DROP DATABASE IF EXISTS data_warehouse WITH (FORCE);

CREATE DATABASE data_warehouse
    ENCODING   'UTF8'
    TEMPLATE   template0;

-- ---------------------------------------------------------------- PARTE 2
\connect data_warehouse

CREATE SCHEMA IF NOT EXISTS bronze;   -- datos originales, tal como llegan
CREATE SCHEMA IF NOT EXISTS silver;   -- datos limpios y estandarizados
CREATE SCHEMA IF NOT EXISTS gold;     -- modelo en estrella para análisis
CREATE SCHEMA IF NOT EXISTS audit;    -- bitácora técnica de las cargas

COMMENT ON SCHEMA bronze IS 'Capa Bronze: datos originales de CRM y ERP sin transformar.';
COMMENT ON SCHEMA silver IS 'Capa Silver: datos depurados, estandarizados y enriquecidos.';
COMMENT ON SCHEMA gold   IS 'Capa Gold: vistas de negocio en esquema estrella.';
COMMENT ON SCHEMA audit  IS 'Bitácora de ejecución de los procedimientos de carga.';

-- Bitácora: una fila por tabla cargada en cada ejecución.
CREATE TABLE IF NOT EXISTS audit.load_log
(
    log_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id        UUID         NOT NULL,
    layer           VARCHAR(10)  NOT NULL,
    table_name      VARCHAR(100) NOT NULL,
    start_time      TIMESTAMPTZ  NOT NULL,
    end_time        TIMESTAMPTZ,
    rows_loaded     BIGINT,
    status          VARCHAR(10)  NOT NULL,
    error_message   TEXT
);

COMMENT ON TABLE audit.load_log IS 'Registro de cada tabla cargada: lote, duración, filas y errores.';
