/*
=============================================================================
 run_full_etl.sql
 Crea todos los objetos y ejecuta el ETL completo: Bronze -> Silver -> Gold.
 Requiere haber ejecutado antes init_database.sql.

 Ejecutar desde la RAÍZ del repositorio (por las rutas de los CSV):
     psql -U postgres -d data_warehouse -f 03_scripts/run_full_etl.sql

 La carga de Bronze se hace con \copy (lado cliente), así funciona aunque el
 servicio de PostgreSQL no tenga acceso a la carpeta del repositorio. Si sí
 lo tiene, se puede usar en su lugar: CALL bronze.load_bronze('<ruta>/01_datasets');
=============================================================================
*/

\set ON_ERROR_STOP on
\set QUIET on

\echo '>> Bronze: tablas y procedimiento'
\ir bronze/ddl_bronze.sql
\ir bronze/proc_load_bronze.sql
\echo '>> Bronze: carga de los CSV'
\ir bronze/load_bronze_psql.sql

\echo '>> Silver: tablas, procedimiento y carga'
\ir silver/ddl_silver.sql
\ir silver/proc_load_silver.sql
CALL silver.load_silver();

\echo '>> Gold: vistas'
\ir gold/ddl_gold.sql

\echo '>> Resumen'
SELECT 'gold.dim_customers' AS object_name, COUNT(*) AS rows FROM gold.dim_customers
UNION ALL SELECT 'gold.dim_products', COUNT(*) FROM gold.dim_products
UNION ALL SELECT 'gold.fact_sales',   COUNT(*) FROM gold.fact_sales;
