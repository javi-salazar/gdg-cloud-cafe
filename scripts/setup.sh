#!/usr/bin/env bash
# setup.sh — Prepara tu proyecto de Google Cloud para el workshop:
#   1. Habilita las APIs de Cloud Run, Cloud Build, Artifact Registry y Logging.
#   2. Crea el repositorio Docker "cloud-cafe" en Artifact Registry (us-central1).
#   3. Le da a la cuenta de servicio de Cloud Build permiso de desplegar en
#      Cloud Run (sin esto, --allow-unauthenticated no puede hacerlo público).
#
# Es idempotente: puedes correrlo todas las veces que quieras.
# Uso: ./scripts/setup.sh
set -euo pipefail

REGION="us-central1"
REPO="cloud-cafe"
APIS=(
  run.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  logging.googleapis.com
)
ROLES=(
  roles/run.admin               # desplegar el servicio y hacerlo público
  roles/iam.serviceAccountUser  # correr el servicio con su cuenta de servicio
  roles/artifactregistry.writer # subir imágenes
  roles/logging.logWriter       # escribir los logs del build
)

# Si un comando falla, damos pistas antes de salir.
ayuda_si_falla() {
  echo
  echo "❌ Algo falló (el error de gcloud está arriba). Lo más común:"
  echo "   • Habla de billing          → activa la facturación del proyecto."
  echo "   • Dice PERMISSION_DENIED    → necesitas ser Owner del proyecto."
  echo "   • Acabas de habilitar APIs  → espera un minuto y vuelve a correr ./scripts/setup.sh"
}
trap ayuda_si_falla ERR

PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ No hay proyecto configurado. Corre: gcloud config set project TU_PROJECT_ID"
  exit 1
fi
echo "☕ Preparando el proyecto: $PROJECT_ID"
echo

echo "[1/3] Habilitando APIs (la primera vez tarda 1-2 minutos)..."
gcloud services enable "${APIS[@]}"
echo "      ✅ APIs habilitadas"

echo "[2/3] Repositorio '$REPO' en Artifact Registry ($REGION)..."
if gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1; then
  echo "      ✅ Ya existía"
else
  gcloud artifacts repositories create "$REPO" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Imágenes del workshop Cloud Café"
  echo "      ✅ Creado"
fi

echo "[3/3] Permisos para que Cloud Build despliegue en Cloud Run..."
# gcloud la devuelve como "projects/.../serviceAccounts/CORREO"; nos quedamos con el CORREO.
CUENTA_BUILD="$(gcloud builds get-default-service-account --format='value(serviceAccountEmail)')"
CUENTA_BUILD="${CUENTA_BUILD##*/}"
echo "      Cuenta de servicio de Cloud Build: $CUENTA_BUILD"
for ROL in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$CUENTA_BUILD" \
    --role="$ROL" \
    --condition=None \
    --quiet >/dev/null
  echo "      ✅ $ROL"
done

echo
echo "🎉 Proyecto listo. Confírmalo con: ./scripts/verify.sh"
