-- Задача 1. Подзадача 1.2 - отменённые и недоставленные по месяцам: сколько и на какую сумму
-- Самостоятельный файл (свой календарь), от VIEW не зависит

WITH 
calendar_day AS (
SELECT
	generate_series(
	'2016-09-01':: date, -- первая дата в данных - 2016-09-04
	'2018-10-31'::date, -- последняя дата в данных - 2018-10-17
	'1 day'::INTERVAL
	)::date AS DAY
),
overview_canceled_1 AS (
-- Сумма отмененных заказов по дням - с пропусками
-- В таблице orders нет повторяющихся order_id (все уникальные), 
-- В payments - есть повторяющиеся order_id
-- left join к таблице payments
-- TODO (ревью): комментарий устарел: база теперь orders, payments присоединяется
SELECT
		date_trunc('day', o.order_purchase_timestamp) AS purchase_date,
		count(DISTINCT o.order_id) AS orders_count,
		sum(p.payment_value) AS day_gmv
FROM
	orders o
LEFT JOIN payments p ON
	p.order_id = o.order_id
WHERE
	o.order_status IN ('shipped', 'unavailable', 'invoiced', 'created', 'approved', 'processing', 'canceled')
	-- TODO (ревью): старую строку с OR можно удалить
	-- 'shipped' or o.order_status = 'unavailable' or o.order_status = 'invoiced' or o.order_status = 'created' or o.order_status = 'approved' or o.order_status = 'processing'  or o.order_status = 'canceled'
GROUP BY
	purchase_date
ORDER BY
	purchase_date
),
overview_canceled_2 AS (
-- Сумма отмененных заказов по дням - без пропусков 
-- В календаре есть все даты, если значения для какой-то даты нет, то ставится 0
SELECT
		cd.day,
		COALESCE(oc1.orders_count, 0) AS orders_count,
		COALESCE(oc1.day_gmv, 0) AS day_gmv
FROM
	calendar_day cd
LEFT JOIN overview_canceled_1 oc1 ON
	oc1.purchase_date = cd.day
ORDER BY
	cd.day
),
overview_canceled_3 AS (
-- Сумма отмененных заказов по месяцам - без пропусков
SELECT
		date_trunc('month', oc2.day) AS MONTH,
		sum(oc2.orders_count) AS orders_count,
		sum(oc2.day_gmv) AS month_gmv
FROM
	overview_canceled_2 oc2
GROUP BY
	MONTH
ORDER BY
	MONTH DESC
),
overview_canceled AS (
-- 2. Отменённые и недоставленные по месяцам отдельно: сколько их и на какую сумму.
SELECT
		MONTH,
	orders_count, 
		round(oc.month_gmv::NUMERIC, 2) AS month_gmv,
		round(oc.month_gmv::NUMERIC / NULLIF(orders_count::NUMERIC, 0), 2) AS avg_month_payment
FROM
	overview_canceled_3 oc
)

SELECT *
FROM overview_canceled
ORDER BY MONTH;
