/*
=============================================================================
 ddl_bronze.sql
 Tablas de la capa Bronze. Conservan los nombres y la estructura de los
 archivos de origen (<sistema>_<entidad>). Solo se agregan dos columnas
 técnicas de trazabilidad: dwh_load_date y dwh_source_file.

 Ejecutar conectado a data_warehouse. Vuelve a crear las tablas.
=============================================================================
*/

-- ----------------------------------------------------------------- CRM
DROP TABLE IF EXISTS bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info
(
    cst_id              INT,
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(50),
    cst_lastname        VARCHAR(50),
    cst_marital_status  VARCHAR(50),
    cst_gndr            VARCHAR(50),
    cst_create_date     DATE,
    dwh_load_date       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    dwh_source_file     VARCHAR(100) NOT NULL DEFAULT 'source_crm/cust_info.csv'
);

DROP TABLE IF EXISTS bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info
(
    prd_id              INT,
    prd_key             VARCHAR(50),
    prd_nm              VARCHAR(50),
    prd_cost            INT,
    prd_line            VARCHAR(50),
    prd_start_dt        DATE,
    prd_end_dt          DATE,
    dwh_load_date       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    dwh_source_file     VARCHAR(100) NOT NULL DEFAULT 'source_crm/prd_info.csv'
);

-- Las fechas llegan como enteros AAAAMMDD (y a veces 0): se guardan como INT.
DROP TABLE IF EXISTS bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details
(
    sls_ord_num         VARCHAR(50),
    sls_prd_key         VARCHAR(50),
    sls_cust_id         INT,
    sls_order_dt        INT,
    sls_ship_dt         INT,
    sls_due_dt          INT,
    sls_sales           INT,
    sls_quantity        INT,
    sls_price           INT,
    dwh_load_date       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    dwh_source_file     VARCHAR(100) NOT NULL DEFAULT 'source_crm/sales_details.csv'
);

-- ----------------------------------------------------------------- ERP
DROP TABLE IF EXISTS bronze.erp_cust_az12;
CREATE TABLE bronze.erp_cust_az12
(
    cid                 VARCHAR(50),
    bdate               DATE,
    gen                 VARCHAR(50),
    dwh_load_date       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    dwh_source_file     VARCHAR(100) NOT NULL DEFAULT 'source_erp/CUST_AZ12.csv'
);

DROP TABLE IF EXISTS bronze.erp_loc_a101;
CREATE TABLE bronze.erp_loc_a101
(
    cid                 VARCHAR(50),
    cntry               VARCHAR(50),
    dwh_load_date       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    dwh_source_file     VARCHAR(100) NOT NULL DEFAULT 'source_erp/LOC_A101.csv'
);

DROP TABLE IF EXISTS bronze.erp_px_cat_g1v2;
CREATE TABLE bronze.erp_px_cat_g1v2
(
    id                  VARCHAR(50),
    cat                 VARCHAR(50),
    subcat              VARCHAR(50),
    maintenance         VARCHAR(50),
    dwh_load_date       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    dwh_source_file     VARCHAR(100) NOT NULL DEFAULT 'source_erp/PX_CAT_G1V2.csv'
);
