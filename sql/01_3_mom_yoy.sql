-- =====================================================================
-- Задача 1 · Подзадача 1.3 - динамика: MoM и YoY по месяцам (в % и в абсолютных значениях)
-- Вопрос продакта: растём или нет? Какие месяцы выбиваются?
-- Решение: YoY через LAG(…, 12) корректен, потому что в v_delivered_monthly нет пропущенных месяцев
--   (календарь без пропусков). Ряд обрезан по 2017-01…2018-08.
-- Находки: ноябрь 2017 - пик (Чёрная пятница, см. 01_5); в 2018 рост от месяца к месяцу
--   почти остановился - заказы держатся на уровне ~6–7 тыс. в месяц.
-- Зависит от: 01_0_views.sql
-- =====================================================================

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
WHERE MONTH >= '2017-01-01' AND MONTH <= '2018-08-01' -- Берем этот период, т.к. 2016 - единичные заказы, после 08.2018 нет доставленных заказов (данные заканчиваются 17.10.2018)
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
)

SELECT * FROM mom_yoy_prcnt ORDER BY MONTH;
-- В абсолютных значениях (янв-авг 2018):
-- SELECT * FROM mom_yoy_dif ORDER BY MONTH;
