-- 1. Загрузка: 8 таблиц через импорт DBeaver, reviews через psql (\copy) — т.к. при импорте возникла ошибка, в которой склеивались отзывы
-- 2. CREATE TABLE reviews (...)
-- 3. ALTER TABLE ... (исправление типов дат)
-- 4. Проверка числа строк через select count(*) from название_таблицы


select 'category_translation' as table_name, count(*) as row_count from category_translation ct
union all
select 'customers' as table_name, count(*) as row_count from customers c
union all
select 'geolocation' as table_name, count(*) as row_count from geolocation g
union all
select 'order_items' as table_name, count(*) as row_count from order_items oi
union all
select 'orders' as table_name, count(*) as row_count from orders o
union all
select 'payments' as table_name, count(*) as row_count from payments p
union all
select 'products' as table_name, count(*) as row_count from products pr
union all
select 'reviews' as table_name, count(*) as row_count from reviews r
union all
select 'sellers' as table_name, count(*) as row_count from sellers s