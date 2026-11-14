/*
=============================================================================
 proc_load_bronze.sql
 Procedimiento bronze.load_bronze: carga completa (TRUNCATE + COPY) de los
 seis archivos CSV en las tablas de la capa Bronze. No transforma los datos.

 Parámetro:
   p_dataset_path  ruta de la carpeta 01_datasets VISTA DESDE EL SERVIDOR
                   PostgreSQL (usar / como separador, también en Windows).

 Uso:
   CALL bronze.load_bronze('C:/ruta/al/repositorio/01_datasets');

 Requisitos de COPY en el servidor:
   - El usuario debe ser superusuario o tener el rol pg_read_server_files.
   - El servicio de PostgreSQL debe poder leer la carpeta. En Windows el
     servicio no suele tener acceso a la carpeta del usuario (Escritorio,
     OneDrive); en ese caso usar load_bronze_psql.sql o copiar la carpeta a
     una ruta como C:/pg_datasets (ver 00_setup/README.md).

 Cada tabla se registra en audit.load_log. Si una tabla falla, se registra el
 error, se muestra un WARNING y se continúa con las demás.
=============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze(p_dataset_path TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id    UUID := gen_random_uuid();
    v_batch_start TIMESTAMPTZ := clock_timestamp();
    v_start       TIMESTAMPTZ;
    v_rows        BIGINT;
    v_failed      INT := 0;
    v_item        RECORD;
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Cargando capa Bronze (lote %)', v_batch_id;
    RAISE NOTICE '================================================';

    FOR v_item IN
        SELECT * FROM (VALUES
            (1, 'bronze.crm_cust_info',     'source_crm/cust_info.csv',
                'cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date'),
            (2, 'bronze.crm_prd_info',      'source_crm/prd_info.csv',
                'prd_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt'),
            (3, 'bronze.crm_sales_details', 'source_crm/sales_details.csv',
                'sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price'),
            (4, 'bronze.erp_cust_az12',     'source_erp/CUST_AZ12.csv',
                'cid, bdate, gen'),
            (5, 'bronze.erp_loc_a101',      'source_erp/LOC_A101.csv',
                'cid, cntry'),
            (6, 'bronze.erp_px_cat_g1v2',   'source_erp/PX_CAT_G1V2.csv',
                'id, cat, subcat, maintenance')
        ) AS t (seq, table_name, file_name, column_list)
        ORDER BY seq
    LOOP
        v_start := clock_timestamp();
        BEGIN
            EXECUTE format('TRUNCATE TABLE %s', v_item.table_name);
            EXECUTE format('COPY %s (%s) FROM %L WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')',
                           v_item.table_name, v_item.column_list,
                           rtrim(p_dataset_path, '/') || '/' || v_item.file_name);
            GET DIAGNOSTICS v_rows = ROW_COUNT;

            INSERT INTO audit.load_log (batch_id, layer, table_name, start_time, end_time, rows_loaded, status)
            VALUES (v_batch_id, 'bronze', v_item.table_name, v_start, clock_timestamp(), v_rows, 'OK');

            RAISE NOTICE '%: % filas (% s)', rpad(v_item.table_name, 26), v_rows,
                         round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 2);
        EXCEPTION WHEN OTHERS THEN
            v_failed := v_failed + 1;
            INSERT INTO audit.load_log (batch_id, layer, table_name, start_time, end_time, status, error_message)
            VALUES (v_batch_id, 'bronze', v_item.table_name, v_start, clock_timestamp(), 'ERROR', SQLERRM);
            RAISE WARNING '% falló: %', v_item.table_name, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Bronze terminado en % s con % tabla(s) con error.',
                 round(extract(epoch FROM clock_timestamp() - v_batch_start)::numeric, 2), v_failed;
END;
$$;

COMMENT ON PROCEDURE bronze.load_bronze(TEXT) IS
    'Carga completa (truncate & insert) de los CSV de CRM y ERP en la capa Bronze.';
