# CareNotes — one image, five entrypoints (portal | processor | scc-router | job-hl7-sim | job-daily-report)
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8080

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY carenotes ./carenotes

# Never run as root
RUN useradd --uid 10001 --create-home carenotes
USER 10001

EXPOSE 8080
ENTRYPOINT ["python", "-m", "carenotes"]
CMD ["portal"]
