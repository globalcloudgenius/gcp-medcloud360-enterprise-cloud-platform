"""BigQuery helper: every query job that runs in the PHI project encrypts its results with
the company key, so the CMEK organization policy on the prod folder is always satisfied."""
from google.cloud import bigquery

from . import config


def query(client: bigquery.Client, sql: str, params: list | None = None):
    job_config = bigquery.QueryJobConfig(query_parameters=params or [])
    if config.BQ_KMS_KEY and client.project == config.PROJECT_DATA:
        job_config.destination_encryption_configuration = bigquery.EncryptionConfiguration(kms_key_name=config.BQ_KMS_KEY)
    return list(client.query(sql, job_config=job_config).result())
