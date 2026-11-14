/*
=============================================================================
 ddl_gold.sql
 Capa Gold: vistas de negocio en esquema estrella (star schema).
 No se cargan datos: las vistas leen de Silver, por lo que siempre muestran
 el resultado de la última carga.

   gold.dim_customers  dimensión de clientes (CRM + ERP)
   gold.dim_products   dimensión de productos vigentes (CRM + categorías ERP)
   gold.fact_sales     hechos de ventas con las claves subrogadas

 Ejecutar conectado a data_warehouse.
=============================================================================
*/

-- ---------------------------------------------------------------- dim_customers
-- Integración: CRM es la fuente principal. Del ERP se toma la fecha de
-- nacimiento y el país, y el género solo cuando CRM no lo tiene.
DROP VIEW IF EXISTS gold.fact_sales;
DROP VIEW IF EXISTS gold.dim_customers;
CREATE VIEW gold.dim_customers AS
SELECT ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
       ci.cst_id                              AS customer_id,
       ci.cst_key                             AS customer_number,
       ci.cst_firstname                       AS first_name,
       ci.cst_lastname                        AS last_name,
       COALESCE(la.cntry, 'n/a')              AS country,
       ci.cst_marital_status                  AS marital_status,
       CASE WHEN ci.cst_gndr <> 'n/a' THEN ci.cst_gndr
            ELSE COALESCE(ca.gen, 'n/a')
       END                                    AS gender,
       ca.bdate                               AS birthdate,
       ci.cst_create_date                     AS create_date
FROM   silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca ON ca.cid = ci.cst_key
LEFT JOIN silver.erp_loc_a101  la ON la.cid = ci.cst_key;

COMMENT ON VIEW gold.dim_customers IS 'Dimensión de clientes: datos del CRM enriquecidos con país, fecha de nacimiento y género del ERP.';

-- ---------------------------------------------------------------- dim_products
-- Solo la versión vigente de cada producto (prd_end_dt NULL), porque el
-- alcance pide trabajar con el conjunto de datos más reciente.
DROP VIEW IF EXISTS gold.dim_products;
CREATE VIEW gold.dim_products AS
SELECT ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
       pn.prd_id                                                AS product_id,
       pn.prd_key                                               AS product_number,
       pn.prd_nm                                                AS product_name,
       pn.cat_id                                                AS category_id,
       pc.cat                                                   AS category,
       pc.subcat                                                AS subcategory,
       pc.maintenance                                           AS maintenance,
       pn.prd_cost                                              AS cost,
       pn.prd_line                                              AS product_line,
       pn.prd_start_dt                                          AS start_date
FROM   silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc ON pc.id = pn.cat_id
WHERE  pn.prd_end_dt IS NULL;

COMMENT ON VIEW gold.dim_products IS 'Dimensión de productos vigentes con su categoría y subcategoría del ERP.';

-- ---------------------------------------------------------------- fact_sales
-- Una fila por línea de pedido. Las claves de negocio se reemplazan por las
-- claves subrogadas de las dimensiones.
CREATE VIEW gold.fact_sales AS
SELECT sd.sls_ord_num   AS order_number,
       pr.product_key   AS product_key,
       cu.customer_key  AS customer_key,
       sd.sls_order_dt  AS order_date,
       sd.sls_ship_dt   AS shipping_date,
       sd.sls_due_dt    AS due_date,
       sd.sls_sales     AS sales_amount,
       sd.sls_quantity  AS quantity,
       sd.sls_price     AS price
FROM   silver.crm_sales_details sd
LEFT JOIN gold.dim_products  pr ON pr.product_number = sd.sls_prd_key
LEFT JOIN gold.dim_customers cu ON cu.customer_id    = sd.sls_cust_id;

COMMENT ON VIEW gold.fact_sales IS 'Hechos de ventas: una fila por línea de pedido con claves subrogadas.';

-- ---------------------------------------------------------------- report_
-- Ejemplo de vista de reporte (patrón report_ de la convención).
DROP VIEW IF EXISTS gold.report_sales_monthly;
CREATE VIEW gold.report_sales_monthly AS
SELECT DATE_TRUNC('month', f.order_date)::DATE AS order_month,
       COUNT(DISTINCT f.order_number)          AS total_orders,
       COUNT(DISTINCT f.customer_key)          AS total_customers,
       SUM(f.quantity)                         AS total_quantity,
       SUM(f.sales_amount)                     AS total_sales
FROM   gold.fact_sales f
WHERE  f.order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', f.order_date)
ORDER BY order_month;

COMMENT ON VIEW gold.report_sales_monthly IS 'Ventas agregadas por mes: pedidos, clientes, unidades y monto.';
