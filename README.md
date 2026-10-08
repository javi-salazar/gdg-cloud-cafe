# Ship it, Break it, Fix it ☕

**CI/CD en Cloud Run + un copiloto de incidentes con Gemini** · Workshop hands-on de GDG Hermosillo · 17 de octubre de 2026

Vas a desplegar *Cloud Café*, una pequeña app de FastAPI, a Cloud Run con un pipeline de Cloud Build.
Luego la vas a romper con un release malo y vas a hacer rollback en segundos.
Al final, un copiloto con Gemini va a leer los logs y te va a ayudar a diagnosticar el incidente.

## Pre-requisitos

| Necesitas | Detalle |
|---|---|
| 💻 Laptop con navegador | Chrome recomendado. Todo se hace en [Cloud Shell](https://shell.cloud.google.com): no instalas nada. |
| 🔑 Cuenta de Google personal | Mejor una Gmail personal: las cuentas de trabajo o escuela suelen tener políticas que bloquean servicios públicos. |
| 💳 Proyecto de Google Cloud con billing activo | Free trial o créditos. Cloud Run y Cloud Build piden billing activo aunque el consumo del workshop sea mínimo. |
| 🤖 API key de Gemini | Gratis en [AI Studio](https://aistudio.google.com/apikey), en un proyecto **sin** facturación (detalles en [copilot/](copilot/README.md)). |
| 🐙 Cuenta de GitHub | Opcional: solo si al final quieres llevarte tu propia copia (fork) del repo. |
| ⌨️ Terminal básica | Con saber copiar, pegar y correr comandos es suficiente. |

¿Ya tienes todo? En Cloud Shell, dentro del repo clonado, corre `./scripts/verify.sh`.

## Guía paso a paso

👉 **[docs/GUIA.md](docs/GUIA.md)** · Problemas comunes: [docs/GOTCHAS.md](docs/GOTCHAS.md)

## ¿Qué hay en este repo?

```text
app/             la app Cloud Café (FastAPI + una página HTML)
Dockerfile       cómo se empaqueta la app en un contenedor
cloudbuild.yaml  el pipeline: build → push → deploy a Cloud Run
scripts/         setup.sh, verify.sh y loadgen.sh
copilot/         el copiloto de incidentes con Gemini
docs/            la guía y los gotchas
```

Ramas: `main` (v1, estable) · `demo/bad-release` (v2 con promociones, roto a propósito) · `demo/fixed` (v2.1 con el fix)
