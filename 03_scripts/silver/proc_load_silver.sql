/*
=============================================================================
 proc_load_silver.sql
 Procedimiento silver.load_silver: carga completa (TRUNCATE + INSERT) de la
 capa Silver a partir de Bronze, aplicando limpieza, estandarización,
 normalización, columnas derivadas y enriquecimiento.

 Uso:
   CALL silver.load_silver();

 Reglas aplicadas por tabla
 ---------------------------------------------------------------------------
 crm_cust_info     - Se descartan los registros sin cst_id.
                   - Duplicados de cst_id: se conserva el más reciente
                     (cst_create_date mayor).
                   - TRIM de nombres.
                   - Estado civil S/M -> Single/Married; género F/M ->
                     Female/Male; lo demás -> 'n/a'.
 crm_prd_info      - prd_key se separa en cat_id (5 primeros caracteres,
                     '-' -> '_') y prd_key (desde el carácter 7).
                   - prd_cost nulo -> 0.
                   - Línea M/R/S/T -> Mountain/Road/Other Sales/Touring.
                   - prd_end_dt se recalcula: un día antes del inicio de la
                     siguiente versión del mismo producto (la de origen
                     viene con fechas de fin anteriores al inicio).
 crm_sales_details - Fechas AAAAMMDD a DATE; 0 o longitud distinta de 8 -> NULL.
                   - Ventas nulas, <= 0 o distintas de cantidad * |precio|
                     se recalculan como cantidad * |precio|.
                   - Precio nulo o <= 0 se recalcula como ventas / cantidad.
 erp_cust_az12     - Se quita el prefijo 'NAS' de cid para enlazar con cst_key.
                   - Fechas de nacimiento futuras -> NULL.
                   - Género normalizado a Female/Male/'n/a'.
 erp_loc_a101      - Se quitan los guiones de cid para enlazar con cst_key.
                   - País: DE -> Germany, US/USA -> United States,
                     vacío -> 'n/a'.
 erp_px_cat_g1v2   - TRIM de los textos (los datos ya vienen limpios).
=============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
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
    RAISE NOTICE 'Cargando capa Silver (lote %)', v_batch_id;
    RAISE NOTICE '================================================';

    FOR v_item IN
        SELECT * FROM (VALUES
        -- ------------------------------------------------------- CRM clientes
        (1, 'silver.crm_cust_info', $q$
            INSERT INTO silver.crm_cust_info
                (cst_id, cst_key, cst_firstname, cst_lastname,
                 cst_marital_status, cst_gndr, cst_create_date)
            SELECT cst_id,
                   TRIM(cst_key),
                   TRIM(cst_firstname),
                   TRIM(cst_lastname),
                   CASE UPPER(TRIM(cst_marital_status))
                        WHEN 'S' THEN 'Single'
                        WHEN 'M' THEN 'Married'
                        ELSE 'n/a'
                   END,
                   CASE UPPER(TRIM(cst_gndr))
                        WHEN 'F' THEN 'Female'
                        WHEN 'M' THEN 'Male'
                        ELSE 'n/a'
                   END,
                   cst_create_date
            FROM  (SELECT *,
                          ROW_NUMBER() OVER (PARTITION BY cst_id
                                             ORDER BY cst_create_date DESC NULLS LAST) AS flag_last
                   FROM   bronze.crm_cust_info
                   WHERE  cst_id IS NOT NULL) t
            WHERE  flag_last = 1
        $q$),
        -- ------------------------------------------------------- CRM productos
        (2, 'silver.crm_prd_info', $q$
            INSERT INTO silver.crm_prd_info
                (prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line,
                 prd_start_dt, prd_end_dt)
            SELECT prd_id,
                   REPLACE(SUBSTRING(TRIM(prd_key) FROM 1 FOR 5), '-', '_'),
                   SUBSTRING(TRIM(prd_key) FROM 7),
                   TRIM(prd_nm),
                   COALESCE(prd_cost, 0),
                   CASE UPPER(TRIM(prd_line))
                        WHEN 'M' THEN 'Mountain'
                        WHEN 'R' THEN 'Road'
                        WHEN 'S' THEN 'Other Sales'
                        WHEN 'T' THEN 'Touring'
                        ELSE 'n/a'
                   END,
                   prd_start_dt,
                   LEAD(prd_start_dt) OVER (PARTITION BY TRIM(prd_key)
                                            ORDER BY prd_start_dt) - 1
            FROM   bronze.crm_prd_info
        $q$),
        -- ------------------------------------------------------- CRM ventas
        (3, 'silver.crm_sales_details', $q$
            INSERT INTO silver.crm_sales_details
                (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt,
                 sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price)
            SELECT TRIM(sls_ord_num),
                   TRIM(sls_prd_key),
                   sls_cust_id,
                   CASE WHEN sls_order_dt <= 0 OR LENGTH(sls_order_dt::TEXT) <> 8 THEN NULL
                        ELSE TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD') END,
                   CASE WHEN sls_ship_dt <= 0 OR LENGTH(sls_ship_dt::TEXT) <> 8 THEN NULL
                        ELSE TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD') END,
                   CASE WHEN sls_due_dt <= 0 OR LENGTH(sls_due_dt::TEXT) <> 8 THEN NULL
                        ELSE TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD') END,
                   CASE WHEN sls_sales IS NULL OR sls_sales <= 0
                             OR sls_sales <> sls_quantity * ABS(sls_price)
                        THEN sls_quantity * ABS(sls_price)
                        ELSE sls_sales END,
                   sls_quantity,
                   CASE WHEN sls_price IS NULL OR sls_price <= 0
                        THEN sls_sales / NULLIF(sls_quantity, 0)
                        ELSE sls_price END
            FROM   bronze.crm_sales_details
        $q$),
        -- ------------------------------------------------------- ERP clientes
        (4, 'silver.erp_cust_az12', $q$
            INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
            SELECT CASE WHEN TRIM(cid) LIKE 'NAS%' THEN SUBSTRING(TRIM(cid) FROM 4)
                        ELSE TRIM(cid) END,
                   CASE WHEN bdate > CURRENT_DATE THEN NULL ELSE bdate END,
                   CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                        ELSE 'n/a' END
            FROM   bronze.erp_cust_az12
        $q$),
        -- ------------------------------------------------------- ERP ubicación
        (5, 'silver.erp_loc_a101', $q$
            INSERT INTO silver.erp_loc_a101 (cid, cntry)
            SELECT REPLACE(TRIM(cid), '-', ''),
                   CASE WHEN UPPER(TRIM(cntry)) = 'DE'           THEN 'Germany'
                        WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
                        WHEN cntry IS NULL OR TRIM(cntry) = ''   THEN 'n/a'
                        ELSE TRIM(cntry) END
            FROM   bronze.erp_loc_a101
        $q$),
        -- ------------------------------------------------------- ERP categorías
        (6, 'silver.erp_px_cat_g1v2', $q$
            INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
            SELECT TRIM(id), TRIM(cat), TRIM(subcat), TRIM(maintenance)
            FROM   bronze.erp_px_cat_g1v2
        $q$)
        ) AS t (seq, table_name, insert_sql)
        ORDER BY seq
    LOOP
        v_start := clock_timestamp();
        BEGIN
            EXECUTE format('TRUNCATE TABLE %s', v_item.table_name);
            EXECUTE v_item.insert_sql;
            GET DIAGNOSTICS v_rows = ROW_COUNT;

            INSERT INTO audit.load_log (batch_id, layer, table_name, start_time, end_time, rows_loaded, status)
            VALUES (v_batch_id, 'silver', v_item.table_name, v_start, clock_timestamp(), v_rows, 'OK');

            RAISE NOTICE '%: % filas (% s)', rpad(v_item.table_name, 26), v_rows,
                         round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 2);
        EXCEPTION WHEN OTHERS THEN
            v_failed := v_failed + 1;
            INSERT INTO audit.load_log (batch_id, layer, table_name, start_time, end_time, status, error_message)
            VALUES (v_batch_id, 'silver', v_item.table_name, v_start, clock_timestamp(), 'ERROR', SQLERRM);
            RAISE WARNING '% falló: %', v_item.table_name, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Silver terminado en % s con % tabla(s) con error.',
                 round(extract(epoch FROM clock_timestamp() - v_batch_start)::numeric, 2), v_failed;
END;
$$;

COMMENT ON PROCEDURE silver.load_silver() IS
    'Carga completa de la capa Silver desde Bronze con limpieza y estandarización.';
