#!/usr/bin/env bash
# loadgen.sh — Genera tráfico contra tu servicio (~2 requests por segundo),
# mezclando GET /api/menu y POST /api/order, para que las métricas y los
# logs muestren lo que pasa (¡incluido el incidente!).
#
# Uso:
#   URL=$(gcloud run services describe cloud-cafe --region=us-central1 --format='value(status.url)')
#   ./scripts/loadgen.sh "$URL"
# Para detenerlo: Ctrl+C (al salir imprime un resumen).
set -euo pipefail

if [[ $# -ne 1 || "$1" != http* ]]; then
  echo "Uso: $0 URL_DEL_SERVICIO   (por ejemplo: https://cloud-cafe-xxxxx-uc.a.run.app)" >&2
  exit 1
fi

URL="${1%/}"            # quitamos la "/" final, si viene
PAUSA=0.5               # medio segundo entre requests = ~2 req/s
CAFES=(espresso americano latte cafe_de_olla cold_brew)
RESULTADOS="$(mktemp)"  # cada resultado se anota aquí para el resumen final

# Hace UN request e imprime una línea: hora, método, ruta, código HTTP y tiempo.
un_request() {
  local metodo="$1" ruta="$2" cuerpo="${3:-}"
  local opciones=(--silent --output /dev/null --max-time 15 --write-out '%{http_code} %{time_total}')
  if [[ "$metodo" == "POST" ]]; then
    opciones+=(--request POST --header "Content-Type: application/json" --data "$cuerpo")
  fi

  local resultado codigo segundos icono
  resultado="$(curl "${opciones[@]}" "$URL$ruta" || true)" # si falla, curl reporta 000
  codigo="${resultado%% *}"
  segundos="${resultado##* }"

  if [[ "$codigo" == 2* && "${segundos%%.*}" -ge 1 ]]; then
    icono="🐢 lento"
  elif [[ "$codigo" == 2* ]]; then
    icono="✅"
  elif [[ "$codigo" == 000 ]]; then
    icono="❌ sin respuesta"
  else
    icono="❌"
  fi
  printf '%s  %-4s %-10s  %s  %5ss  %s\n' "$(date +%H:%M:%S)" "$metodo" "$ruta" \
    "$codigo" "${segundos:0:4}" "$icono" | tee -a "$RESULTADOS"
}

# Al presionar Ctrl+C: cortamos los requests pendientes e imprimimos el resumen.
resumen() {
  local pid total errores lentos
  for pid in $(jobs -p); do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  total="$(wc -l <"$RESULTADOS")"
  errores="$(grep -c '❌' "$RESULTADOS" || true)"
  lentos="$(grep -c '🐢' "$RESULTADOS" || true)"
  echo
  echo "📊 Resumen: $total requests · $errores con error · $lentos lentos (más de 1 s)"
  rm -f "$RESULTADOS"
}
trap 'resumen; exit 0' INT TERM

echo "☕ Mandando ~2 req/s a $URL  (Ctrl+C para parar)"
echo
while true; do
  # El "&" lanza el request en segundo plano: no esperamos la respuesta,
  # así el ritmo se mantiene aunque el servicio esté lento.
  if ((RANDOM % 2 == 0)); then
    un_request GET /api/menu &
  else
    cafe="${CAFES[RANDOM % ${#CAFES[@]}]}"
    un_request POST /api/order "{\"item\": \"$cafe\"}" &
  fi
  sleep "$PAUSA"
done
