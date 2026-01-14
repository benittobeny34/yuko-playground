SELECT
	date::date,
	integrations.store_url,
	integrations.type,
	integrations.status
FROM
	generate_series('2025-08-18'::date, CURRENT_DATE, interval '1 day') AS all_dates (date)
	LEFT JOIN integrations ON integrations.created_at::date = all_dates.date
ORDER BY
	all_dates.date DESC;


select count(*), date(created_at) from integrations group by date(created_at) order by date(created_at) desc;

SELECT
    DATE_TRUNC('month', created_at) AS month,
    COUNT(*) AS total
FROM integrations
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

select * from integrations order by id desc;


-- Total webhook events occurred

SELECT
    DATE(created_at) AS event_date,
    COUNT(*) AS total_events,
SUM(CASE WHEN topic = 'product.updated' THEN 1 ELSE 0 END) AS product_updated,
    SUM(CASE WHEN topic =  'ORDERS_PAID' THEN 1 ELSE 0 END) AS shopify_ORDERS_PAID,
    SUM(CASE WHEN topic = 'SHOP_UPDATE' THEN 1 ELSE 0 END) AS shopify_SHOP_UPDATE,
    SUM(CASE WHEN topic = 'ORDERS_CREATE' THEN 1 ELSE 0 END) AS shopify_ORDERS_CREATE,
    SUM(CASE WHEN topic = 'order.deleted' THEN 1 ELSE 0 END) AS order_deleted,
    SUM(CASE WHEN topic = 'ORDERS_UPDATED' THEN 1 ELSE 0 END) AS shopify_ORDERS_UPDATED,
    SUM(CASE WHEN topic = 'PRODUCTS_UPDATE' THEN 1 ELSE 0 END) AS shopify_PRODUCTS_UPDATE,
    SUM(CASE WHEN topic = 'product.deleted' THEN 1 ELSE 0 END) AS product_deleted,
    SUM(CASE WHEN topic = 'CUSTOMERS_CREATE' THEN 1 ELSE 0 END) AS CUSTOMERS_CREATE,
    SUM(CASE WHEN topic = 'CUSTOMERS_UPDATE' THEN 1 ELSE 0 END) AS CUSTOMERS_UPDATE,
    SUM(CASE WHEN topic = 'ORDERS_CANCELLED' THEN 1 ELSE 0 END) AS ORDERS_CANCELLED,
    SUM(CASE WHEN topic = 'ORDERS_FULFILLED' THEN 1 ELSE 0 END) AS ORDERS_FULFILLED,
    SUM(CASE WHEN topic = 'customer.updated' THEN 1 ELSE 0 END) AS woo_customer_updated,
    SUM(CASE WHEN topic = 'product.restored' THEN 1 ELSE 0 END) AS product_restored,
    SUM(CASE WHEN topic = 'order.yuko_order_paid' THEN 1 ELSE 0 END) AS yuko_order_paid,
    SUM(CASE WHEN topic = 'order.yuko_order_cancelled' THEN 1 ELSE 0 END) AS yuko_order_cancelled,
    SUM(CASE WHEN topic = 'order.yuko_order_fulfilled' THEN 1 ELSE 0 END) AS yuko_order_fulfilled,
    SUM(CASE WHEN topic = 'order.yuko_order_status_change' THEN 1 ELSE 0 END) AS yuko_order_status_change
FROM webhook_events
GROUP BY DATE(created_at)
ORDER BY event_date DESC;

select count(*) from webhook_events where platform = 'shopify' and processed_at is not null;

-- list of events subscribed per event type
SELECT
    ws.created_at::date  AS event_date,
    ws.org_uuid,
    i.store_url,
    e.event_type,
    COUNT(*) AS total_subscribers
FROM workflow_subscribers ws
JOIN events e
    ON e.uuid = ws.event_uuid
JOIN integrations i
    ON i.org_uuid = ws.org_uuid
WHERE ws.created_at::date = CURRENT_DATE
GROUP BY
    ws.created_at::date,
    ws.org_uuid,
    i.store_url,
    e.event_type
ORDER BY
    event_date DESC,
    e.event_type;


--How Many new orders came in each day
SELECT
    o.created_at::date AS day,
    o.org_uuid,
    i.store_url,
    COUNT(*) AS new_orders
FROM orders o
JOIN integrations i
    ON i.org_uuid = o.org_uuid
WHERE o.created_at::date = CURRENT_DATE
GROUP BY
    o.created_at::date,
    o.org_uuid,
    i.store_url
ORDER BY day DESC;


-- How may new customers created in each day
SELECT
    DATE(created_at) AS day,
    COUNT(*) AS new_customers
FROM customers
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- How may new products created in each day
SELECT
    DATE(created_at) AS day,
    COUNT(*) AS new_products
FROM products
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- How may new reviews created in each day
SELECT
    DATE(created_at) AS day,
    COUNT(*) AS reviews
FROM reviews
where source != 'import'
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- How may new order reviews created in each day
SELECT
	reviews.created_at::date AS DAY,
	COUNT(*) AS reviews,
	reviews.org_uuid,
	integrations.store_url
FROM
	reviews
	RIGHT JOIN integrations ON reviews.org_uuid = integrations.org_uuid
WHERE
	reviews.review_parent_uuid IS NULL
	AND reviews.order_uuid IS NOT NULL
	AND reviews.created_at::date = CURRENT_DATE
GROUP BY
	reviews.created_at::date,
	reviews.org_uuid,
	integrations.store_url
ORDER BY
	DAY DESC;



-- GET the emails sent count by organizations
SELECT
	integrations.store_url,
	order_review_request_count
FROM
	(
		SELECT
			count(*) AS order_review_request_count,
			org_uuid
		FROM
			message_histories
		where trigger_type = 'order_review_request'
		and skipped = false
		GROUP BY
			org_uuid
	) AS email_histories
	RIGHT JOIN integrations ON integrations.org_uuid = email_histories.org_uuid
ORDER BY
	order_review_request_count desc NULLS LAST;


select subscriptions.org_uuid, review_requests_sent, integrations.store_url from subscriptions left join integrations on integrations.org_uuid = subscriptions.org_uuid order by review_requests_sent desc;


