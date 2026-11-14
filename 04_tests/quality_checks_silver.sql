/*
=============================================================================
 quality_checks_silver.sql
 Revisiones de calidad de la capa Silver después de CALL silver.load_silver().
 Cada consulta indica el resultado esperado. Si una devuelve filas cuando se
 esperaba "sin filas", hay un problema que revisar en la carga.

 Ejecutar conectado a data_warehouse.
=============================================================================
*/

-- ====================================================== silver.crm_cust_info
-- 1. Clave primaria nula o duplicada. Esperado: sin filas.
SELECT cst_id, COUNT(*)
FROM   silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- 2. Espacios sobrantes. Esperado: sin filas.
SELECT cst_key, cst_firstname, cst_lastname
FROM   silver.crm_cust_info
WHERE  cst_key       <> TRIM(cst_key)
   OR  cst_firstname <> TRIM(cst_firstname)
   OR  cst_lastname  <> TRIM(cst_lastname);

-- 3. Valores estandarizados. Esperado: solo Single/Married/n/a y Female/Male/n/a.
SELECT DISTINCT cst_marital_status, cst_gndr
FROM   silver.crm_cust_info
ORDER BY 1, 2;

-- ====================================================== silver.crm_prd_info
-- 4. Clave primaria nula o duplicada. Esperado: sin filas.
SELECT prd_id, COUNT(*)
FROM   silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- 5. Costos nulos o negativos. Esperado: sin filas.
SELECT prd_id, prd_cost
FROM   silver.crm_prd_info
WHERE  prd_cost < 0 OR prd_cost IS NULL;

-- 6. Línea de producto. Esperado: Mountain/Road/Other Sales/Touring/n/a.
SELECT DISTINCT prd_line
FROM   silver.crm_prd_info
ORDER BY 1;

-- 7. Fecha de fin anterior a la de inicio. Esperado: sin filas.
SELECT prd_key, prd_start_dt, prd_end_dt
FROM   silver.crm_prd_info
WHERE  prd_end_dt < prd_start_dt;

-- 8. Más de una versión vigente por producto. Esperado: sin filas.
SELECT prd_key, COUNT(*)
FROM   silver.crm_prd_info
WHERE  prd_end_dt IS NULL
GROUP BY prd_key
HAVING COUNT(*) > 1;

-- ====================================================== silver.crm_sales_details
-- 9. Orden de las fechas: pedido <= envío y pedido <= vencimiento. Esperado: sin filas.
SELECT sls_ord_num, sls_order_dt, sls_ship_dt, sls_due_dt
FROM   silver.crm_sales_details
WHERE  sls_order_dt > sls_ship_dt
   OR  sls_order_dt > sls_due_dt;

-- 10. Regla de negocio ventas = cantidad * precio, sin nulos ni negativos.
--     Esperado: sin filas.
SELECT sls_ord_num, sls_sales, sls_quantity, sls_price
FROM   silver.crm_sales_details
WHERE  sls_sales <> sls_quantity * sls_price
   OR  sls_sales    IS NULL OR sls_sales    <= 0
   OR  sls_quantity IS NULL OR sls_quantity <= 0
   OR  sls_price    IS NULL OR sls_price    <= 0;

-- 11. Fechas de pedido que no se pudieron convertir (se dejaron en NULL).
--     Informativo: muestra cuántas venían en 0 o mal formadas en el origen.
SELECT COUNT(*) AS order_dates_null
FROM   silver.crm_sales_details
WHERE  sls_order_dt IS NULL;

-- ====================================================== silver.erp_cust_az12
-- 12. Fechas de nacimiento fuera de rango. Esperado: sin filas futuras.
SELECT cid, bdate
FROM   silver.erp_cust_az12
WHERE  bdate > CURRENT_DATE;

-- 13. Género estandarizado. Esperado: Female/Male/n/a.
SELECT DISTINCT gen
FROM   silver.erp_cust_az12
ORDER BY 1;

-- ====================================================== silver.erp_loc_a101
-- 14. Países estandarizados. Esperado: nombres completos y n/a, sin códigos.
SELECT DISTINCT cntry
FROM   silver.erp_loc_a101
ORDER BY 1;

-- ====================================================== silver.erp_px_cat_g1v2
-- 15. Espacios sobrantes. Esperado: sin filas.
SELECT *
FROM   silver.erp_px_cat_g1v2
WHERE  cat <> TRIM(cat) OR subcat <> TRIM(subcat) OR maintenance <> TRIM(maintenance);

-- ====================================================== Integración entre fuentes
-- 16. Clientes del CRM sin datos en el ERP. Informativo.
SELECT COUNT(*) AS crm_without_erp_birthdate
FROM   silver.crm_cust_info ci
WHERE  NOT EXISTS (SELECT 1 FROM silver.erp_cust_az12 ca WHERE ca.cid = ci.cst_key);

-- 17. Productos cuya categoría no existe en el ERP. Informativo.
SELECT DISTINCT cat_id
FROM   silver.crm_prd_info p
WHERE  NOT EXISTS (SELECT 1 FROM silver.erp_px_cat_g1v2 c WHERE c.id = p.cat_id);

-- 18. Ventas con un producto o cliente que no existe en el CRM. Esperado: sin filas.
SELECT s.sls_ord_num, s.sls_prd_key, s.sls_cust_id
FROM   silver.crm_sales_details s
WHERE  NOT EXISTS (SELECT 1 FROM silver.crm_prd_info  p WHERE p.prd_key = s.sls_prd_key)
   OR  NOT EXISTS (SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_id  = s.sls_cust_id);
