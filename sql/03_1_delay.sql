-- =====================================================================
-- Задача 3. «Логистика просит бюджет» · Подзадача 3.1 - задержка доставки
-- Письмо продакта: логистика говорит, что задержки доставки портят отзывы, и просит деньги
--   на ускорение. Правда ли это? Где задержек больше всего? Где больше всего выручки?
--   Нужен вывод «да / нет / частично» с цифрами + где ускорять в первую очередь.
-- Вопрос подзадачи: как определить задержку, какая доля заказов опаздывает и насколько.
-- Что делает файл: VIEW v_delivered_with_delay - одна строка = один доставленный заказ:
--   покупатель, штат, даты, задержка в днях, оценка в отзыве. На нём построены 3.2 и 3.3.
-- Решения:
--   - задержка = дата фактической доставки позже обещанной покупателю (по дням):
--     покупатель ориентируется на обещанную дату;
--   - период 2017-01…2018-08, только delivered (как в задачах 1–2);
--   - исключено 8 заказов без даты доставки;
--   - несколько отзывов на заказ → средняя оценка (пограничный случай: отзывы 1 и 4 дают 2,5,
--     такой заказ не считается плохим; таких заказов единицы).
-- Результат: с задержкой приехали 6 531 из 96 203 заказов (6,79%); 91,9% приезжают раньше
--   обещанной даты. Опоздания: 1–3 дня - 1,9%, 4–7 - 1,9%, 8–14 - 1,5%, 15+ - 1,4% заказов.
-- =====================================================================

-- order_purchase_timestamp - когда сделан заказ


-- order_delivered_carrier_date - дата, когда заказ передан в логистику
-- order_delivered_customer_date - фактическая дата доставки клиенту
-- order_estimated_delivery_date - предполагаемая дата доставки, которую сообщили клиенту

-- Задержка - если день фактической даты доставки > день предполагаемой дата доставки. 
-- Т.к. пользователь ориентируется на рассчитанную ранее дату, то при доставке позже этой даты он будет считать, что заказ задерживается
-- Исключено 8 заказов без order_delivered_customer_date (проверка - последний запрос файла)


DROP VIEW IF EXISTS v_delivered_with_delay;

CREATE OR REPLACE VIEW v_delivered_with_delay AS
WITH orders_delivery AS (
	SELECT
		o.order_id, c.customer_unique_id, c.customer_state,
		o.order_delivered_customer_date, -- фактическая дата доставки клиенту
		o.order_estimated_delivery_date, -- предполагаемая дата доставки, которую сообщили клиенту
		o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS delay
	FROM orders o
	LEFT JOIN customers c ON c.customer_id = o.customer_id 
	WHERE o.order_purchase_timestamp >= '2017-01-01' AND o.order_purchase_timestamp < '2018-09-01' 
		AND o.order_status = 'delivered'
		AND order_delivered_customer_date IS NOT NULL AND order_estimated_delivery_date IS NOT NULL
),
-- Добавление отзывов в таблицу с заказами
reviews_group AS (
	-- Для заказов с несколькими отзывами берется среднее оценки. Есть заказы с отзывами 1, 4 или 2,5. Такие заказы в "негативные отзывы" не попадут
	SELECT 
		order_id,  AVG(review_score) AS review_score
	FROM reviews
	GROUP BY order_id 
),
with_reviews AS (
	SELECT 
		d.order_id, d.customer_unique_id, d.customer_state, r.review_score , 
		d.order_delivered_customer_date, d.order_estimated_delivery_date, d.delay
	FROM orders_delivery d
	LEFT JOIN reviews_group r ON d.order_id = r.order_id 
)
SELECT * FROM with_reviews;


-- Какая доля доставленных заказов пришла с задержкой
SELECT 
	COUNT(*) AS delivered_orders,
	COUNT(*) FILTER(WHERE delay > 0) AS delivered_with_delay,
	ROUND(COUNT(*) FILTER(WHERE delay > 0)/ COUNT(*)  :: NUMERIC * 100, 2) AS delivered_with_delay_prcnt
FROM v_delivered_with_delay;

-- Насколько опаздывают заказы - распределение по интервалам
SELECT 
	CASE 
		WHEN delay < 0 THEN '1. Приехал заранее'
		WHEN delay = 0 THEN '2. Приехал точно в срок'
		WHEN delay BETWEEN 1 AND 3 THEN '3. Задержка 1-3 дня' 
		WHEN delay BETWEEN 4 AND 7 THEN '4. Задержка 4-7 дней'
		WHEN delay BETWEEN 8 AND 14 THEN '5. Задержка 8-14 дней'
		WHEN delay > 14 THEN '6. Задержка 15+ дней' 
	END AS delay_status,
	COUNT(*) AS cnt,
	ROUND(COUNT(*) / SUM(COUNT(*)) OVER() :: NUMERIC * 100, 2) AS prcnt
FROM v_delivered_with_delay
GROUP BY delay_status
ORDER BY delay_status;

-- Заказы, у которых есть NULL в  order_estimated_delivery_date или в order_delivered_customer_date
SELECT * FROM orders o
WHERE order_purchase_timestamp >= '2017-01-01' AND order_purchase_timestamp < '2018-09-01'
	AND order_status = 'delivered' 
	AND (order_estimated_delivery_date IS NULL OR order_delivered_customer_date IS NULL);
