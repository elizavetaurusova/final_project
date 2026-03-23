from datetime import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

from scripts.load_raw_orders import load_raw_orders

with DAG(
    dag_id="normalize_orders_dag",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
) as dag:

    init_tables = SQLExecuteQueryOperator(
        task_id="init_tables",
        conn_id="postgres_default",
        sql="sql/ddl.sql",
    )

    load_raw_orders_task = PythonOperator(
        task_id="load_raw_orders",
        python_callable=load_raw_orders,
    )

    truncate_normalized = SQLExecuteQueryOperator(
        task_id="truncate_normalized",
        conn_id="postgres_default",
        sql="/sql/truncate_normalized_tables.sql",
    )

    load_users = SQLExecuteQueryOperator(
        task_id="load_users",
        conn_id="postgres_default",
        sql="""
        insert into users (user_id, user_phone)
        select user_id, max(user_phone)
        from raw_orders
        group by user_id;
        """,
    )

    load_stores = SQLExecuteQueryOperator(
        task_id="load_stores",
        conn_id="postgres_default",
        sql="""
        insert into stores (store_id, store_address)
        select store_id, max(store_address)
        from raw_orders
        group by store_id;
        """,
    )

    load_drivers = SQLExecuteQueryOperator(
        task_id="load_drivers",
        conn_id="postgres_default",
        sql="""
        insert into drivers (driver_id, driver_phone)
        select driver_id, max(driver_phone)
        from raw_orders
        where driver_id is not null
        group by driver_id;
        """,
    )

    load_products = SQLExecuteQueryOperator(
        task_id="load_products",
        conn_id="postgres_default",
        sql="""
        insert into products (item_id, item_title, item_category)
        select item_id, max(item_title), max(item_category)
        from raw_orders
        group by item_id;
        """,
    )

    load_order_drivers = SQLExecuteQueryOperator(
        task_id="load_order_drivers",
        conn_id="postgres_default",
        sql="""
        insert into order_drivers (
            order_id,
            driver_id,
            driver_delivery_cost,
            driver_delivered_at,
            driver_canceled_at,
            is_final_driver
        )
        select
            order_id,
            driver_id,
            max(delivery_cost),
            max(delivered_at),
            max(canceled_at),
            case when max(delivered_at) is not null then true else false end
        from raw_orders
        where driver_id is not null
        group by order_id, driver_id;
        """,
    )

    load_orders = SQLExecuteQueryOperator(
        task_id="load_orders",
        conn_id="postgres_default",
        sql="""
        insert into orders (
            order_id,
            user_id,
            store_id,
            address_text,
            created_at,
            paid_at,
            delivery_started_at,
            delivered_at,
            canceled_at,
            payment_type,
            order_discount,
            order_cancellation_reason,
            delivery_cost_final
        )
        with order_base as (
            select
                order_id,
                max(user_id) as user_id,
                max(store_id) as store_id,
                max(address_text) as address_text,
                max(created_at) as created_at,
                max(paid_at) as paid_at,
                max(delivery_started_at) as delivery_started_at,
                max(delivered_at) as delivered_at,
                max(canceled_at) as canceled_at,
                max(payment_type) as payment_type,
                max(order_discount) as order_discount,
                max(order_cancellation_reason) as order_cancellation_reason
            from raw_orders
            group by order_id
        ),
        final_driver_cost as (
            select
                order_id,
                max(driver_delivery_cost) as delivery_cost_final
            from order_drivers
            where is_final_driver = true
            group by order_id
        )
        select
            b.order_id,
            b.user_id,
            b.store_id,
            b.address_text,
            b.created_at,
            b.paid_at,
            b.delivery_started_at,
            b.delivered_at,
            b.canceled_at,
            b.payment_type,
            b.order_discount,
            b.order_cancellation_reason,
            case
                when b.canceled_at is not null then null
                else f.delivery_cost_final
            end
        from order_base b
        left join final_driver_cost f
            on b.order_id = f.order_id;
        """,
    )

    load_order_items = SQLExecuteQueryOperator(
        task_id="load_order_items",
        conn_id="postgres_default",
        sql="""
        insert into order_items (
            order_id,
            item_id,
            item_quantity,
            item_price,
            item_canceled_quantity,
            item_discount,
            item_replaced_id
        )
        select distinct
            order_id,
            item_id,
            item_quantity,
            item_price,
            item_canceled_quantity,
            item_discount,
            item_replaced_id
        from raw_orders;
        """,
    )

    init_tables >> load_raw_orders_task >> truncate_normalized
    truncate_normalized >> load_users >> load_stores >> load_drivers >> load_products >> load_order_drivers >> load_orders >> load_order_items
