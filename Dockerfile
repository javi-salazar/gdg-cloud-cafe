# Imagen base: Python 3.12 "slim" (Debian pequeño, sin extras)
FROM python:3.12-slim

# Logs de Python al instante (sin buffer) y sin archivos .pyc
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

# Todo vive en /app dentro del contenedor
WORKDIR /app

# Primero solo las dependencias: Docker reusa esta capa si no cambian
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Después el código (cambia seguido, por eso va al final)
COPY app/ .

# Usuario sin privilegios: la app no necesita ser root
RUN useradd cafe
USER cafe

# Puerto por defecto; Cloud Run lo reemplaza con su propia variable $PORT
ENV PORT=8080
EXPOSE 8080

# Arranca uvicorn en $PORT. "exec" = uvicorn recibe la señal de apagado;
# --no-access-log porque la app ya registra cada request con su latencia.
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port $PORT --no-access-log"]
