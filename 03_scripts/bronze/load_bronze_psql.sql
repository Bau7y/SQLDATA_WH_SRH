/*
=============================================================================
 load_bronze_psql.sql
 Alternativa a bronze.load_bronze cuando el servicio de PostgreSQL no puede
 leer la carpeta de los datos. Usa \copy, que lee los archivos desde la
 computadora donde corre psql (el cliente), no desde el servidor.

 Ejecutar desde la RAÍZ del repositorio:
     psql -U postgres -d data_warehouse -f 03_scripts/bronze/load_bronze_psql.sql

 Solo funciona en psql (pgAdmin no entiende \copy).
=============================================================================
*/

\echo 'Cargando capa Bronze con \\copy...'
\timing on

BEGIN;

TRUNCATE TABLE bronze.crm_cust_info, bronze.crm_prd_info, bronze.crm_sales_details,
               bronze.erp_cust_az12, bronze.erp_loc_a101, bronze.erp_px_cat_g1v2;

\copy bronze.crm_cust_info (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date) FROM '01_datasets/source_crm/cust_info.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy bronze.crm_prd_info (prd_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt) FROM '01_datasets/source_crm/prd_info.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy bronze.crm_sales_details (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price) FROM '01_datasets/source_crm/sales_details.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy bronze.erp_cust_az12 (cid, bdate, gen) FROM '01_datasets/source_erp/CUST_AZ12.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy bronze.erp_loc_a101 (cid, cntry) FROM '01_datasets/source_erp/LOC_A101.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy bronze.erp_px_cat_g1v2 (id, cat, subcat, maintenance) FROM '01_datasets/source_erp/PX_CAT_G1V2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

COMMIT;

\timing off
SELECT 'crm_cust_info' AS table_name, count(*) AS rows FROM bronze.crm_cust_info
UNION ALL SELECT 'crm_prd_info',      count(*) FROM bronze.crm_prd_info
UNION ALL SELECT 'crm_sales_details', count(*) FROM bronze.crm_sales_details
UNION ALL SELECT 'erp_cust_az12',     count(*) FROM bronze.erp_cust_az12
UNION ALL SELECT 'erp_loc_a101',      count(*) FROM bronze.erp_loc_a101
UNION ALL SELECT 'erp_px_cat_g1v2',   count(*) FROM bronze.erp_px_cat_g1v2;
