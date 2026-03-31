import os
import gc
from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq
from sqlalchemy import create_engine, text

DATA_DIR = Path(os.getenv("DATA_DIR", "/opt/airflow/data"))
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "100000"))

engine = create_engine(
    f"postgresql+psycopg2://"
    f"{os.getenv('DB_USER', 'airflow')}:"
    f"{os.getenv('DB_PASSWORD', 'airflow')}@"
    f"{os.getenv('DB_HOST', 'postgres')}:"
    f"{os.getenv('DB_PORT', '5432')}/"
    f"{os.getenv('DB_NAME', 'airflow')}"
)

datetime_cols = [
    "created_at", "paid_at", "delivery_started_at", "delivered_at", "canceled_at"
]

numeric_cols = [
    "order_id", "user_id", "item_id", "driver_id", "store_id",
    "item_quantity", "item_canceled_quantity", "item_price",
    "order_discount", "item_discount", "delivery_cost", "item_replaced_id"
]


def transform_batch(df: pd.DataFrame) -> pd.DataFrame:
    for col in datetime_cols:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    if "item_replaced_id" in df.columns:
        df["item_replaced_id"] = df["item_replaced_id"].astype("Int64")

    return df


def load_file_in_batches(file_path: Path):
    parquet_file = pq.ParquetFile(file_path)
    total_rows = parquet_file.metadata.num_rows
    print(f"\nОбрабатывается файл: {file_path.name}")
    print(f"Всего строк в файле: {total_rows}")

    loaded_rows = 0

    for batch_num, record_batch in enumerate(parquet_file.iter_batches(batch_size=BATCH_SIZE), start=1):
        df = record_batch.to_pandas()
        df = transform_batch(df)

        df.to_sql(
            "raw_orders",
            engine,
            if_exists="append",
            index=False,
            method="multi",
            chunksize=1000
        )

        loaded_rows += len(df)
        print(
            f"  Пакет {batch_num}: загружено {len(df)} строк, "
            f"всего загружено из файла: {loaded_rows}"
        )

        del df
        gc.collect()


def load_raw_orders():
    files = sorted(DATA_DIR.glob("*.parquet"))
    if not files:
        raise FileNotFoundError(f"В папке {DATA_DIR} не найдено parquet-файлов")

    print("Найдены parquet-файлы:")
    for file in files:
        print(f" - {file.name}")

    with engine.begin() as conn:
        conn.execute(text("TRUNCATE TABLE raw_orders;"))

    print("\nТаблица raw_orders очищена. Начинается загрузка данных...")

    for file in files:
        load_file_in_batches(file)

    print("\nЗагрузка всех parquet-файлов в raw_orders завершена успешно")


if __name__ == "__main__":
    load_raw_orders()