TRUNCATE raw.customers, raw.geolocation, raw.order_items, raw.order_payments,
  raw.order_reviews, raw.orders, raw.products, raw.sellers, raw.category_translation;

\copy raw.customers FROM 'data/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.geolocation FROM 'data/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_items FROM 'data/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_payments FROM 'data/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_reviews FROM 'data/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.orders FROM 'data/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.products FROM 'data/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.sellers FROM 'data/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.category_translation FROM 'data/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
