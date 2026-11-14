# Modelo de datos – capa Gold (esquema estrella)

```mermaid
erDiagram
    dim_customers ||--o{ fact_sales : "customer_key"
    dim_products  ||--o{ fact_sales : "product_key"

    dim_customers {
        bigint  customer_key PK
        int     customer_id
        varchar customer_number
        varchar first_name
        varchar last_name
        varchar country
        varchar marital_status
        varchar gender
        date    birthdate
        date    create_date
    }
    dim_products {
        bigint  product_key PK
        int     product_id
        varchar product_number
        varchar product_name
        varchar category_id
        varchar category
        varchar subcategory
        varchar maintenance
        int     cost
        varchar product_line
        date    start_date
    }
    fact_sales {
        varchar order_number
        bigint  product_key FK
        bigint  customer_key FK
        date    order_date
        date    shipping_date
        date    due_date
        int     sales_amount
        int     quantity
        int     price
    }
```

- **Grano de `fact_sales`:** una fila por línea de pedido (`order_number` +
  producto).
- **Claves subrogadas:** `customer_key` y `product_key` se generan con
  `ROW_NUMBER()` en las vistas. No dependen de las claves del sistema origen.
- **Regla de negocio:** `sales_amount = quantity × price`.
- **Vista de reporte:** `gold.report_sales_monthly` agrega por mes los
  pedidos, clientes, unidades y monto de ventas.

## Ejemplo de consulta

```sql
SELECT c.country,
       p.category,
       SUM(f.sales_amount) AS total_sales
FROM   gold.fact_sales f
JOIN   gold.dim_customers c ON c.customer_key = f.customer_key
JOIN   gold.dim_products  p ON p.product_key  = f.product_key
GROUP BY c.country, p.category
ORDER BY total_sales DESC;
```
