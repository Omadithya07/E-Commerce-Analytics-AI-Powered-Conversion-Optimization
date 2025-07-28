CREATE DATABASE OrderDB;
USE OrderDB;
SELECT TOP 0 * FROM website_sessions;
SELECT TOP 0 * FROM website_pageviews;
SELECT TOP 0 * FROM products;
SELECT TOP 0 * FROM orders;
SELECT TOP 0 * FROM order_items;
SELECT TOP 0 * FROM order_item_refunds;

ALTER TABLE website_pageviews
ADD CONSTRAINT FK_website_pageviews_session
FOREIGN KEY (website_session_id) REFERENCES website_sessions(website_session_id);

ALTER TABLE orders
ADD CONSTRAINT FK_orders_session
FOREIGN KEY (website_session_id) REFERENCES website_sessions(website_session_id);

ALTER TABLE orders
ADD CONSTRAINT FK_orders_product
FOREIGN KEY (primary_product_id) REFERENCES products(product_id);

ALTER TABLE order_items
ADD CONSTRAINT FK_order_items_order
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_items
ADD CONSTRAINT FK_order_items_product
FOREIGN KEY (product_id) REFERENCES products(product_id);

ALTER TABLE order_item_refunds
ADD CONSTRAINT FK_refunds_order
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_item_refunds
ADD CONSTRAINT FK_refunds_order_item
FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id);

ALTER TABLE orders
ALTER COLUMN primary_product_id BIGINT NOT NULL;
ALTER TABLE orders
ADD CONSTRAINT FK_orders_product
FOREIGN KEY (primary_product_id) REFERENCES products(product_id);

CREATE NONCLUSTERED INDEX IX_website_sessions_user_id 
ON website_sessions(user_id);

CREATE NONCLUSTERED INDEX IX_website_sessions_created_at 
ON website_sessions(created_at);

CREATE NONCLUSTERED INDEX IX_website_sessions_utm_source 
ON website_sessions(utm_source);

CREATE NONCLUSTERED INDEX IX_website_sessions_utm_campaign 
ON website_sessions(utm_campaign);

CREATE NONCLUSTERED INDEX IX_website_sessions_device_type 
ON website_sessions(device_type);

CREATE NONCLUSTERED INDEX IX_website_sessions_http_referer 
ON website_sessions(http_referer);

CREATE NONCLUSTERED INDEX IX_pageviews_session 
ON website_pageviews(website_session_id);

CREATE NONCLUSTERED INDEX IX_orders_session 
ON orders(website_session_id);

CREATE NONCLUSTERED INDEX IX_orders_user_id 
ON orders(user_id);

CREATE NONCLUSTERED INDEX IX_order_items_order 
ON order_items(order_id);

CREATE NONCLUSTERED INDEX IX_order_items_product 
ON order_items(product_id);

CREATE NONCLUSTERED INDEX IX_refunds_order 
ON order_item_refunds(order_id);

CREATE NONCLUSTERED INDEX IX_refunds_order_item 
ON order_item_refunds(order_item_id);

SELECT DISTINCT utm_source FROM website_sessions;
UPDATE website_sessions
SET http_referer = 'Direct'
WHERE http_referer IS NULL;

ALTER TABLE website_sessions
ALTER COLUMN is_repeat_session VARCHAR(20);

UPDATE website_sessions
SET is_repeat_session = 
    CASE 
        WHEN is_repeat_session = 0 THEN 'New User'
        ELSE 'Repeat User'
END;