#!/usr/bin/env bash
# verify.sh — ¿Estás listo para el workshop? Revisa los pre-requisitos y te
# dice cómo arreglar lo que falte. Solo lee: no cambia nada en tu proyecto.
#
# Uso: ./scripts/verify.sh
set -uo pipefail # sin "-e": queremos revisar TODO aunque algo falle

APIS=(
  run.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  logging.googleapis.com
)
FALLAS=0

ok() { echo "✅ $1"; }
falla() {
  echo "❌ $1"
  echo "   👉 Arreglo: $2"
  FALLAS=$((FALLAS + 1))
}

echo "🔎 Revisando los pre-requisitos del workshop..."
echo

# 1) gcloud instalado y con una sesión activa
if ! command -v gcloud >/dev/null 2>&1; then
  falla "No encuentro gcloud" "usa Cloud Shell (https://shell.cloud.google.com), ya trae todo instalado"
  exit 1
fi
CUENTA="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1)"
if [[ -n "$CUENTA" ]] && gcloud auth print-access-token >/dev/null 2>&1; then
  ok "gcloud autenticado como $CUENTA"
else
  falla "gcloud no tiene una sesión activa" "corre: gcloud auth login"
fi

# 2) Proyecto configurado (y que de verdad exista)
PROYECTO="$(gcloud config get-value project 2>/dev/null)"
if [[ -z "$PROYECTO" ]]; then
  falla "No hay proyecto configurado" "corre: gcloud config set project TU_PROJECT_ID"
elif ! gcloud projects describe "$PROYECTO" >/dev/null 2>&1; then
  falla "No puedo abrir el proyecto '$PROYECTO'" "revisa el ID con: gcloud projects list"
else
  ok "Proyecto configurado: $PROYECTO"
fi

# 3) y 4) Billing y APIs: solo tienen sentido con sesión y proyecto en orden
if ((FALLAS > 0)); then
  echo "⏭️  Billing y APIs se revisan cuando lo de arriba esté en verde."
else
  BILLING="$(gcloud billing projects describe "$PROYECTO" --format='value(billingEnabled)' 2>/dev/null)"
  if [[ "$BILLING" == "True" ]]; then
    ok "Billing activo"
  else
    falla "El proyecto no tiene billing activo" "vincula una cuenta de facturación en https://console.cloud.google.com/billing/linkedaccount?project=$PROYECTO"
  fi

  HABILITADAS="$(gcloud services list --enabled --format='value(config.name)' 2>/dev/null)"
  for API in "${APIS[@]}"; do
    if grep -qx "$API" <<<"$HABILITADAS"; then
      ok "API habilitada: $API"
    else
      falla "API sin habilitar: $API" "corre: ./scripts/setup.sh"
    fi
  done
fi

echo
if ((FALLAS == 0)); then
  echo "🎉 ¡Listo para el workshop!"
else
  echo "Te faltan $FALLAS cosa(s). Arregla los ❌ y vuelve a correr: ./scripts/verify.sh"
  exit 1
fi
