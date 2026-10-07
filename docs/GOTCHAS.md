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
     - Cloud Run reserva algunas rutas que terminan en "z": /healthz puede devolver un 404
       de Google desde fuera, sin llegar al contenedor (localmente sí funciona).
     - cloudbuild.yaml pone RELEASE_NAME=$SHORT_SHA, así que en Cloud Run el badge muestra
       el SHA del commit, no "v1-estable" / "v2-promos" (esos defaults se ven en local). -->

## Logs y métricas
<!-- Detectado al construir el repo:
     - La app escribe logs JSON de una línea (severity + message + release): en Cloud Logging
       se puede filtrar con severity>=ERROR y cada traceback queda en una sola entrada. -->

## Copiloto de Gemini
<!-- Llega en el Brief C. -->
