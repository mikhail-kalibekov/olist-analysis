-- =====================================================================
-- Задача 3 · Подзадача 3.3 - промежуточные варианты выбора штатов (история решения)
-- Итоговый вариант - в 03_3_regions.sql (вариант 3, «лишние» опоздания).
--
-- Вариант 1 - сумма рангов (ранг по GMV + ранг по доле опозданий).
--   Кандидаты: RJ, BA, CE. Проблема: ранг показывает «выше / ниже», но не «насколько» -
--   теряется масштаб. SP по доле опозданий на 11-м месте, хотя опоздавших заказов в нём больше всех;
--   CE попал в тройку, хотя опозданий там в 10 раз меньше, чем в SP.
--
-- Вариант 2 - сортировка по числу опоздавших заказов (и их доле во всех опозданиях).
--   Кандидаты: SP, RJ, MG, BA, RS. Проблема: почти повторяет размер штата. SP и MG в топе,
--   потому что большие, а опаздывают реже средней (4,5% и 4,6% при 6,79% по стране) -
--   ускорять там, где логистика и так работает лучше среднего.
--
-- Вариант 3 - «лишние» опоздания сверх среднего по стране: соединяет частоту и масштаб.
-- =====================================================================

-- Решение 1 - через ранги. Проблема - не учитывается масштаб штатов
-- Для решения штаты пронумерованы по выручке (от большей к меньшей) и по проценту задержке (от большего к меньшему)
-- Сумма этих значений - показывает, где находится штат в суммарном топе. Чем меньше это значение, тем более проблемный штат
-- Штаты с заказами < 300 не рассматриваются
WITH state_delay AS (
	SELECT
		customer_state, ROUND(AVG(review_score),1) AS review_score,
		COUNT(*) AS order_cnt,
		COUNT(*) FILTER(WHERE delay > 0) AS orders_with_delay,
		ROUND(COUNT(*) FILTER(WHERE delay > 0) /COUNT(*)::NUMERIC * 100, 2) AS delay_prcnt, -- доля опоздавших заказов
		ROUND(AVG(delay) FILTER(WHERE delay > 0), 1) AS avg_delay -- средняя задержка опоздавших по штатам
	FROM v_delivered_with_delay
	GROUP BY customer_state
),
GMV_state AS (
	SELECT
		v.customer_state,
		ROUND(SUM(p.payment_value)::numeric, 2) AS GMV_state,
		COUNT(DISTINCT v.order_id) AS order_cnt
	FROM v_delivered_with_delay v
	JOIN payments p ON v.order_id = p.order_id
	GROUP BY v.customer_state
	HAVING COUNT(DISTINCT v.order_id) >= 300
),
rn_states AS (
	SELECT
		g.customer_state, g.GMV_state, g.order_cnt, s.orders_with_delay, s.delay_prcnt, s.avg_delay, s.review_score,
		ROW_NUMBER() OVER(ORDER BY GMV_state DESC) AS rn_gmv,
		ROW_NUMBER() OVER(ORDER BY delay_prcnt DESC) AS rn_delay
	FROM GMV_state g
	LEFT JOIN state_delay s
	ON g.customer_state = s.customer_state
),
top_states_with_delay AS (
	SELECT
		customer_state, order_cnt, GMV_state, orders_with_delay, delay_prcnt, avg_delay, review_score,
		rn_gmv + rn_delay AS delay_score
	FROM rn_states
)
SELECT * FROM top_states_with_delay ORDER BY delay_score, gmv_state DESC, delay_prcnt DESC;


-- Решение 2 - через долю заказов с задержками от всех опозданий.
-- Проблема - повторяет размер штата = будем улучшать в штатах, где и так может работать хорошо
-- Штаты с заказами < 300 не рассматриваются
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
		ROUND(s.orders_with_delay / SUM(s.orders_with_delay) OVER()::NUMERIC * 100, 2) AS delay_prcnt_of_all
	FROM GMV_state g
	LEFT JOIN state_delay s
	ON g.customer_state = s.customer_state
)
SELECT * FROM state_order ORDER BY orders_with_delay DESC;
