TRUNCATE raw.customers, raw.geolocation, raw.order_items, raw.order_payments,
  raw.order_reviews, raw.orders, raw.products, raw.sellers, raw.category_translation;

\copy raw.customers FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.geolocation FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_items FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_payments FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_reviews FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.orders FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.products FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.sellers FROM 'C:/Users/lller/olist-postgres-warehouse/data/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.category_translation FROM 'C:/Users/lller/olist-postgres-warehouse/data/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')