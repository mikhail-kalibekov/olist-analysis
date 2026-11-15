-- =====================================================================
-- Задача 2 · Подзадача 2.4 - LTV по когортам
-- Вопрос продакта: сколько GMV в среднем приносит покупатель когорты за 3, 6 и 12 месяцев
--   с первой покупки (накопленно) и какая доля приходится на первую покупку.
-- Решения:
--   - деньги = GMV из payments по доставленным заказам (как в задаче 1);
--   - заказы в течение суток здесь НЕ исключаются: в retention считаем возвраты, а в LTV - деньги,
--     и эти заказы - реальные деньги покупателя;
--   - сетка «когорта × месяц» + правый край: после августа 2018 - NULL, в том числе
--     после накопленной суммы (SUM() OVER пропускает NULL).
-- Находки: LTV когорт 2017 года за 12 месяцев - 154–181 R$; месяц первой покупки даёт 96–98% LTV,
--   следующие 11 месяцев добавляют 2–4%.
-- Зависит от: 02_1_first_purchase.sql, 02_2_repeat.sql (VIEW)
--
-- v_customer_orders: customer_unique_id, order_purchase_timestamp, order_id, rn, first_order_date, date_dif
-- =====================================================================

WITH 
lifetime_full AS (
	SELECT generate_series(0, 12) AS lifetime
),
cohort_full AS (
	SELECT DISTINCT cohort_month 
	FROM v_first_customers
	WHERE cohort_month >= '2017-01-01'
),
cohort_grid AS (
	SELECT cohort_month, lifetime 
	FROM lifetime_full CROSS JOIN cohort_full
),
user_orders AS (
	SELECT 
		c.customer_unique_id, c.order_purchase_timestamp, c.order_id, c.first_order_date, f.cohort_month,
		DATE_TRUNC('month', c.order_purchase_timestamp) AS active_month,
		p.payment_value 
	FROM v_customer_orders c
	JOIN v_first_customers f ON c.customer_unique_id = f.customer_unique_id
	JOIN payments p ON c.order_id = p.order_id
	WHERE c.first_order_date >= '2017-01-01' --AND (rn = 1 OR date_dif > INTERVAL '0 days') -- Для рассчета LTV нам важно посчитать сумму по всем заказам, поэтому это условие не нужно
),
cohort_lifetime AS (
	SELECT 
		customer_unique_id, cohort_month, active_month, payment_value,
		(EXTRACT(YEAR FROM active_month) - EXTRACT(YEAR FROM cohort_month))*12 + (EXTRACT(MONTH FROM active_month) - EXTRACT(MONTH FROM cohort_month)) AS lifetime
	FROM user_orders 
),
cohort_sizes_1 AS (
	SELECT 
		cohort_month, lifetime,
		COUNT(DISTINCT customer_unique_id) AS users_count,
		SUM(payment_value) AS cohort_payment
	FROM cohort_lifetime
	GROUP BY cohort_month, lifetime
),
cohort_sizes AS (
	SELECT 
		g.cohort_month, g.lifetime,
		CASE 
			WHEN g.cohort_month + g.lifetime * INTERVAL '1 month' > '2018-08-01' THEN NULL 
			ELSE COALESCE(c.users_count, 0) 
		END AS users_count,
		CASE 
			WHEN g.cohort_month + g.lifetime * INTERVAL '1 month' > '2018-08-01' THEN NULL 
			ELSE COALESCE(c.cohort_payment, 0) 
		END AS cohort_payment
	FROM cohort_grid g
	LEFT JOIN cohort_sizes_1 c ON g.cohort_month = c.cohort_month AND g.lifetime = c.lifetime 

),
cohort_payment_sum AS (
	SELECT
		cohort_month, lifetime, users_count,
		FIRST_VALUE(users_count) OVER (PARTITION BY cohort_month ORDER BY lifetime) AS cohort_users_count,
		CASE 
			WHEN cohort_month + lifetime * INTERVAL '1 month' > '2018-08-01' THEN NULL 
			ELSE SUM(cohort_payment) OVER(PARTITION BY cohort_month ORDER BY lifetime) 
		END AS cohort_gmv
	FROM cohort_sizes
),
pivot_payment_sum AS (
	SELECT 
		cohort_month,
		MAX(cohort_users_count) AS cohort_users_count,
		MAX(cohort_gmv) FILTER (WHERE lifetime = 0) m0,
		MAX(cohort_gmv) FILTER (WHERE lifetime = 3) m3,
		MAX(cohort_gmv) FILTER (WHERE lifetime = 6) m6,
		MAX(cohort_gmv) FILTER (WHERE lifetime = 12) m12
	FROM cohort_payment_sum
	GROUP BY cohort_month
),
pivot_ltv AS (
	SELECT 
		cohort_month,
		ROUND(m0::numeric / cohort_users_count::NUMERIC, 2) AS m0,
		ROUND(m3::numeric / cohort_users_count::NUMERIC, 2) AS m3,
		ROUND(m6::numeric / cohort_users_count::NUMERIC, 2) AS m6,
		ROUND(m12::numeric / cohort_users_count::NUMERIC, 2) AS m12
	FROM pivot_payment_sum
),
pivot_ltv_prcnt_of_m0 AS (
	SELECT 
		cohort_month,
		ROUND(m0/m0::numeric * 100, 1) AS m0,
		ROUND(m0/m3::numeric * 100, 1) AS m3,
		ROUND(m0/m6::numeric * 100, 1) AS m6,
		ROUND(m0/m12::numeric * 100, 1) AS m12
	FROM pivot_ltv 
)


-- Сколько GMV в среднем приносит покупатель когорты за 3, 6 и 12 месяцев с первой покупки (накопленно)? 
SELECT * FROM pivot_ltv ORDER BY cohort_month;


-- Какая доля этого LTV приходится на первую покупку, а какая на повторные?
-- (доля месяца первой покупки в LTV, %)
-- SELECT * FROM pivot_ltv_prcnt_of_m0 ORDER BY cohort_month;
