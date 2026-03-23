from datetime import datetime

from airflow import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

with DAG(
    dag_id="build_data_marts_dag",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
) as dag:

    create_mart_tables = SQLExecuteQueryOperator(
        task_id="create_mart_tables",
        conn_id="postgres_default",
        sql="sql/mart_ddl.sql",
    )

    build_mart_orders = SQLExecuteQueryOperator(
        task_id="build_mart_orders",
        conn_id="postgres_default",
        sql="sql/mart_orders.sql",
    )

    build_mart_items = SQLExecuteQueryOperator(
        task_id="build_mart_items",
        conn_id="postgres_default",
        sql="sql/mart_items.sql",
    )

    create_mart_tables >> build_mart_orders >> build_mart_items
