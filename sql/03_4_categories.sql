-- =====================================================================
-- Задача 3 · Подзадача 3.4 - категории: где деньги, как с опозданиями и оценками
-- Вопрос продакта: какие категории приносят больше всего денег (топ-10, доля выручки, заказы)?
--   Как в них с опозданиями и оценками?
-- Решения:
--   - выручка категории = price + freight_value из order_items: в payments сумма на весь заказ,
--     и её нельзя разделить между категориями, если в заказе товары из разных категорий;
--     доставка включена, как в GMV задачи 1;
--   - заказы и опоздавшие заказы - COUNT(DISTINCT order_id): order_items - строка на товар;
--     заказ с товарами из нескольких категорий учитывается в каждой из них;
--   - категория без перевода - исходное название (LEFT JOIN + COALESCE);
--   - ограничение: средняя оценка и средняя задержка посчитаны по строкам товаров
--     (заказ из 3 товаров весит втрое больше); на вывод не влияет - он построен на доле опозданий.
-- Результат: топ-10 категорий дают ≈62% выручки, топ-3 (health_beauty, watches_gifts,
--   bed_bath_table) ≈25%. Доля опозданий в топ-10 - 5,4–7,5% (в среднем 6,75%), оценки 3,9–4,2.
-- Вывод: доля опозданий по категориям - от 5,4% до 7,5%, по штатам (3.3) - от 4,1% до 21,5%.
--   Опоздает заказ или нет, зависит в основном от того, куда его доставляют, а не от того, что в нём.
--   Бюджет логистики нужно направлять на ускорение доставки по регионам, а не по категориям,
--   начиная с RJ.
-- Зависит от: 03_1_delay.sql (VIEW)
-- =====================================================================


WITH order_with_products AS (
	SELECT 
		v.order_id, v.customer_unique_id, v.customer_state, v.review_score , 
		v.order_delivered_customer_date, v.order_estimated_delivery_date, v.delay,
		i.order_item_id, i.product_id, i.price + i.freight_value AS price,
		COALESCE(ct.product_category_name_english, p.product_category_name) AS product_category_name
	FROM v_delivered_with_delay v
	JOIN order_items i
		ON v.order_id = i.order_id
	JOIN products p
		ON i.product_id = p.product_id
	LEFT JOIN category_translation ct 
		ON ct.product_category_name = p.product_category_name 
),
gmv_category_1 AS (
	SELECT 
		product_category_name, 
		ROUND(SUM(price) :: numeric,2) AS GMV_category,
		COUNT(DISTINCT order_id) AS orders_cnt,
		COUNT(DISTINCT order_id) FILTER (WHERE delay > 0) AS orders_with_delay_cnt,
		ROUND(AVG(review_score), 1) AS avg_review_score, -- сейчас считается по товарам, а не по заказам
		ROUND(AVG(delay) FILTER(WHERE delay >0), 1) AS avg_delay_days -- сейчас считается по товарам, а не по заказам
	FROM order_with_products
	GROUP BY product_category_name
),
gmv_category AS (
	SELECT 
		product_category_name, GMV_category, 
		ROUND (GMV_category :: NUMERIC / SUM(GMV_category) OVER() :: NUMERIC * 100, 2) AS GMV_prcnt,
		orders_cnt, orders_with_delay_cnt,
		ROUND(orders_with_delay_cnt / orders_cnt::NUMERIC * 100, 2) AS delay_prcnt,
		ROUND (SUM(orders_with_delay_cnt) OVER() / SUM(orders_cnt) OVER()::NUMERIC * 100, 2) AS avg_delay_prcnt,
		avg_delay_days, avg_review_score
	FROM gmv_category_1
)


-- Какие категории товаров приносят больше всего денег? Топ-10 категорий по выручке, их доля в общей выручке и число заказов.
-- Как в этих категориях с опозданиями и оценками? Доля опоздавших заказов и средняя оценка по категориям из топ-10.
SELECT * FROM gmv_category ORDER BY GMV_category DESC LIMIT 10

