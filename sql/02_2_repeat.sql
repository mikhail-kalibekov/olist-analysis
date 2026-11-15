-- =====================================================================
-- Задача 2 · Подзадача 2.2 - повторные покупки
-- Вопрос продакта: какая доля покупателей делает вторую покупку и через сколько дней.
-- Что делает файл: VIEW v_customer_orders (одна строка = один доставленный заказ покупателя:
--   номер заказа rn, дата первой покупки, дни с прошлого заказа) + три запроса поверх него.
-- Находка: 853 из 2 801 «вторых покупок» (~30%) сделаны в течение суток после предыдущего
--   заказа - скорее всего, это одна корзина, разбитая на несколько заказов (например, от разных
--   продавцов), а не возврат покупателя. Поэтому результаты - в двух версиях.
-- Результат:              с заказами в течение суток | без них
--   повторных покупателей 2 801 (3,00%)              | 1 991 (2,13%)
--   медиана до повторной  28 дней                    | 76 дней
-- =====================================================================
-- Какая доля покупателей сделала вторую покупку?
-- Покупки сделанные в течение 24 часов не считаем как повторную покупку, т.к., вероятно, это вторая часть заказа
-- В запросах для наглядности выведены результаты С и БЕЗ учета покупок в течение 24 часов
-- За повторную покупку также считаем результаты с rn=3, если разница времени покупки между rn=1 и rn=2 меньше 24 часов

DROP VIEW IF EXISTS v_customer_orders;

CREATE OR REPLACE VIEW v_customer_orders AS
WITH customers_full AS (
	SELECT 
 	c.customer_unique_id,
 	o.order_purchase_timestamp,
 	o.order_id
	FROM customers c 
	JOIN orders o ON c.customer_id = o.customer_id AND o.order_status = 'delivered'
),
rn_customers AS (
	SELECT 
		cf.customer_unique_id, cf.order_purchase_timestamp, cf.order_id,
		ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS rn
	FROM customers_full cf
),
day_dif AS (
	SELECT
		customer_unique_id, order_purchase_timestamp, order_id, rn,
		FIRST_VALUE(order_purchase_timestamp) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('day',
		order_purchase_timestamp - LAG(order_purchase_timestamp) OVER(PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp)
		) AS date_dif
	FROM rn_customers
)
SELECT * FROM day_dif;


-- Повторные покупатели - количество (second_buyers_cnt) и доля (second_buyers_prcnt) от всех 
-- С учетом покупок в течение 24 часов - with_0_day - и без учета покупок в течение 24 часов - without_0_day
SELECT
	'with_0_day' AS cond,
	COUNT(*) FILTER(WHERE rn = 2) AS second_buyers_cnt,
	ROUND((COUNT(*) FILTER(WHERE rn = 2) / COUNT(DISTINCT customer_unique_id) :: NUMERIC) * 100, 2) AS second_buyers_prcnt
FROM v_customer_orders
UNION ALL
SELECT 
	'without_0_day' AS cond,
	COUNT(DISTINCT customer_unique_id) FILTER(WHERE rn >= 2 AND date_dif > INTERVAL '0 days') AS second_buyers_cnt,
	ROUND((COUNT(DISTINCT customer_unique_id) FILTER(WHERE rn >= 2 AND date_dif > INTERVAL '0 days') / COUNT(DISTINCT customer_unique_id) :: NUMERIC) * 100, 2) AS second_buyers_prcnt
FROM v_customer_orders;

-- Медиана, через сколько дней происходит повторная покупка
-- С учетом покупок в течение 24 часов - with_0_day - и без учета покупок в течение 24 часов - without_0_day
-- Выросла, т.к. стало меньше результатов, "сдвигавших" значение медианы в меньшую сторону
-- Чтобы учесть повторные заказы с rn=3, если разница времени покупки между rn=1 и rn=2 меньше 24 часов, необходимо
-- рассчитать разницу между первым заказом и минимальной датой заказа, для которой интервал с предыдущим заказом больше 24 часов
WITH edited_date_values AS (
SELECT 
	customer_unique_id,
	DATE_TRUNC('day', MIN(order_purchase_timestamp) - MIN(first_order_date)) AS date_dif_1
FROM v_customer_orders
WHERE date_dif > INTERVAL '0 days'
GROUP BY customer_unique_id
)
SELECT 
	'with_0_day' AS cond,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY date_dif) AS median
FROM v_customer_orders
WHERE rn = 2
UNION ALL
SELECT 
	'without_0_day' AS cond,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY date_dif_1) AS median
FROM edited_date_values;



-- Интервалы, через сколько дней происходит повторная покупка (вторая по счёту, с выделенной группой «в течение суток»)
WITH intervals_1 AS (
	SELECT 
		customer_unique_id,
		date_dif,
		CASE 
			WHEN date_dif =  INTERVAL '0 days' THEN '0. in 24 hours'
			WHEN date_dif >  INTERVAL '0 days' AND date_dif <=  INTERVAL '30 days' THEN '1. under 30 days'
			WHEN date_dif > INTERVAL '30 days' AND date_dif <= INTERVAL '90 days' THEN '2. 31-90 days'
			WHEN date_dif > INTERVAL '90 days' AND date_dif <= INTERVAL '180 days' THEN '3. 91-180 days'
			WHEN date_dif > INTERVAL '180 days' THEN '4. 180+ days'
		END AS day_interval
	FROM v_customer_orders
	WHERE rn = 2
)
SELECT
	day_interval,
	COUNT(*)
FROM intervals_1
GROUP BY day_interval
ORDER BY day_interval;
