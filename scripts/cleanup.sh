#!/usr/bin/env bash
# cleanup.sh — Borra lo que creaste en el workshop y te pregunta antes de cada cosa:
#   1. El servicio "cloud-cafe" de Cloud Run (con todas sus revisiones).
#   2. Los triggers de Cloud Build (si montaste el del anexo en casa).
#   3. Los repositorios de imágenes de Artifact Registry: "cloud-cafe" (lo creó
#      setup.sh) y "cloud-run-source-deploy" (lo creó tu primer deploy).
#   4. Los buckets donde Cloud Build guardó tu código para construirlo.
#
# No toca el proyecto, la facturación, las APIs ni los permisos (nada de eso
# cobra): después de esto puedes volver a empezar desde CP0.
# ¿Quieres borrar TODO, proyecto incluido? gcloud projects delete TU_PROJECT_ID
#
# Uso: ./scripts/cleanup.sh      (Enter = no lo borres · "s" = sí, bórralo)
set -euo pipefail

# Que gcloud no haga sus propias preguntas: aquí preguntamos nosotros.
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

REGION="us-central1"
SERVICIO="cloud-cafe"
REPOS=(cloud-cafe cloud-run-source-deploy)
BORRADOS=0
CONSERVADOS=0
SERVICIO_VIVO=""

# Pregunta si borramos algo. Solo "s", "si", "sí", "y" o "yes" cuentan como sí.
confirmar() {
  local respuesta=""
  read -r -p "      ¿Lo borro? [s/N] " respuesta || true # sin respuesta = no
  case "${respuesta,,}" in
    s | si | sí | y | yes) return 0 ;;
  esac
  echo "      ⏭️  Lo dejo"
  CONSERVADOS=$((CONSERVADOS + 1))
  return 1
}

borrado() {
  echo "      ✅ Borrado"
  BORRADOS=$((BORRADOS + 1))
}

# Cuenta las líneas que imprime un comando (0 si falla, por ejemplo si la API está apagada).
contar() {
  local salida
  salida="$("$@" 2>/dev/null || true)"
  grep -c . <<<"$salida" || true
}

# Los buckets con el código de tus builds: run-sources-PROYECTO-REGIÓN (deploy --source)
# y PROYECTO_cloudbuild (gcloud builds submit).
buckets_de_builds() {
  gcloud storage buckets list --format='value(name)' 2>/dev/null |
    grep -E "^(run-sources-${PROJECT_ID}-.+|${PROJECT_ID}(_.+)?_cloudbuild)$" || true
}

if ! gcloud auth print-access-token >/dev/null 2>&1; then
  echo "❌ gcloud no tiene una sesión activa. Corre: gcloud auth login"
  exit 1
fi
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ No hay proyecto configurado. Corre: gcloud config set project TU_PROJECT_ID"
  exit 1
fi
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
  echo "❌ No puedo abrir el proyecto '$PROJECT_ID'. Revisa el ID con: gcloud projects list"
  exit 1
fi

echo "🧹 Limpieza del proyecto: $PROJECT_ID"
echo "   Te pregunto antes de borrar cada cosa (Enter = no la borres)."

echo
echo "[1/4] Servicio '$SERVICIO' de Cloud Run ($REGION)"
if URL="$(gcloud run services describe "$SERVICIO" --region="$REGION" \
  --format='value(status.url)' 2>/dev/null)"; then
  echo "      Existe: $URL"
  if confirmar; then
    gcloud run services delete "$SERVICIO" --region="$REGION" --quiet
    borrado
  else
    SERVICIO_VIVO="sí"
  fi
else
  echo "      ✅ No existe: nada que borrar"
fi

echo
echo "[2/4] Triggers de Cloud Build"
HAY_TRIGGERS=""
for UBICACION in global "$REGION"; do
  mapfile -t TRIGGERS < <(gcloud builds triggers list --region="$UBICACION" \
    --format='value(name)' 2>/dev/null || true)
  for TRIGGER in "${TRIGGERS[@]}"; do
    [[ -n "$TRIGGER" ]] || continue
    HAY_TRIGGERS="sí"
    echo "      Existe: $TRIGGER ($UBICACION)"
    if confirmar; then
      gcloud builds triggers delete "$TRIGGER" --region="$UBICACION" --quiet
      borrado
    fi
  done
done
[[ -n "$HAY_TRIGGERS" ]] || echo "      ✅ No hay: nada que borrar"

echo
echo "[3/4] Repositorios de imágenes en Artifact Registry ($REGION)"
for REPO in "${REPOS[@]}"; do
  if gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1; then
    echo "      Existe: $REPO"
    if [[ -n "$SERVICIO_VIVO" ]]; then
      echo "      ⚠️  Tu servicio sigue vivo y arranca con estas imágenes: sin ellas ya no podrá arrancar."
    fi
    if confirmar; then
      gcloud artifacts repositories delete "$REPO" --location="$REGION" --quiet
      borrado
    fi
  else
    echo "      ✅ $REPO no existe: nada que borrar"
  fi
done

echo
echo "[4/4] Buckets con el código fuente de tus builds"
mapfile -t BUCKETS < <(buckets_de_builds)
HAY_BUCKETS=""
for BUCKET in "${BUCKETS[@]}"; do
  [[ -n "$BUCKET" ]] || continue
  HAY_BUCKETS="sí"
  echo "      Existe: gs://$BUCKET"
  if confirmar; then
    gcloud storage rm --recursive --all-versions "gs://$BUCKET"
    borrado
  fi
done
[[ -n "$HAY_BUCKETS" ]] || echo "      ✅ No hay: nada que borrar"

# Inventario final: lo que queda, contado de nuevo desde cero.
TRIGGERS_QUEDAN=$(($(contar gcloud builds triggers list --region=global --format='value(name)') +
  $(contar gcloud builds triggers list --region="$REGION" --format='value(name)')))
echo
echo "📋 Lo que queda en $PROJECT_ID:"
echo "   Servicios de Cloud Run:      $(contar gcloud run services list --region="$REGION" --format='value(metadata.name)')"
echo "   Triggers de Cloud Build:     $TRIGGERS_QUEDAN"
echo "   Repos de Artifact Registry:  $(contar gcloud artifacts repositories list --location="$REGION" --format='value(name)')"
echo "   Buckets de builds:           $(contar buckets_de_builds)"

echo
if ((CONSERVADOS == 0)); then
  echo "🎉 Listo: borré $BORRADOS cosa(s). Ya no queda nada del workshop que te cobre."
  echo "   ¿Quieres volver a empezar? Desde CP0: ./scripts/setup.sh"
else
  echo "Listo: borré $BORRADOS cosa(s) y dejé $CONSERVADOS. Cuando quieras borrarlas, vuelve a correr ./scripts/cleanup.sh"
fi
