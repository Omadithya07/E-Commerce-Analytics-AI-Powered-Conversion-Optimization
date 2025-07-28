SELECT TOP 0 * FROM orders;
SELECT TOP 0 * FROM order_items;
SELECT TOP 0 * FROM order_item_refunds;
SELECT TOP 0 * FROM website_sessions;
SELECT TOP 0 * FROM website_pageviews;
SELECT TOP 0 * FROM products;


--Traffic Overview
--What is the breakdown of website sessions by device type (desktop, mobile, tablet)?
SELECT 
	device_type,
	COUNT(DISTINCT website_session_id) AS Number 
FROM website_sessions
GROUP BY 
	device_type
ORDER BY
	Number DESC;


--Which UTM campaigns and traffic sources are generating the highest number of sessions and conversions?
SELECT 
	a.utm_source,
	a.utm_campaign,
	COUNT(DISTINCT a.website_session_id) AS Session,
	(COUNT(DISTINCT b.order_id) * 1.0 / COUNT(DISTINCT a.website_session_id)) * 100 AS Conversion
FROM website_sessions a
LEFT JOIN orders b
ON a.website_session_id = b.website_session_id
GROUP BY 
	a.utm_source,
	a.utm_campaign
ORDER BY
	Conversion DESC;


--What percentage of sessions come from repeat users versus new users?
SELECT 
    is_repeat_session,
    COUNT(*) AS Session_Count,
    100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS Percentage
FROM website_sessions
GROUP BY is_repeat_session;


--How does website traffic from each source (utm_source) trend over time (monthly), and which sources are increasing or decreasing in session volume?
SELECT 
    FORMAT(created_at, 'yyyy-MM') AS Month,
    utm_source,
    COUNT(*) AS Total_Sessions
FROM website_sessions
GROUP BY FORMAT(created_at, 'yyyy-MM'), utm_source
ORDER BY Month, utm_source;


--User Behavior
--How does bounce rate vary across different landing pages?
WITH first_pageviews AS (
    SELECT 
        wp.website_session_id,
        wp.pageview_url,
        ROW_NUMBER() OVER (PARTITION BY wp.website_session_id ORDER BY wp.created_at) AS rn
    FROM website_pageviews wp
),
landing_pages AS (
    SELECT 
        website_session_id,
        pageview_url AS landing_page
    FROM first_pageviews
    WHERE rn = 1
),
pageview_counts AS (
    SELECT 
        website_session_id,
        COUNT(*) AS total_pageviews
    FROM website_pageviews
    GROUP BY website_session_id
),
combined AS (
    SELECT 
        lp.landing_page,
        pc.total_pageviews
    FROM landing_pages lp
    JOIN pageview_counts pc 
        ON lp.website_session_id = pc.website_session_id
)
SELECT 
    landing_page,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN total_pageviews = 1 THEN 1 ELSE 0 END) AS bounced_sessions,
    CAST(SUM(CASE WHEN total_pageviews = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS bounce_rate_percentage
FROM combined
GROUP BY landing_page
ORDER BY bounce_rate_percentage DESC;




--Most Common User Paths and Drop-offs
WITH session_paths AS (
    SELECT
        website_session_id,
        STRING_AGG(CAST(pageview_url AS VARCHAR(MAX)), ' > ')
            WITHIN GROUP (ORDER BY created_at ASC) AS path
    FROM
        website_pageviews
    GROUP BY
        website_session_id
)
SELECT
    path,
    COUNT(website_session_id) AS total_sessions
FROM
    session_paths
GROUP BY
    path
ORDER BY
    total_sessions DESC;



--Which pages have the highest exit rates and should be prioritized for optimization?
WITH last_pageviews AS (
    SELECT
        website_session_id,
        pageview_url,
        ROW_NUMBER() OVER(PARTITION BY website_session_id ORDER BY created_at DESC) as rn
    FROM
        website_pageviews
),
exit_counts AS (
    SELECT
        pageview_url,
        COUNT(website_session_id) AS exit_count
    FROM
        last_pageviews
    WHERE
        rn = 1 
    GROUP BY
        pageview_url
),
total_pageviews AS (
    SELECT
        pageview_url,
        COUNT(website_pageview_id) AS total_views
    FROM
        website_pageviews
    GROUP BY
        pageview_url
)
SELECT
    tp.pageview_url,
    tp.total_views,
    ec.exit_count,
    CAST(ec.exit_count AS FLOAT) / tp.total_views AS exit_rate
FROM
    total_pageviews tp
JOIN
    exit_counts ec ON tp.pageview_url = ec.pageview_url
ORDER BY
    exit_rate DESC;



--How does the average session duration correlate with conversion rates?
WITH session_duration_info AS (
    SELECT
        s.website_session_id,
        DATEDIFF(second, MIN(p.created_at), MAX(p.created_at)) AS session_duration_seconds,
        MAX(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) AS is_converted_session
    FROM
        website_sessions s
        LEFT JOIN website_pageviews p ON s.website_session_id = p.website_session_id
        LEFT JOIN orders o ON s.website_session_id = o.website_session_id
    GROUP BY
        s.website_session_id
),
duration_buckets AS (
    SELECT
        is_converted_session,
        CASE
            WHEN session_duration_seconds < 30 THEN 'A. 0-30s'
            WHEN session_duration_seconds < 60 THEN 'B. 30-60s'
            WHEN session_duration_seconds < 180 THEN 'C. 1-3 Min'
            WHEN session_duration_seconds < 300 THEN 'D. 3-5 Min'
            ELSE 'E. 5+ Min'
        END AS duration_bucket
    FROM
        session_duration_info
)
SELECT
    duration_bucket,
    SUM(is_converted_session) as converted_sessions, -- CORRECTED LINE
    COUNT(*) AS total_sessions,
    CAST(SUM(is_converted_session) AS FLOAT) / COUNT(*) AS conversion_rate -- CORRECTED LINE
FROM
    duration_buckets
GROUP BY
    duration_bucket
ORDER BY
    duration_bucket;



--2. Product & Sales Performance
--Which products are top-selling by units, revenue, and profit margin?
SELECT
    p.product_name,
    COUNT(oi.order_item_id) AS units_sold,
    SUM(oi.price_usd) AS total_revenue,
    SUM(oi.price_usd - oi.cogs_usd) AS total_profit,
    (SUM(oi.price_usd - oi.cogs_usd) / SUM(oi.price_usd)) AS profit_margin
FROM
    order_items oi
JOIN
    products p ON oi.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    total_revenue DESC;



--What is the attach rate of secondary products (upsell/cross-sell) to primary product purchases?
WITH PrimaryOrders AS (
    SELECT DISTINCT order_id
    FROM order_items
    WHERE is_primary_item = 1
),
SecondaryAttachments AS (
    SELECT DISTINCT oi.order_id
    FROM order_items oi
    INNER JOIN PrimaryOrders po ON oi.order_id = po.order_id
    WHERE oi.is_primary_item = 0
)

SELECT
    CAST(COUNT(*) * 1.0 / (SELECT COUNT(*) FROM PrimaryOrders) * 100 AS DECIMAL(5,2)) AS AttachRatePercent
FROM SecondaryAttachments;



--What is the average order value (AOV) and how does it change by UTM medium, campaign, or device type?
SELECT 
    ws.utm_source,
    AVG(o.price_usd) AS average_order_value,
    COUNT(o.order_id) AS order_count,
    SUM(o.price_usd) AS total_revenue
FROM orders o
JOIN website_sessions ws ON o.website_session_id = ws.website_session_id
GROUP BY ws.utm_source
ORDER BY average_order_value DESC;


SELECT 
    ws.utm_campaign,
    AVG(o.price_usd) AS average_order_value,
    COUNT(o.order_id) AS order_count,
    SUM(o.price_usd) AS total_revenue
FROM orders o
JOIN website_sessions ws ON o.website_session_id = ws.website_session_id
GROUP BY ws.utm_campaign
ORDER BY average_order_value DESC;

SELECT 
    ws.device_type,
    AVG(o.price_usd) AS average_order_value,
    COUNT(o.order_id) AS order_count,
    SUM(o.price_usd) AS total_revenue
FROM orders o
JOIN website_sessions ws ON o.website_session_id = ws.website_session_id
GROUP BY ws.device_type
ORDER BY average_order_value DESC;


--Customer Analytics, Marketing Performance, and Revenue Optimization
--What is the average revenue per user (ARPU) by acquisition channel (utm_source) and device type?
SELECT
    ws.utm_source,
    ws.device_type,
    COUNT(DISTINCT o.user_id) AS user_count,
    SUM(o.price_usd) AS total_revenue,
    CASE 
        WHEN COUNT(DISTINCT o.user_id) = 0 THEN 0
        ELSE SUM(o.price_usd) * 1.0 / COUNT(DISTINCT o.user_id)
    END AS arpu
FROM
    orders o
    INNER JOIN website_sessions ws ON o.website_session_id = ws.website_session_id
GROUP BY
    ws.utm_source,
    ws.device_type
ORDER BY
    arpu DESC;


--What is the churn rate of customers over time by acquisition source and device type?
WITH user_months AS (
  SELECT
    o.user_id,
    DATEPART(YEAR, o.created_at) AS yr,
    DATEPART(MONTH, o.created_at) AS mon,
    MIN(ws.utm_source) AS utm_source, -- use the first session's utm_source
    MIN(ws.device_type) AS device_type
  FROM orders o
  JOIN website_sessions ws ON o.website_session_id = ws.website_session_id
  GROUP BY o.user_id, DATEPART(YEAR, o.created_at), DATEPART(MONTH, o.created_at)
),

churned_users AS (
  SELECT
    curr.yr,
    curr.mon,
    curr.utm_source,
    curr.device_type,
    curr.user_id
  FROM user_months curr
  LEFT JOIN user_months nxt
    ON curr.user_id = nxt.user_id
    AND nxt.yr = CASE WHEN curr.mon = 12 THEN curr.yr + 1 ELSE curr.yr END
    AND nxt.mon = CASE WHEN curr.mon = 12 THEN 1 ELSE curr.mon + 1 END
  WHERE nxt.user_id IS NULL -- No order in the following month
)

SELECT
  curr.yr,
  curr.mon,
  curr.utm_source,
  curr.device_type,
  COUNT(DISTINCT curr.user_id) AS customers_at_start,
  COUNT(DISTINCT churned.user_id) AS churned_customers,
  CASE WHEN COUNT(DISTINCT curr.user_id) = 0 THEN 0
       ELSE COUNT(DISTINCT churned.user_id) * 100.0 / COUNT(DISTINCT curr.user_id)
  END AS churn_rate_pct
FROM user_months curr
LEFT JOIN churned_users churned
  ON curr.user_id = churned.user_id
  AND curr.yr = churned.yr
  AND curr.mon = churned.mon
  AND curr.utm_source = churned.utm_source
  AND curr.device_type = churned.device_type
GROUP BY curr.yr, curr.mon, curr.utm_source, curr.device_type
ORDER BY curr.yr, curr.mon, churn_rate_pct DESC;