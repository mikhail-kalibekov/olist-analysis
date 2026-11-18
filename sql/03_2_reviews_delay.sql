-- =====================================================================
-- Задача 3 · Подзадача 3.2 - оценка в отзыве и задержка доставки
-- Вопрос продакта: правда ли, что задержки портят отзывы? Как меняется средняя оценка и доля
--   плохих оценок (1–2) по группам задержки? Какую часть плохих отзывов дают опоздавшие заказы?
-- Решения:
--   - единица анализа - заказ: несколько отзывов на заказ → средняя оценка (в VIEW из 3.1);
--   - доля плохих оценок считается среди заказов с оценкой: знаменатель COUNT(review_score),
--     а не COUNT(*).
-- Результат:
--   группа           | средняя оценка | доля оценок 1–2
--   раньше срока     | 4,30           | 9,2%
--   в срок           | 4,04           | 12,3%
--   опоздание 1–3 дня| 3,29           | 32,2%
--   4–7 дней         | 2,11           | 67,6%
--   8–14 дней        | 1,67           | 80,1%
--   15+ дней         | 1,73           | 78,2%
--   На опоздавшие заказы приходится 3 977 из 12 192 плохих оценок (32,6%).
-- Вывод: оценка падает с ~4 до 2,1 при опоздании на 4–7 дней - плохих оценок в 5–7 раз больше,
--   чем у заказов, приехавших вовремя; при большем опоздании - плато ~1,7.
--   ~7% заказов дают ~1/3 плохих отзывов: задержки портят оценку заказа. При этом 2/3 плохих
--   отзывов - у заказов, приехавших вовремя, значит, есть и другие причины.
-- Зависит от: 03_1_delay.sql (VIEW)
-- =====================================================================

-- Проверка гранулярности reviews
-- В reviews есть заказы, на которые приходится несколько отзывов и оценок. Для таких заказов берем среднее оценок
SELECT 
	d.order_id, COUNT(*) AS cnt
FROM v_delivered_with_delay d
LEFT JOIN reviews r ON d.order_id = r.order_id 
GROUP BY d.order_id
ORDER BY cnt DESC;

-- Примеры таких заказов
SELECT * 
FROM v_delivered_with_delay d
LEFT JOIN reviews r ON d.order_id = r.order_id 
WHERE d.order_id IN ('79675ac76b2c97ba601ce736de298724');
-- '03c939fd7fd3b38f8485a0f95798f1f6', '8e17072ec97ce29f0e1f111e598b0c85', 'c88b1d1b157a9999ce368f218a407141','df56136b8031ecd28e200bb18e6ddb2e' -- примеры заказов с несколькими отзывами


-- Решение (оценка уже на уровне заказа - см. VIEW в 03_1)

-- Как меняется средняя оценка в зависимости от задержки? Какая доля плохих оценок в каждой группе?
SELECT 
	CASE 
		WHEN delay < 0 THEN '1. Приехал заранее'
		WHEN delay = 0 THEN '2. Приехал точно в срок'
		WHEN delay BETWEEN 1 AND 3 THEN '3. Задержка 1-3 дня' 
		WHEN delay BETWEEN 4 AND 7 THEN '4. Задержка 4-7 дней'
		WHEN delay BETWEEN 8 AND 14 THEN '5. Задержка 8-14 дней'
		WHEN delay > 14 THEN '6. Задержка 15+ дней' 
	END AS delay_status,
	ROUND(AVG(review_score), 2) AS avg_review_score,
	ROUND(COUNT(*) FILTER(WHERE review_score <=2) / COUNT(review_score)::NUMERIC * 100, 2) negative_reviews_prcnt,
	COUNT(*) AS order_cnt,
	COUNT(*) FILTER(WHERE review_score <=2) AS negative_reviews_cnt
FROM v_delivered_with_delay
GROUP BY delay_status
ORDER BY delay_status;


-- Сколько всего плохих оценок приходится на опоздавшие заказы?
WITH negative_reviews AS (
SELECT 
	COUNT(*) AS all_negative_reviews,
	COUNT(*) FILTER(WHERE delay > 0) AS delivery_negative_reviews
FROM v_delivered_with_delay 
WHERE review_score <=2
)

SELECT 
	all_negative_reviews, delivery_negative_reviews,
	ROUND(delivery_negative_reviews / all_negative_reviews::NUMERIC * 100, 2) AS delivery_negative_prcnt
FROM negative_reviews