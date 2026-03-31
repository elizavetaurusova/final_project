truncate table mart_orders;

insert into mart_orders (
    order_date, year, month, day, city, store_id, store_address,
    turnover, revenue, profit,
    total_orders, delivered_orders, canceled_orders,
    canceled_after_delivery, canceled_service_errors,
    unique_customers, avg_check, orders_per_customer, revenue_per_customer,
    courier_changes, active_couriers
)
with order_item_agg as (
    select
        oi.order_id,
        sum(oi.item_price * oi.item_quantity)                                    as gross_amount,
        sum(oi.item_price * (oi.item_quantity - oi.item_canceled_quantity))       as net_amount,
        sum(coalesce(oi.item_discount, 0))                                       as total_item_discount
    from order_items oi
    group by oi.order_id
),
order_driver_stats as (
    select
        od.order_id,
        count(distinct od.driver_id) as driver_count
    from order_drivers od
    group by od.order_id
),
active_couriers_agg as (
    select
        o.created_at::date as order_date,
        o.store_id,
        count(distinct od.driver_id) as active_couriers
    from orders o
    join order_drivers od on o.order_id = od.order_id
    group by o.created_at::date, o.store_id
),
order_enriched as (
    select
        o.order_id,
        o.created_at::date                                                       as order_date,
        o.store_id,
        s.store_address,
        trim(split_part(s.store_address, ',', 1))                                as city,
        o.user_id,
        o.delivered_at,
        o.canceled_at,
        o.order_cancellation_reason,
        o.delivery_cost_final,
        -- turnover per order
        coalesce(oia.gross_amount, 0)
            - coalesce(o.order_discount, 0)
            - coalesce(oia.total_item_discount, 0)                               as order_turnover,
        -- revenue: only for paid orders
        case when o.paid_at is not null
            then coalesce(oia.net_amount, 0)
                 - coalesce(o.order_discount, 0)
                 - coalesce(oia.total_item_discount, 0)
            else 0
        end                                                                      as order_revenue,
        coalesce(ods.driver_count, 0)                                            as driver_count
    from orders o
    join stores s on o.store_id = s.store_id
    left join order_item_agg oia on o.order_id = oia.order_id
    left join order_driver_stats ods on o.order_id = ods.order_id
),
mart_base as (
    select
        oe.order_date,
        extract(year  from oe.order_date)::int as year,
        extract(month from oe.order_date)::int as month,
        extract(day   from oe.order_date)::int as day,
        oe.city,
        oe.store_id,
        oe.store_address,

        sum(oe.order_turnover)                                                   as turnover,
        sum(oe.order_revenue)                                                    as revenue,
        sum(oe.order_revenue) - sum(coalesce(oe.delivery_cost_final, 0))         as profit,

        count(*)                                                                 as total_orders,
        count(*) filter (where oe.delivered_at is not null)                      as delivered_orders,
        count(*) filter (where oe.canceled_at  is not null)                      as canceled_orders,
        count(*) filter (where oe.delivered_at is not null
                           and oe.canceled_at  is not null)                      as canceled_after_delivery,
        count(*) filter (where oe.order_cancellation_reason
                           in ('Ошибка приложения', 'Проблемы с оплатой'))       as canceled_service_errors,

        count(distinct oe.user_id)                                               as unique_customers,

        case when count(*) filter (where oe.delivered_at is not null) > 0
            then sum(oe.order_revenue)::numeric
                 / count(*) filter (where oe.delivered_at is not null)
            else 0
        end                                                                      as avg_check,

        case when count(distinct oe.user_id) > 0
            then count(*)::numeric / count(distinct oe.user_id)
            else 0
        end                                                                      as orders_per_customer,

        case when count(distinct oe.user_id) > 0
            then sum(oe.order_revenue)::numeric / count(distinct oe.user_id)
            else 0
        end                                                                      as revenue_per_customer,

        count(*) filter (where oe.driver_count > 1)                              as courier_changes
    from order_enriched oe
    group by oe.order_date, oe.city, oe.store_id, oe.store_address
)
select
    mb.order_date, mb.year, mb.month, mb.day,
    mb.city, mb.store_id, mb.store_address,
    mb.turnover, mb.revenue, mb.profit,
    mb.total_orders, mb.delivered_orders, mb.canceled_orders,
    mb.canceled_after_delivery, mb.canceled_service_errors,
    mb.unique_customers, mb.avg_check, mb.orders_per_customer, mb.revenue_per_customer,
    mb.courier_changes,
    coalesce(aca.active_couriers, 0) as active_couriers
from mart_base mb
left join active_couriers_agg aca
    on mb.order_date = aca.order_date
   and mb.store_id   = aca.store_id;
