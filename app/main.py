"""Cloud Café ☕ — la app del workshop "Ship it, Break it, Fix it".

Endpoints:
  GET  /           la página (UI)
  GET  /api/menu   el menú en JSON
  POST /api/order  ordenar un café, por ejemplo {"item": "latte"}
  GET  /health     ¿la app está viva?
"""

import json
import logging
import os
import random
import sys
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# Nombre del release: se ve en el badge y en el header X-Release.
# Se puede cambiar con la variable de entorno RELEASE_NAME.
RELEASE_NAME = os.environ.get("RELEASE_NAME", "v2.1-promos-fixed")

# Carpeta con el HTML, CSS y JS de la página.
STATIC_DIR = Path(__file__).parent / "static"


# --- Logs ------------------------------------------------------------------
# Cada log sale como UNA línea JSON en stdout. Así Cloud Logging entiende la
# severidad (INFO, ERROR...) y cada traceback queda en una sola entrada.
class FormatoJSON(logging.Formatter):
    def format(self, record):
        mensaje = record.getMessage()
        if record.exc_info:
            mensaje += "\n" + self.formatException(record.exc_info)
        log = {"severity": record.levelname, "message": mensaje,
               "release": RELEASE_NAME}
        return json.dumps(log, ensure_ascii=False)


salida = logging.StreamHandler(sys.stdout)
salida.setFormatter(FormatoJSON())
logger = logging.getLogger("cloud-cafe")
logger.addHandler(salida)
logger.setLevel(logging.INFO)


# --- El menú ---------------------------------------------------------------
# Precios en pesos (MXN). eta_min = minutos para que el café esté listo.
MENU = [
    {"id": "espresso", "name": "Espresso", "price": 40, "eta_min": 2},
    {"id": "americano", "name": "Americano", "price": 45, "eta_min": 3},
    {"id": "latte", "name": "Latte", "price": 60, "eta_min": 4},
    {"id": "cafe_de_olla", "name": "Café de olla", "price": 50, "eta_min": 5},
    {"id": "cold_brew", "name": "Cold brew", "price": 65, "eta_min": 2},
]


def buscar_cafe(item_id):
    """Regresa el café del menú con ese id (o None si no lo tenemos)."""
    for cafe in MENU:
        if cafe["id"] == item_id:
            return cafe
    return None


# NUEVO en v2: promociones del día (% de descuento por café).
PROMOS = {"latte": 10, "cold_brew": 15}


def obtener_promo(item_id):
    """v2.1: la promo sale de la tabla PROMOS, sin esperar al motor."""
    return PROMOS.get(item_id, 0)


def preparar_orden(cafe):
    """Arma la orden: un número de orden y en cuántos minutos sale."""
    return {
        "status": "ok",
        "order_id": random.randint(1000, 9999),
        "eta_min": cafe["eta_min"],
        "promo_pct": obtener_promo(cafe["id"]),  # NUEVO en v2
    }


# --- La app ----------------------------------------------------------------
app = FastAPI(title="Cloud Café")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


# Middleware: corre en CADA request. Mide la latencia, agrega el header
# X-Release y escribe una línea de log. (FastAPI pide "async" aquí;
# el resto de la app es código normal, síncrono.)
@app.middleware("http")
async def registrar_request(request: Request, call_next):
    inicio = time.perf_counter()
    response = await call_next(request)
    segundos = time.perf_counter() - inicio
    response.headers["X-Release"] = RELEASE_NAME
    logger.info("%s %s -> %s (%.2f s)", request.method, request.url.path,
                response.status_code, segundos)
    return response


@app.get("/")
def pagina():
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/menu")
def ver_menu():
    return MENU


class Pedido(BaseModel):
    item: str  # el id del café, por ejemplo "latte"


@app.post("/api/order")
def ordenar(pedido: Pedido):
    cafe = buscar_cafe(pedido.item)
    if cafe is None:
        raise HTTPException(status_code=404,
                            detail=f"No tenemos '{pedido.item}' en el menú")
    try:
        orden = preparar_orden(cafe)
    except Exception as error:
        # Si algo truena: el traceback va a los logs y el cliente
        # recibe un 500 con un mensaje claro.
        logger.exception("La orden de %s falló: %s", cafe["id"], error)
        return JSONResponse(status_code=500,
                            content={"status": "error", "detail": str(error)})
    logger.info("Orden #%s: %s, lista en %s min",
                orden["order_id"], cafe["name"], orden["eta_min"])
    return orden


# /health y no /healthz: Cloud Run reserva algunas rutas que terminan en "z".
@app.get("/health")
def health():
    return {"status": "ok", "release": RELEASE_NAME}


logger.info("☕ Cloud Café arrancó (release %s)", RELEASE_NAME)
