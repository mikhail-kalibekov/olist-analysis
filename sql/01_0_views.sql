-- Задача 1. Подзадача 1.0 - базовые представления (VIEW)
-- Выполнить ОДИН раз (и заново после правок в этом файле). Остальные файлы задачи 1 читают из этих VIEW.
-- v_delivered_daily   - доставленные заказы по дням, без пропусков дат (заказы, GMV)
-- v_delivered_monthly - то же по месяцам + средний чек
--
-- Задача 1. «Как у нас дела в целом?»: GMV, число заказов и средний чек по месяцам
--
-- Определения:
-- 1. Выручка = GMV (оборот): всё, что заплатил покупатель, включая доставку.
--    Источник: payments.payment_value. Это фактически уплаченная сумма, в том числе
--    проценты по рассрочке, поэтому иногда она больше, чем price + freight_value
--    в order_items. Расхождение по delivered: 0,017%.
--    Комиссию маркетплейса не считаем: данных о ней в базе нет.
-- 2. В payments может быть несколько строк на заказ: оплата разными способами
--    (payment_sequential), например картой и ваучерами. Поэтому за основу берется таблицы payments 
--    с уникальными строками, а потом соединяется с таблицей orders, иначе строки размножатся.
-- TODO (ревью): формулировка неверна: строки в payments НЕ уникальны. Объясни, почему твой подход
--    всё равно не задваивает (orders - одна строка на заказ, count(DISTINCT), сумма по строкам платежей).
-- 3. Ваучеры считаю оплатой наравне с другими способами.
--    Платежи not_defined (3 шт.) все относятся к отменённым заказам и на GMV не влияют.
-- 4. Заказы: только status = 'delivered' (≈96% всех заказов). Остальные статусы
--    (shipped, invoiced, processing и др.) — смесь старых застрявших заказов с 2016
--    года и свежих «в пути»; это не заработанные деньги.
--    canceled и unavailable — не выручка, показываю отдельно.
-- 5. Месяц заказа = order_purchase_timestamp: момент, когда клиент решил купить,
--    без NULL. order_approved_at не подходит: в нём есть пропуски.
-- 6. Средний чек = GMV доставленных заказов / число доставленных заказов
--    (один и тот же набор заказов в числителе и знаменателе).
-- 7. Первая дата в данных - 2016-09-04, последняя дата в данных - 2018-10-17
-- 8. Сравниваю Январь-Август 2017-2018 годов, т.к. данные по заказам заканчиваются в августе. 
-- 	  Доставленных заказов в сентябре-октябре 2018 нет
-- 9. В черную пятницу - 2017-11-24 - наблюдался рост количества заказов в 6,7 раз

-- TODO (ревью): ORDER BY внутри CTE/VIEW не гарантирует порядок итога - сортируй в финальном SELECT

CREATE OR REPLACE VIEW v_delivered_daily AS
WITH 
calendar_day AS (
SELECT
	generate_series(
	'2016-09-01':: date, -- первая дата в данных - 2016-09-04
	'2018-10-31'::date, -- последняя дата в данных - 2018-10-17
	'1 day'::INTERVAL
	)::date AS DAY
),
overview_1 AS (
-- Сумма заказов delivered по дня - с пропусками 
-- В таблице orders нет повторяющихся order_id (все уникальные), 
-- В payments - есть повторяющиеся order_id
-- left join к таблице payments
-- TODO (ревью): из-за WHERE по o.order_status это фактически INNER JOIN - поправь комментарий
SELECT
		date_trunc('day', o.order_purchase_timestamp) AS purchase_date,
		count(DISTINCT o.order_id) AS orders_count,
		sum(p.payment_value) AS day_gmv
FROM
	payments p
LEFT JOIN orders o ON
	p.order_id = o.order_id
WHERE
	o.order_status = 'delivered'
GROUP BY
	purchase_date
ORDER BY
	purchase_date
),
overview_2 AS (
-- Сумма заказов delivered по дням - без пропусков 
-- В календаре есть все даты, если значения для какой-то даты нет, то ставится 0
SELECT
		cd.day,
		COALESCE(ov1.orders_count, 0) AS orders_count,
		COALESCE(ov1.day_gmv, 0) AS day_gmv
FROM calendar_day cd
LEFT JOIN overview_1 ov1 ON
	ov1.purchase_date = cd.day
ORDER BY
	cd.day
)
SELECT * FROM overview_2;


CREATE OR REPLACE VIEW v_delivered_monthly AS
WITH
overview_3 AS (
-- Сумма заказов delivered по месяцам - без пропусков
SELECT
		date_trunc('month', ov2.day) AS MONTH,
		sum(ov2.orders_count) AS orders_count,
		sum(ov2.day_gmv) AS month_gmv
FROM v_delivered_daily ov2
GROUP BY MONTH
ORDER BY MONTH DESC
),
overview AS (
-- 1. Таблица по месяцам: заказы, GMV, средний чек.
SELECT 
		MONTH,
	orders_count, 
		round(month_gmv::NUMERIC, 2) AS month_gmv,
		-- TODO (ревью): в месяце без заказов средний чек не определён - должен быть NULL, а не 0
		round(COALESCE(month_gmv::NUMERIC / NULLIF(orders_count::NUMERIC, 0), 0), 2) AS avg_month_payment
FROM
	overview_3
)
SELECT * FROM overview;
