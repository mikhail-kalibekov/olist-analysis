-- =====================================================================
-- Задача 2 · Подзадача 2.3 - когортный retention
-- Вопрос продакта: какая доля покупателей когорты (месяц первой покупки) покупает снова
--   через 1, 2, 3… месяца.
-- Решения:
--   - месяц жизни считается по календарным месяцам (см. ответы на вопросы ниже);
--   - когорты с 2017-01: когорты 2016 года - 1, 262 и 1 покупатель, выводы по ним не сделать;
--   - заказы в течение суток после предыдущего не считаются возвратом (как в 2.2);
--   - сетка «когорта × месяц» (CROSS JOIN): 0 - месяц есть в данных, но покупок нет;
--     NULL - месяц позже августа 2018, данных ещё нет.
-- Находки: retention в месяц 1 - 0,2–0,7%, дальше держится на 0,1–0,4% без явного затухания.
-- Зависит от: 02_1_first_purchase.sql, 02_2_repeat.sql (VIEW)
-- =====================================================================
-- 	Разбей покупателей на когорты по месяцу первой покупки.
-- 	Для каждой когорты посчитай, какая доля покупателей сделала покупку через 1, 2, 3… месяца после первой.
-- 	Какие когорты включать в таблицу — реши сам и обоснуй.
-- 	Прислать: таблицу «когорта × месяц после первой покупки» в % + размер каждой когорты + 1–2 строки: что видишь.

-- Что такое «месяц 1» для покупателя, который купил впервые 31 января? Февраль или 31 день спустя? 
-- 		Если считать по количеству дней спустя, то непонятно, как привязать эти данные к привычным для человека единицам измерения. Поэтому буду считать по месяцам
-- Покупатель сделал в месяце 2 три заказа. Сколько раз он должен попасть в числитель? 
-- 		1 раз
-- Заказы, сделанные в течение суток после первого, попадут в месяц 0 или в месяц 1?
-- 		Если считать по месяцам - зависит от даты. Если 1 заказ сделан 31 января, а второй 1 февраля, то в разные. Если в течение месяца, то в один месяц


-- v_customer_orders
-- customer_unique_id, order_purchase_timestamp, order_id, rn, first_order_date, date_dif

-- v_first_customers
-- customer_unique_id, first_order_date, cohort_month




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

user_activity AS(
	SELECT 
		c.customer_unique_id, f.cohort_month,
		DATE_TRUNC('month', c.order_purchase_timestamp) AS active_month
	FROM v_customer_orders c
	JOIN v_first_customers f ON c.customer_unique_id = f.customer_unique_id
	WHERE c.first_order_date >= '2017-01-01' AND (rn = 1 OR date_dif > INTERVAL '0 days') -- Нам важно отследить возвращаемость клиентов. Поэтому заказы, которые сделаны менее чем через сутки считаем как тот же заказ
),
cohort_lifetime AS (
	SELECT 
		customer_unique_id, cohort_month, active_month,
		(EXTRACT(YEAR FROM active_month) - EXTRACT(YEAR FROM cohort_month))*12 + (EXTRACT(MONTH FROM active_month) - EXTRACT(MONTH FROM cohort_month)) AS lifetime
	FROM user_activity 
),
cohort_sizes_1 AS (
	SELECT 
		cohort_month, lifetime,
		COUNT(DISTINCT customer_unique_id) AS users_count
	FROM cohort_lifetime
	GROUP BY cohort_month, lifetime
),
cohort_sizes AS (
	SELECT 
		g.cohort_month, 
		g.lifetime, 
		CASE 
			WHEN g.cohort_month + g.lifetime * INTERVAL '1 month' > '2018-08-01' THEN NULL 
			ELSE COALESCE(c.users_count, 0) 
		END AS users_count
	FROM cohort_grid g
	LEFT JOIN cohort_sizes_1 c ON c.cohort_month = g.cohort_month AND g.lifetime  = c.lifetime 
),
pivot_raw_cnt AS (
	SELECT 
		cohort_month,
		MAX(users_count) FILTER (WHERE lifetime = 0) AS m0,
		MAX(users_count) FILTER (WHERE lifetime = 1) AS m1,
		MAX(users_count) FILTER (WHERE lifetime = 2) AS m2,
		MAX(users_count) FILTER (WHERE lifetime = 3) AS m3,
		MAX(users_count) FILTER (WHERE lifetime = 4) AS m4,
		MAX(users_count) FILTER (WHERE lifetime = 5) AS m5,
		MAX(users_count) FILTER (WHERE lifetime = 6) AS m6,
		MAX(users_count) FILTER (WHERE lifetime = 7) AS m7,
		MAX(users_count) FILTER (WHERE lifetime = 8) AS m8,
		MAX(users_count) FILTER (WHERE lifetime = 9) AS m9,
		MAX(users_count) FILTER (WHERE lifetime = 10) AS m10,
		MAX(users_count) FILTER (WHERE lifetime = 11) AS m11,
		MAX(users_count) FILTER (WHERE lifetime = 12) AS m12
	FROM cohort_sizes
	GROUP BY cohort_month 
),
pivot_raw_prcnt AS (
	SELECT
		cohort_month, 
		m0 AS cohort_size,
		ROUND(m0/m0::numeric * 100) AS m0,
		ROUND(m1/m0::numeric * 100, 2) AS m1,
		ROUND(m2/m0::numeric * 100, 2) AS m2,
		ROUND(m3/m0::numeric * 100, 2) AS m3,
		ROUND(m4/m0::numeric * 100, 2) AS m4,
		ROUND(m5/m0::numeric * 100, 2) AS m5,
		ROUND(m6/m0::numeric * 100, 2) AS m6,
		ROUND(m7/m0::numeric * 100, 2) AS m7,
		ROUND(m8/m0::numeric * 100, 2) AS m8,
		ROUND(m9/m0::numeric * 100, 2) AS m9,
		ROUND(m10/m0::numeric * 100, 2) AS m10,
		ROUND(m11/m0::numeric * 100, 2) AS m11,
		ROUND(m12/m0::numeric * 100, 2) AS m12
	FROM pivot_raw_cnt

)

-- Retention, % от размера когорты
SELECT * FROM pivot_raw_prcnt ORDER BY cohort_month;
