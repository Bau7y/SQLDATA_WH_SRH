# Catálogo de datos – capa Gold

La capa Gold es la que consumen los analistas y las herramientas de BI.
Contiene vistas de negocio en un esquema estrella: dos dimensiones, una tabla
de hechos y una vista de reporte.

## gold.dim_customers

Clientes del CRM enriquecidos con datos demográficos y geográficos del ERP.
Una fila por cliente.

| Columna | Tipo | Descripción |
|---|---|---|
| customer_key | BIGINT | Clave subrogada que identifica a cada cliente en la dimensión. |
| customer_id | INT | Identificador numérico del cliente en el CRM. |
| customer_number | VARCHAR(50) | Código alfanumérico del cliente (ej. `AW00011000`), usado para enlazar con el ERP. |
| first_name | VARCHAR(50) | Nombre del cliente. |
| last_name | VARCHAR(50) | Apellido del cliente. |
| country | VARCHAR(50) | País de residencia (ej. `Australia`). `n/a` si no se conoce. |
| marital_status | VARCHAR(50) | Estado civil: `Married`, `Single` o `n/a`. |
| gender | VARCHAR(50) | Género: `Male`, `Female` o `n/a`. Se toma del CRM; si no lo tiene, del ERP. |
| birthdate | DATE | Fecha de nacimiento (AAAA-MM-DD). NULL si no se conoce o era inválida. |
| create_date | DATE | Fecha en que se registró el cliente en el CRM. |

## gold.dim_products

Productos vigentes con su categoría. Una fila por producto (solo la versión
actual de cada uno).

| Columna | Tipo | Descripción |
|---|---|---|
| product_key | BIGINT | Clave subrogada que identifica a cada producto en la dimensión. |
| product_id | INT | Identificador del producto en el CRM. |
| product_number | VARCHAR(50) | Código alfanumérico del producto (ej. `FR-R92B-58`). |
| product_name | VARCHAR(50) | Nombre descriptivo, con tipo, color y tamaño. |
| category_id | VARCHAR(50) | Código de la categoría (ej. `CO_RF`), enlace con el ERP. |
| category | VARCHAR(50) | Categoría general (ej. `Bikes`, `Components`). |
| subcategory | VARCHAR(50) | Subcategoría (ej. `Road Frames`). |
| maintenance | VARCHAR(50) | Indica si el producto requiere mantenimiento (`Yes` / `No`). |
| cost | INT | Costo base del producto. |
| product_line | VARCHAR(50) | Línea: `Mountain`, `Road`, `Touring`, `Other Sales` o `n/a`. |
| start_date | DATE | Fecha desde la que está disponible esta versión del producto. |

## gold.fact_sales

Transacciones de venta. Una fila por línea de pedido.

| Columna | Tipo | Descripción |
|---|---|---|
| order_number | VARCHAR(50) | Número del pedido (ej. `SO54496`). |
| product_key | BIGINT | Producto vendido. Referencia a `dim_products.product_key`. |
| customer_key | BIGINT | Cliente que compró. Referencia a `dim_customers.customer_key`. |
| order_date | DATE | Fecha del pedido. NULL si en el origen era inválida. |
| shipping_date | DATE | Fecha de envío. |
| due_date | DATE | Fecha de vencimiento del pago. |
| sales_amount | INT | Monto total de la línea (`quantity × price`). |
| quantity | INT | Unidades vendidas. |
| price | INT | Precio unitario. |

## gold.report_sales_monthly

Ventas agregadas por mes.

| Columna | Tipo | Descripción |
|---|---|---|
| order_month | DATE | Primer día del mes. |
| total_orders | BIGINT | Pedidos distintos del mes. |
| total_customers | BIGINT | Clientes distintos que compraron en el mes. |
| total_quantity | BIGINT | Unidades vendidas. |
| total_sales | BIGINT | Monto total vendido. |
