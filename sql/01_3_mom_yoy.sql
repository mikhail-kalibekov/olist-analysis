-- Задача 1. Подзадача 1.3 - динамика: MoM и YoY по месяцам (в % и в абсолютных значениях)
-- Зависит от: 01_0_views.sql

WITH
mom_1 AS (
-- 3. Сравнение MOM - месяц к месяцу, и YOY - год к году
SELECT
		MONTH,
		
		orders_count, 
		LAG(orders_count, 1) OVER (
	ORDER BY MONTH) AS prev_month_orders_count,
		LAG(orders_count, 12) OVER (
	ORDER BY MONTH) AS prev_year_orders_count,
		
		month_gmv, 
		LAG(month_gmv, 1) OVER (
	ORDER BY MONTH) AS prev_month_gmv,
		LAG(month_gmv, 12) OVER (
	ORDER BY MONTH) AS prev_year_month_gmv,
		
		avg_month_payment,
		LAG(avg_month_payment, 1) OVER (
	ORDER BY MONTH) AS prev_month_avg_month_payment,
		LAG(avg_month_payment, 12) OVER (
	ORDER BY MONTH) AS prev_year_avg_month_payment
FROM v_delivered_monthly
ORDER BY MONTH DESC
),
mom_yoy_prcnt AS (
-- 3. Сравнение MOM - месяц к месяцу, и YOY - год к году - в процентах
SELECT
		MONTH,
		
		orders_count,
		round( ((orders_count - prev_month_orders_count) / NULLIF(prev_month_orders_count::NUMERIC, 0)) * 100, 1) AS mom_count_prcnt,
		round( ((orders_count - prev_year_orders_count) / NULLIF(prev_year_orders_count::NUMERIC, 0)) * 100, 1) AS yoy_count_prcnt,
		
		month_gmv,
		round( ((month_gmv - prev_month_gmv) / NULLIF(prev_month_gmv, 0)) * 100, 1 ) AS mom_gmv_prcnt,
		round( ((month_gmv - prev_year_month_gmv) / NULLIF(prev_year_month_gmv, 0)) * 100, 1 ) AS yoy_gmv_prcnt,
		
		avg_month_payment,
		round( ((avg_month_payment - prev_month_avg_month_payment) / NULLIF(prev_month_avg_month_payment, 0)) * 100, 1 ) AS mom_avg_month_payment_prcnt,
		round( ((avg_month_payment - prev_year_avg_month_payment) / NULLIF(prev_year_avg_month_payment, 0)) * 100, 1 ) AS yoy_avg_month_payment_prcnt
FROM mom_1
-- TODO (ревью): справа в ряду будут сентябрь-октябрь 2018 с 0 доставленных и YoY -100%: реши, показывать ли их
WHERE MONTH >= '2017-01-01'
ORDER BY MONTH DESC
),
mom_yoy_dif AS (
-- 3. Сравнение MOM - месяц к месяцу, и YOY - год к году - в абсолютных значениях. январь-август 2018 vs 2017 год
SELECT
		MONTH,
		
		orders_count,
		orders_count - prev_month_orders_count AS mom_count_dif,
		orders_count - prev_year_orders_count AS yoy_count_dif,
		
		month_gmv,
		month_gmv - prev_month_gmv AS mom_gmv_dif,
		month_gmv - prev_year_month_gmv AS yoy_gmv_dif,
		
		avg_month_payment,
		avg_month_payment - prev_month_avg_month_payment AS mom_avg_month_payment_dif,
		avg_month_payment - prev_year_avg_month_payment AS yoy_avg_month_payment_dif
FROM
	mom_1
WHERE (MONTH >= '2018-01-01' AND MONTH <= '2018-08-31')
ORDER BY MONTH DESC
)

SELECT * FROM mom_yoy_prcnt ORDER BY MONTH;
-- В абсолютных значениях (янв-авг 2018):
-- SELECT * FROM mom_yoy_dif ORDER BY MONTH;
