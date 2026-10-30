-- Задача 1. Подзадача 1.1 - таблица по месяцам: заказы, GMV, средний чек (доставленные)
-- Зависит от: 01_0_views.sql

SELECT *
FROM v_delivered_monthly
ORDER BY MONTH;
