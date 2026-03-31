create table if not exists raw_orders (
    order_id bigint,
    user_id bigint,
    user_phone text,
    address_text text,
    created_at timestamp,
    paid_at timestamp,
    delivery_started_at timestamp,
    delivered_at timestamp,
    canceled_at timestamp,
    payment_type text,
    item_id bigint,
    item_title text,
    item_category text,
    item_quantity numeric(10,2),
    item_price numeric(10,2),
    item_canceled_quantity numeric(10,2),
    item_replaced_id bigint,
    order_discount numeric(5,2),
    item_discount numeric(5,2),
    order_cancellation_reason text,
    driver_id bigint,
    driver_phone text,
    delivery_cost numeric(10,2),
    store_id bigint,
    store_address text
);

create table if not exists users (
    user_id bigint primary key,
    user_phone text
);

create table if not exists stores (
    store_id bigint primary key,
    store_address text
);

create table if not exists drivers (
    driver_id bigint primary key,
    driver_phone text
);

create table if not exists products (
    item_id bigint primary key,
    item_title text,
    item_category text
);

create table if not exists order_drivers (
    order_id bigint not null,
    driver_id bigint not null references drivers(driver_id),
    driver_delivery_cost numeric(10,2),
    driver_delivered_at timestamp,
    driver_canceled_at timestamp,
    is_final_driver boolean,
    primary key (order_id, driver_id)
);

create table if not exists orders (
    order_id bigint primary key,
    user_id bigint not null references users(user_id),
    store_id bigint not null references stores(store_id),
    address_text text,
    created_at timestamp,
    paid_at timestamp,
    delivery_started_at timestamp,
    delivered_at timestamp,
    canceled_at timestamp,
    payment_type text,
    order_discount numeric(5,2),
    order_cancellation_reason text,
    delivery_cost_final numeric(10,2)
);

create table if not exists order_items (
    order_item_sk bigserial primary key,
    order_id bigint not null references orders(order_id),
    item_id bigint not null references products(item_id),
    item_quantity numeric(10,2),
    item_price numeric(10,2),
    item_canceled_quantity numeric(10,2),
    item_discount numeric(5,2),
    item_replaced_id bigint
);
