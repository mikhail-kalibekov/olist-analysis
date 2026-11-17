-- order_purchase_timestamp - когда сделан заказ


-- order_delivered_carrier_date - дата, когда заказ передан в логистику
-- order_delivered_customer_date - фактическая дата доставки клиенту
-- order_estimated_delivery_date - предполагаемая дата доставки, которую сообщили клиенту

-- Задержка - если день фактической даты доставки > день предполагаемой дата доставки. 
-- Т.к. пользователь ориентируется на рассчитанную ранее дату, то при доставке позже этой даты он будет считать, что заказ задерживается
-- Исключено 8 заказов без order_delivered_customer_date


DROP VIEW IF EXISTS v_delivered_with_delay;

CREATE OR REPLACE VIEW v_delivered_with_delay AS
SELECT
	o.order_id, c.customer_unique_id, c.customer_state,
	o.order_delivered_customer_date, -- фактическая дата доставки клиенту
	o.order_estimated_delivery_date, -- предполагаемая дата доставки, которую сообщили клиенту
	o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS delay
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id 
WHERE o.order_purchase_timestamp >= '2017-01-01' AND o.order_purchase_timestamp < '2018-09-01' 
	AND o.order_status = 'delivered'
	AND order_delivered_customer_date IS NOT NULL AND order_estimated_delivery_date IS NOT NULL;

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
	AND (order_estimated_delivery_date IS NULL OR order_delivered_customer_date IS NULL)



