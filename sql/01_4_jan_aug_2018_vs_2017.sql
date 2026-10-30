-- Задача 1. Подзадача 1.4 - рост год к году: январь-август 2018 vs январь-август 2017
-- Сравниваем одинаковые месяцы: в 2016 данных почти нет, после августа 2018 нет доставленных заказов
-- Зависит от: 01_0_views.sql

WITH
jan_aug_2017_vs_2018_abs AS (
-- Показатели по количеству заказов, выручке и среднему чеку за январь-август 2017 и 2018 годов
-- Доступные строки в overview - MONTH, orders_count, month_gmv, avg_month_payment,
SELECT
	date_trunc ('year', month) AS YEAR,
	sum(orders_count) AS orders_count,
	sum(month_gmv) AS gmv,
	sum(month_gmv)::numeric / sum(orders_count)::NUMERIC AS avg_payment
FROM v_delivered_monthly o
WHERE (MONTH >= '2017-01-01' AND MONTH < '2017-09-01') OR (MONTH >= '2018-01-01' AND MONTH < '2018-09-01')
GROUP BY year
),

jan_aug_2017_vs_2018 AS (
-- Прирост выручки за январь-август год-к-году 2017 vs 2018

SELECT 
	ja.YEAR,
	
	ja.gmv - LAG(ja.gmv, 1) OVER (ORDER BY year) AS gmv_dif,
	round(
		(ja.gmv - LAG(ja.gmv, 1) OVER (ORDER BY year)) / LAG(ja.gmv, 1) OVER (ORDER BY year) :: NUMERIC * 100 
	, 2)
	AS gmv_prcnt ,
	
	ja.orders_count - LAG(ja.orders_count,1) OVER (ORDER BY year) AS orders_count_dif,
	round(
	(ja.orders_count - LAG(ja.orders_count,1) OVER (ORDER BY year)) / LAG(ja.orders_count,1) OVER (ORDER BY year) :: NUMERIC *100 
	,2)
	AS orders_count_prcnt,
	
	round(ja.avg_payment - LAG(ja.avg_payment, 1) OVER (ORDER BY year),2) AS avg_payment_dif,
	round(
	(ja.avg_payment - LAG(ja.avg_payment, 1) OVER (ORDER BY year)) / LAG(ja.avg_payment, 1) OVER (ORDER BY year) :: NUMERIC * 100
	, 2) AS avg_payment_prcnt
FROM jan_aug_2017_vs_2018_abs ja
)

-- Абсолютные значения по годам:
SELECT * FROM jan_aug_2017_vs_2018_abs;

-- Прирост год к году:
-- SELECT * FROM jan_aug_2017_vs_2018 WHERE gmv_dif IS NOT NULL;
