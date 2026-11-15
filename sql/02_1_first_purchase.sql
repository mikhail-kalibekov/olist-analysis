-- =====================================================================
-- Задача 2. «Возвращаются ли покупатели?» · Подзадача 2.1 - покупатели и первая покупка
-- Вопрос продакта: кто для нас «покупатель», сколько их и когда каждый купил впервые.
-- Что делает файл: VIEW v_first_customers - покупатель → дата первой покупки → месяц когорты.
--   На нём построены 2.3 и 2.4.
-- Решение: покупатель = customer_unique_id с хотя бы одним доставленным заказом
--   (покупкой считаю только delivered - как в задаче 1).
-- =====================================================================
-- customer_id - уникальный номер, который присваивается к заказу, у каждого - только 1 заказ. Их количество совпадает с числом заказов - 99 441
-- customer_unique_id - id уникальных пользователей, у каждого может быть несколько заказов. Их всего - 96 096, с заказами в статусе delivered - 93 358
-- Кто для нас покупатель? Уникальный customer_unique_id из таблицы customers, у кого есть хотя бы 1 заказ со статусом delivered

DROP VIEW IF EXISTS v_first_customers;

CREATE OR REPLACE VIEW v_first_customers AS
WITH first_order AS (
	-- Когда каждый купил впервые
	SELECT 
 	c.customer_unique_id,
 	MIN(o.order_purchase_timestamp) AS first_order_date,
 	DATE_TRUNC('MONTH', MIN(o.order_purchase_timestamp)) AS cohort_month
	FROM customers c 
	JOIN orders o ON c.customer_id = o.customer_id 
	WHERE o.order_status = 'delivered'
	GROUP BY c.customer_unique_id 
)
SELECT * FROM first_order;

-- Сколько покупателей за весь период (результат: 93 358)
SELECT COUNT(*) FROM v_first_customers;
