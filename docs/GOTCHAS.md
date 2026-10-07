# Gotchas · problemas comunes y cómo salir de ellos

> 🚧 **Placeholder.** Se completa junto con la [guía](GUIA.md).

## Cuenta, proyecto y billing
<!-- Detectado al construir el repo:
     - Cuentas de trabajo/escuela: las políticas de la organización pueden bloquear allUsers
       (Domain Restricted Sharing) o quitarle permisos a la cuenta de servicio por defecto.
     - Sin billing activo, setup.sh falla al habilitar las APIs. -->

## Cloud Shell

## GitHub: fork y ramas
<!-- Detectado al construir el repo:
     - El diálogo de fork trae marcada "Copy the main branch only": así el fork NO trae
       demo/bad-release ni demo/fixed. -->

## Cloud Build
<!-- Detectado al construir el repo:
     - $SHORT_SHA solo existe en builds disparados por un trigger. Con `gcloud builds submit`
       hay que pasarlo: --substitutions=SHORT_SHA=$(git rev-parse --short HEAD); si no,
       el paso 1 falla con "invalid reference format".
     - --allow-unauthenticated necesita run.services.setIamPolicy (roles/run.admin) en la
       cuenta de servicio de Cloud Build. Sin eso el deploy "termina con warnings" y la URL
       responde 403. setup.sh ya da ese rol. -->

## Cloud Run
<!-- Detectado al construir el repo:
     - La app usa /health y no /healthz: Cloud Run reserva algunas rutas que terminan en
       "z" y desde fuera pueden devolver un 404 de Google sin llegar al contenedor.
     - cloudbuild.yaml no manda RELEASE_NAME: el badge muestra el default del código de cada
       rama (v1-estable → v2-promos → v2.1-promos-fixed). Ojo: Cloud Run conserva las
       variables de entorno entre deploys; si alguna vez desplegaste con
       --set-env-vars=RELEASE_NAME=..., quítala con:
       gcloud run services update cloud-cafe --region=us-central1 --remove-env-vars=RELEASE_NAME -->

## Logs y métricas
<!-- Detectado al construir el repo:
     - La app escribe logs JSON de una línea (severity + message + release): en Cloud Logging
       se puede filtrar con severity>=ERROR y cada traceback queda en una sola entrada. -->

## Copiloto de Gemini
<!-- Llega en el Brief C. -->
