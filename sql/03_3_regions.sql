-- =====================================================================
-- Задача 3 · Подзадача 3.3 - регионы: где задержки и где деньги
-- Вопрос продакта: в каких штатах задержек больше всего, где больше всего денег и где ускорение
--   даст больше пользы.
-- Решения:
--   - штаты с < 300 заказами не рассматриваются: доли и средние там случайны (RR - 40 заказов);
--   - метрика выбора - «лишние» опоздания: опоздания сверх того, что было бы при средней по стране
--     доле опозданий (6,79%) = заказы штата × (доля опозданий штата − 6,79%);
--   - ход решения (ранги → число опозданий → «лишние» опоздания) - в 03_3_regions_variants.sql.
-- Результат («лишние» опоздания): RJ 659, BA 175, CE 90, ES 79, MA 77 … SP −925, MG −249.
-- Вывод: кандидаты для улучшения доставки - RJ, BA, CE, ES, MA.
--   RJ - приоритет №1: из ~1 390 «лишних» опозданий по всем штатам на RJ приходится 659 - почти половина.
--   В SP опозданий больше всех (1 817) просто из-за масштаба, а доля опозданий там 4,5% - ниже средней
--   по стране: логистика там работает лучше среднего.
-- Зависит от: 03_1_delay.sql (VIEW)
-- =====================================================================

-- Штаты с заказами < 300 не рассматриваются
-- В качестве метрики, по которой сортируются штаты, выбрано количество "лишних" заказов с задержкой
-- лишние опоздания = заказы штата × (доля опозданий штата − 6,79%), где 6,79% - средний процент заказов с задержкой по стране
WITH state_delay AS (
	SELECT
		customer_state, ROUND(AVG(review_score),1) AS review_score,
		COUNT(*) AS order_cnt,
		COUNT(*) FILTER(WHERE delay>0) AS orders_with_delay,
		ROUND(COUNT(*) FILTER(WHERE delay > 0) /COUNT(*)::NUMERIC * 100, 2) AS delay_prcnt, -- доля опоздавших заказов
		ROUND(AVG(delay) FILTER(WHERE delay > 0), 1) AS avg_delay -- средняя задержка опоздавших по штатам
	FROM v_delivered_with_delay
	GROUP BY customer_state 
),
GMV_state AS (
	SELECT
		v.customer_state,
		ROUND(SUM(p.payment_value)::numeric, 2) AS GMV_state,
		ROUND(SUM(p.payment_value) FILTER(WHERE delay > 0)::numeric, 2) AS money_with_delay,
		COUNT(DISTINCT v.order_id) AS order_cnt
	FROM v_delivered_with_delay v
	JOIN payments p ON v.order_id = p.order_id 
	GROUP BY v.customer_state
	HAVING COUNT(DISTINCT v.order_id) >= 300
),
state_order AS (
	SELECT 
		g.customer_state, g.GMV_state, g.order_cnt, s.orders_with_delay, s.delay_prcnt, s.avg_delay, s.review_score, g.money_with_delay,
		ROUND(s.orders_with_delay / SUM(s.orders_with_delay) OVER()::NUMERIC * 100, 2) AS delay_prcnt_of_all,
		ROUND(g.order_cnt * (s.delay_prcnt - 6.79) / 100) AS extra_delays
	FROM GMV_state g
	LEFT JOIN state_delay s
	ON g.customer_state = s.customer_state
)


-- В каких штатах задержек больше всего? Доля опоздавших заказов и средняя задержка опоздавших по штатам.
-- SELECT * FROM state_delay ORDER BY delay_prcnt DESC

-- Где больше всего денег? GMV и число заказов по штатам.
-- SELECT * FROM GMV_state ORDER BY GMV_state DESC

-- Где ускорение даст больше пользы? Какие штаты одновременно приносят много денег и часто опаздывают?
SELECT * FROM state_order ORDER BY extra_delays DESC



