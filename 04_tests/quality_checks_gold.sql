/*
=============================================================================
 quality_checks_gold.sql
 Revisiones de calidad de la capa Gold: unicidad de las claves subrogadas,
 integridad del modelo en estrella y cuadre con Silver.

 Ejecutar conectado a data_warehouse.
=============================================================================
*/

-- 1. customer_key única. Esperado: sin filas.
SELECT customer_key, COUNT(*)
FROM   gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- 2. product_key única. Esperado: sin filas.
SELECT product_key, COUNT(*)
FROM   gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- 3. Clave de negocio única en cada dimensión. Esperado: sin filas.
SELECT 'dim_customers' AS dimension, customer_id::TEXT AS business_key, COUNT(*)
FROM   gold.dim_customers GROUP BY customer_id HAVING COUNT(*) > 1
UNION ALL
SELECT 'dim_products', product_number, COUNT(*)
FROM   gold.dim_products GROUP BY product_number HAVING COUNT(*) > 1;

-- 4. Integridad del modelo: hechos sin cliente o sin producto. Esperado: sin filas.
SELECT f.*
FROM   gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products  p ON p.product_key  = f.product_key
WHERE  c.customer_key IS NULL OR p.product_key IS NULL;

-- 5. Cuadre con Silver: mismas filas y mismo total de ventas.
--    Esperado: diferencia 0 en ambas columnas.
SELECT (SELECT COUNT(*)        FROM silver.crm_sales_details)
     - (SELECT COUNT(*)        FROM gold.fact_sales)        AS diff_rows,
       (SELECT SUM(sls_sales)  FROM silver.crm_sales_details)
     - (SELECT SUM(sales_amount) FROM gold.fact_sales)      AS diff_sales;

-- 6. Género integrado: valores permitidos. Esperado: Female/Male/n/a.
SELECT gender, COUNT(*)
FROM   gold.dim_customers
GROUP BY gender
ORDER BY gender;

-- 7. Resumen del modelo. Informativo.
SELECT 'dim_customers' AS object_name, COUNT(*) AS rows FROM gold.dim_customers
UNION ALL SELECT 'dim_products', COUNT(*) FROM gold.dim_products
UNION ALL SELECT 'fact_sales',   COUNT(*) FROM gold.fact_sales;
