FROM apache/airflow:2.9.3-python3.9

USER root

# Установка системных зависимостей
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    curl \
    build-essential \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Копирование и установка зависимостей
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# Создание необходимых директорий
RUN mkdir -p /opt/airflow/dags /opt/airflow/plugins /opt/airflow/logs /opt/airflow/config

LABEL project="project_seminar_sm"
LABEL description="Seminar project with Airflow, PostgreSQL and PgAdmin"