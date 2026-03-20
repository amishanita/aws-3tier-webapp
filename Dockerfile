FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app /app

EXPOSE 5000

# Run gunicorn; worker count can be overridden via env.
CMD ["sh", "-c", "gunicorn -w ${GUNICORN_WORKERS:-2} -k gthread --threads ${GUNICORN_THREADS:-2} -b 0.0.0.0:5000 wsgi:app"]

