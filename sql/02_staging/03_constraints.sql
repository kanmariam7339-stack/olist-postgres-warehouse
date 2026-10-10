alter table staging.customers
add primary key (customer_id);

alter table staging.sellers
add primary key (seller_id);

alter table staging.products
add primary key (product_id);

alter table staging.geolocation
add primary key (zip_code_prefix);

alter table staging.orders
add primary key (order_id);

alter table staging.order_items
add primary key (order_id, order_item_id);

alter table staging.order_payments
add primary key (order_id, payment_sequential);

alter table staging.order_reviews
add primary key (review_id, order_id);

-- Foreign keys
ALTER TABLE staging.orders         ADD FOREIGN KEY (customer_id) REFERENCES staging.customers (customer_id);
ALTER TABLE staging.order_items    ADD FOREIGN KEY (order_id)    REFERENCES staging.orders (order_id);
ALTER TABLE staging.order_items    ADD FOREIGN KEY (product_id)  REFERENCES staging.products (product_id);
ALTER TABLE staging.order_items    ADD FOREIGN KEY (seller_id)   REFERENCES staging.sellers (seller_id);
ALTER TABLE staging.order_payments ADD FOREIGN KEY (order_id)    REFERENCES staging.orders (order_id);
ALTER TABLE staging.order_reviews  ADD FOREIGN KEY (order_id)    REFERENCES staging.orders (order_id);