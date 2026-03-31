truncate table mart_items;

insert into mart_items (
    order_date, year, month, day, city, store_id, store_address,
    item_category, item_id, item_title,
    turnover, items_ordered, items_canceled,
    orders_with_item, orders_with_cancel
)
select
    o.created_at::date                                      as order_date,
    extract(year  from o.created_at::date)::int             as year,
    extract(month from o.created_at::date)::int             as month,
    extract(day   from o.created_at::date)::int             as day,
    trim(split_part(s.store_address, ',', 1))                as city,
    o.store_id,
    s.store_address,
    p.item_category,
    oi.item_id,
    p.item_title,
    sum(oi.item_price * oi.item_quantity
        - coalesce(oi.item_discount, 0))                    as turnover,
    sum(oi.item_quantity)                                    as items_ordered,
    sum(oi.item_canceled_quantity)                           as items_canceled,
    count(distinct oi.order_id)                              as orders_with_item,
    count(distinct oi.order_id)
        filter (where oi.item_canceled_quantity > 0)         as orders_with_cancel
from order_items oi
join orders   o on oi.order_id = o.order_id
join stores   s on o.store_id  = s.store_id
join products p on oi.item_id  = p.item_id
group by
    o.created_at::date,
    o.store_id,
    s.store_address,
    p.item_category,
    oi.item_id,
    p.item_title;
