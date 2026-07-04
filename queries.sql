-- ============================================================
-- D2C Skincare E-Commerce — SQL-запросы для портфолио
-- Автор: Начинающий аналитик данных
-- База данных: PostgreSQL / MySQL / SQL Server
-- Описание: Запросы от простых к сложным, с комментариями
-- ============================================================


-- ============================================================
-- ЗАПРОС 1: Простой SELECT с фильтрацией и сортировкой
-- Цель: Получить топ-10 самых дорогих товаров с маржой > 50%
-- Навык: SELECT, WHERE, ORDER BY, вычисляемый столбец
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    mrp,
    cost_price,
    mrp - cost_price                         AS margin,
    ROUND((mrp - cost_price) / mrp * 100, 1) AS margin_pct
FROM products
WHERE ROUND((mrp - cost_price) / mrp * 100, 1) > 50
ORDER BY margin_pct DESC
LIMIT 10;


-- ============================================================
-- ЗАПРОС 2: GROUP BY + HAVING + агрегация
-- Цель: Найти каналы продаж, которые принесли > 50 000 ₹ выручки
-- Навык: GROUP BY, HAVING, COUNT, SUM, ROUND
-- ============================================================

SELECT
    sales_channel,
    COUNT(order_id)        AS total_orders,
    SUM(final_amount)      AS total_revenue,
    ROUND(AVG(final_amount), 2) AS avg_order_value,
    MIN(final_amount)      AS min_order,
    MAX(final_amount)      AS max_order
FROM orders
WHERE order_status != 'Cancelled'
GROUP BY sales_channel
HAVING SUM(final_amount) > 50000
ORDER BY total_revenue DESC;


-- ============================================================
-- ЗАПРОС 3: JOIN нескольких таблиц
-- Цель: Получить полную информацию по каждому возврату:
--        имя клиента, название товара, причина, сумма заказа
-- Навык: LEFT JOIN × 3, читаемые алиасы
-- ============================================================

SELECT
    r.return_id,
    r.return_date,
    c.customer_name,
    c.city,
    p.product_name,
    p.category,
    r.return_reason,
    r.refund_status,
    o.final_amount        AS order_amount
FROM returns r
LEFT JOIN orders   o ON r.order_id   = o.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN products p ON r.product_id  = p.product_id
ORDER BY r.return_date DESC;


-- ============================================================
-- ЗАПРОС 4: Подзапрос (subquery)
-- Цель: Найти клиентов, чья суммарная выручка выше средней
--        по всем клиентам (потенциальные VIP-клиенты)
-- Навык: Скалярный подзапрос в WHERE, GROUP BY
-- ============================================================

SELECT
    c.customer_id,
    c.customer_name,
    c.city,
    c.age_group,
    c.acquisition_channel,
    COUNT(o.order_id)        AS total_orders,
    SUM(o.final_amount)      AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY
    c.customer_id,
    c.customer_name,
    c.city,
    c.age_group,
    c.acquisition_channel
HAVING SUM(o.final_amount) > (
    -- Средняя выручка на клиента по всей базе
    SELECT AVG(customer_revenue)
    FROM (
        SELECT customer_id, SUM(final_amount) AS customer_revenue
        FROM orders
        WHERE order_status = 'Delivered'
        GROUP BY customer_id
    ) sub
)
ORDER BY total_spent DESC;


-- ============================================================
-- ЗАПРОС 5: CTE (Common Table Expression)
-- Цель: Рассчитать RFM-метрики для каждого клиента
--        (Recency, Frequency, Monetary)
-- Навык: WITH, DATE_DIFF / DATEDIFF, вложенные CTE
-- ============================================================

WITH last_order_dates AS (
    -- Дата последней покупки по каждому клиенту
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date,
        COUNT(order_id) AS frequency,
        SUM(final_amount) AS monetary
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
snapshot AS (
    -- Дата среза = максимальная дата в данных + 1 день
    SELECT MAX(order_date) + INTERVAL '1 day' AS snap_date
    FROM orders
),
rfm_raw AS (
    SELECT
        l.customer_id,
        c.customer_name,
        c.age_group,
        c.acquisition_channel,
        EXTRACT(DAY FROM (s.snap_date - l.last_order_date)) AS recency_days,
        l.frequency,
        ROUND(l.monetary, 2) AS monetary
    FROM last_order_dates l
    CROSS JOIN snapshot s
    JOIN customers c ON l.customer_id = c.customer_id
)
SELECT
    customer_id,
    customer_name,
    age_group,
    acquisition_channel,
    recency_days,
    frequency,
    monetary,
    CASE
        WHEN recency_days <= 30  THEN 'Активный'
        WHEN recency_days <= 90  THEN 'Теплый'
        WHEN recency_days <= 180 THEN 'Остывающий'
        ELSE                          'Потерянный'
    END AS recency_segment
FROM rfm_raw
ORDER BY monetary DESC;


-- ============================================================
-- ЗАПРОС 6: Оконные функции — ROW_NUMBER, RANK, DENSE_RANK
-- Цель: Ранжировать товары внутри каждой категории
--        по суммарной выручке
-- Навык: WINDOW FUNCTIONS, PARTITION BY, ORDER BY (в окне)
-- ============================================================

WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.mrp,
        SUM(oi.item_total) AS total_revenue,
        COUNT(oi.order_item_id) AS units_sold
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY p.product_id, p.product_name, p.category, p.mrp
)
SELECT
    category,
    product_name,
    mrp,
    total_revenue,
    units_sold,
    -- ROW_NUMBER: уникальный номер даже при одинаковых значениях
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS row_num,
    -- RANK: одинаковые значения получают одинаковый ранг (с пропуском)
    RANK()       OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rank_in_category,
    -- SUM нарастающим итогом внутри категории
    SUM(total_revenue) OVER (
        PARTITION BY category
        ORDER BY total_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM product_revenue
ORDER BY category, rank_in_category;


-- ============================================================
-- ЗАПРОС 7: Аналитика отзывов + процент возвратов по рейтингу
-- Цель: Проверить гипотезу: товары с низким рейтингом
--        возвращают чаще?
-- Навык: CTE + LEFT JOIN + CASE + агрегация + процент
-- ============================================================

WITH review_return AS (
    SELECT
        rv.review_id,
        rv.rating,
        rv.product_id,
        rv.order_id,
        CASE WHEN r.return_id IS NOT NULL THEN 1 ELSE 0 END AS was_returned
    FROM reviews rv
    LEFT JOIN returns r
        ON rv.order_id   = r.order_id
        AND rv.product_id = r.product_id
)
SELECT
    rating,
    COUNT(*)                              AS total_reviews,
    SUM(was_returned)                     AS returned_count,
    ROUND(SUM(was_returned) * 100.0 / COUNT(*), 1) AS return_rate_pct
FROM review_return
GROUP BY rating
ORDER BY rating;


-- ============================================================
-- ЗАПРОС 8: LAG / LEAD — динамика выручки месяц-к-месяцу (MoM)
-- Цель: Посчитать рост/падение выручки по месяцам
-- Навык: LAG() оконная функция, DATE_TRUNC, форматирование
-- ============================================================

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month_start,
        SUM(final_amount) AS revenue
    FROM orders
    WHERE order_status != 'Cancelled'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    TO_CHAR(month_start, 'YYYY-MM') AS month,
    revenue,
    LAG(revenue) OVER (ORDER BY month_start) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month_start))
        / LAG(revenue) OVER (ORDER BY month_start) * 100,
        1
    ) AS mom_growth_pct
FROM monthly
ORDER BY month_start;
