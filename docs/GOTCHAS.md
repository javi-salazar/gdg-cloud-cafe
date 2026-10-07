# Gotchas · ensayo real en GCP (Brief B)

> Ensayo de punta a punta el **7 de octubre de 2026** en un proyecto nuevo (`us-central1`, cuenta Gmail
> personal, sin organización), con gcloud 584 desde una laptop. Cloud Shell no se usó: lo que depende de él
> (pip, git, gh) va marcado **«por confirmar en el Brief D»**.

## Resumen

- **El flujo funciona en real y es más rápido de lo que dice la guía v1**: `setup.sh` ~30 s, primer deploy < 1 min.
- **3 cambios al repo** para que funcione bien (sección 11): `setup.sh` ya no falla en proyectos nuevos, el
  pipeline baja de 96 s a 59 s, y este documento.
- **GO/NO-GO del pipeline con trigger (CP3): NO-GO para los asistentes → demo del facilitador**; su camino
  es `gcloud run deploy --source`. Detalle en la sección 4.
- **Costo del ensayo: ~US$0.00** (todo dentro de la capa gratuita; sin ella, ~US$0.06). Sección 9.
- El desastre **sí se ve**: 5xx y latencia p95 de ~5.5 s en las métricas de Cloud Run, y tracebacks
  completos en Logging. El rollback recupera el servicio en **~30 s**.
- El paso de IAM de `setup.sh` **hace falta**: sin `run.admin`, el trigger deja el servicio privado (403)
  aunque el build salga verde (3.1).

## 1. Tiempos reales por paso

| Paso | Tiempo real | La guía v1 dice |
|---|---|---|
| Crear proyecto (`gcloud projects create`) | 8 s | — |
| Ligar billing | 2 s *(si la cuenta de billing tiene cupo, ver 2.1)* | — |
| `./scripts/setup.sh` en proyecto nuevo | **~30 s** (con el fix de 2.2) | 2–3 min |
| Primer `gcloud run deploy --source` | **~45 s** (build 22 s) + 1 pregunta (2.3) | 3–6 min |
| Segundo `deploy --source` | 42 s (build 23 s; no hay caché de capas entre builds) | — |
| Crear el trigger | 1 s por CLI | — |
| Commit → producción con trigger | **59 s** (antes del fix de 11.2: 96 s) | — |
| Merge del release malo → v2 en vivo (trigger) | 84 s (medido con la imagen lenta; con el fix de 11.2, ~1 min) | — |
| Métricas visibles en Cloud Monitoring | **~95 s** después del tráfico | — |
| Rollback (`update-traffic --to-revisions`) | **~26 s** hasta el cambio real; el comando regresa a los 29 s | "segundos" |
| Re-apuntar al último deploy (`--to-latest`) | 17 s | — |
| Limpieza completa (sección 8) | ~15 s | — |

## 2. Errores y fricciones (con su fix)

### 2.1 `Cloud billing quota exceeded` al ligar billing
`gcloud billing projects link` falló: la cuenta de billing ya tenía **5 proyectos ligados** y no acepta más
(`QuotaFailure … Cloud billing quota exceeded`).
- **Fix:** desligar un proyecto sin uso (`gcloud billing projects unlink OTRO_PROYECTO`) o pedir más cupo en
  <https://support.google.com/code/contact/billing_quota_increase> (tarda días).
- **Para asistentes:** quien ya usa GCP puede toparse con esto el día del evento → que creen el proyecto y
  liguen billing **en el pre-work**.

### 2.2 `setup.sh` fallaba siempre en un proyecto nuevo — ✅ corregido en el repo
`gcloud services enable` reporta éxito, pero Artifact Registry siguió respondiendo
`PERMISSION_DENIED … SERVICE_DISABLED … If you enabled this API recently, wait a few minutes` durante ~30 s.
En una terminal interactiva (Cloud Shell), gcloud además pregunta `Would you like to enable and retry? (y/N)`
y el script se queda esperando.
- **Fix:** `setup.sh` espera hasta 2 min a que Artifact Registry, Cloud Build y Cloud Run respondan, y corre con
  `CLOUDSDK_CORE_DISABLE_PROMPTS=1`. Probado desde cero: pasa a la primera en ~30 s.

### 2.3 El primer `deploy --source` hace una pregunta
```
Deploying from source requires an Artifact Registry Docker repository to store built containers.
A repository named [cloud-run-source-deploy] in region [us-central1] will be created.
Do you want to continue (Y/n)?
```
- **Fix:** responder `Y` (o Enter). Ojo: crea un **segundo** repositorio (`cloud-run-source-deploy`) además de
  `cloud-cafe`, y un bucket `run-sources-PROYECTO-us-central1` con el código subido. Todo va en la limpieza.
- `deploy` imprime la URL `https://cloud-cafe-NUMERO_DE_PROYECTO.us-central1.run.app`; la consola también
  muestra `https://cloud-cafe-<hash>-uc.a.run.app`. **Las dos sirven**: que nadie se asuste.

### 2.4 `/healthz` lo intercepta el edge de Google (confirmado en real)
Probado contra la URL pública. El header `X-Release` solo lo pone la app, así que indica quién respondió:

| Ruta | Respuesta | ¿Llega a la app? |
|---|---|---|
| `/`, `/api/menu`, `POST /api/order`, `/health`, `/docs`, `/redoc`, `/openapi.json`, `/static/*` | 200 | ✅ sí |
| `/healthz`, `/statusz` | 404 *"Error 404 (Not Found)!!1"* de Google | ❌ no (ni aparece en los logs) |
| `/_ah/warmup` | 302 del edge | ❌ no |
| `/readyz`, `/livez`, `/_ah/health`, `/eventlog` | 404 de FastAPI | ✅ sí |

- **Estado:** la app ya usa `/health` y ninguna de sus rutas choca con el edge.

### 2.5 Crear el trigger sin cuenta de servicio → error opaco
Por CLI: `INVALID_ARGUMENT: Request contains an invalid argument.` (sin más detalle, ni con `--log-http`).
En la consola, el formulario lo exige: *"Your organization policy requires you to select a user-managed
service account"* (aunque el proyecto no tenga organización).
- **Fix:** elegir `NUMERO_DE_PROYECTO-compute@developer.gserviceaccount.com`, la misma a la que `setup.sh` le da
  permisos. **La guía v1 (CP3) no menciona este campo.**

### 2.6 La GitHub App queda con acceso a **todos** tus repos
La pantalla de instalación de *Google Cloud Build* en GitHub trae marcado **"All repositories"**: Cloud Build
obtiene lectura de todos los repos de la cuenta, privados incluidos.
- **Fix:** elegir **"Only select repositories"** → solo el fork. Se corrige después en
  GitHub → Settings → Applications → Google Cloud Build → *Configure*.

### 2.7 Después de un rollback, los deploys nuevos reciben **0%** del tráfico
`update-traffic --to-revisions=REV=100` fija el tráfico en esa revisión. El siguiente deploy (trigger o
`--source`) se crea pero no recibe tráfico, y gcloud lo dice así:
```
Service [cloud-cafe] revision [cloud-cafe-00004-5vx] has been deployed and is serving 0 percent of traffic.
```
Además el mensaje **nombra la revisión equivocada**: la nueva era la `00005`; la `00004` era la rota.
- **Fix:** `gcloud run services update-traffic cloud-cafe --region us-central1 --to-latest` (17 s).
- **Afecta** al Bonus "El fix de verdad" y a cualquier deploy posterior a CP5/CP7.

### 2.8 Las métricas tardan ~1.5 min en aparecer
Medido: una ráfaga de 60 requests apareció en Cloud Monitoring a los **95 s**. En CP5, avisar que las gráficas
tardan 1–2 min en reflejar el release malo (los logs aparecen casi al instante).

## 3. Roles y permisos

- En un proyecto nuevo sin organización, la cuenta de servicio de Cloud Build por default es la
  **Compute Engine default SA** (`NUMERO-compute@developer.gserviceaccount.com`). Se crea sola al habilitar
  Cloud Run (aunque la API de Compute no esté habilitada) y recibe `roles/editor` automáticamente.
- `setup.sh` le agrega `run.admin`, `iam.serviceAccountUser`, `artifactregistry.writer` y `logging.logWriter`.
  Con eso los builds del trigger hicieron build → push → deploy `--allow-unauthenticated` **sin ningún error
  de permisos**.
- Quien corre el taller necesita ser **Owner** del proyecto y poder ligar billing.
- Del lado de GitHub, la app pide: lectura de código, issues, metadata y pull requests; lectura/escritura de
  checks y commit statuses.

### 3.1 ¿Qué pasa sin `run.admin`? (probado)
Se le quitó `run.admin` a la cuenta de servicio (quedó con `editor` + los otros 3 roles) y el trigger hizo el
**primer** deploy del servicio:
```
Setting IAM Policy.............warning
Completed with warnings:
  Setting IAM policy failed, try "gcloud beta run services add-iam-policy-binding --region=us-central1 --member=allUsers --role=roles/run.invoker cloud-cafe"
Service [cloud-cafe] revision [cloud-cafe-00001-6pl] has been deployed and is serving 100 percent of traffic.
```
- El build sale **verde (SUCCESS)**, pero la URL responde **403** a cualquier visitante. Es una falla
  silenciosa: solo se ve en el log del build.
- **Fix:** correr `./scripts/setup.sh` (21 s; devuelve `run.admin`) y volver a desplegar → **200**.
- En el orden de la guía, el primer deploy lo hace el asistente (Owner) con `--source` y el servicio ya queda
  público. Aun así, si alguien se salta CP2 o borra el servicio, sin este rol el trigger lo deja privado.

## 4. GitHub ↔ Cloud Build y recomendación GO/NO-GO

### 4.1 El flujo real en la consola (1st gen, región `global`)
1. *Cloud Build → Triggers → **Connect repository*** abre un panel de 4 pasos:
   1. **Proveedor:** *GitHub (Cloud Build GitHub App)*. (Cloud Source Repositories ya no está disponible para
      cuentas nuevas desde junio de 2024.)
   2. **Authenticate:** se abre una **ventana emergente** de GitHub → *Authorize Google Cloud Build*. Si GitHub
      no tiene sesión: login + 2FA.
   3. En GitHub, **Install Google Cloud Build** → elegir la cuenta → *All repositories* (marcado por default,
      ver 2.6) u *Only select repositories* → *Install*.
   4. **Select repository:** elegir `TU-USUARIO/gdg-cloud-cafe` + casilla de consentimiento → *Connect*.
2. *Create trigger*: nombre, región `global`, evento *Push to a branch*, fuente: *Cloud Build repositories* →
   *1st gen* → el repo, rama `^main$`, configuración *Cloud Build configuration file* (`/cloudbuild.yaml`) y
   **Service account (obligatoria, ver 2.5)**. La pantalla también ofrece *Developer Connect* y *2nd gen*:
   dos decisiones más donde perderse.

Equivalente por CLI (una vez conectado el repo):
```bash
gcloud builds triggers create github --name=deploy-main \
  --repo-owner=TU-USUARIO --repo-name=gdg-cloud-cafe --branch-pattern='^main$' \
  --build-config=cloudbuild.yaml \
  --service-account=projects/TU_PROJECT_ID/serviceAccounts/NUMERO-compute@developer.gserviceaccount.com
```

### 4.2 Tiempos
- **Conexión GitHub ↔ Cloud Build:** en este ensayo la hizo el facilitador a mano (las ventanas emergentes de
  OAuth quedan fuera de la pestaña de la consola). Le tomó **~1 min**, ya conociendo el flujo, y GitHub pidió
  **2FA**. El Brief D lo cronometra con alguien que lo hace por primera vez.
- **Trigger → producción:** push → build en **3 s**; build 14 s; push de imagen 7 s; deploy 31 s →
  **59 s** de commit a producción (con el fix de 11.2).

### 4.3 Recomendación: **NO-GO para los 40 → demo del facilitador**
Su camino es `gcloud run deploy --source` (CP2): ~45 s por deploy, sin credenciales de GitHub.
1. **Dos identidades y ventanas emergentes.** Consola de GCP + OAuth de GitHub + página de instalación de la
   app. La ventana de OAuth se abre fuera de la pestaña: bloqueadores de pop-ups, cuenta equivocada de Google
   o de GitHub, 2FA… En este ensayo ni la automatización pudo con ella; la completó una persona.
2. **Dos trampas que la guía no menciona:** la cuenta de servicio obligatoria (si falta, el error es opaco) y
   "All repositories" por default (un problema de privacidad con repos personales).
3. **`git push` desde Cloud Shell necesita autenticarse con GitHub** (token personal o `gh auth login`) y una
   identidad de git configurada. Son 3–5 min más por persona y tokens pegados en una terminal frente al grupo.
   *Por confirmar en el Brief D.*
4. **No escala con helpers:** cada bloqueo pasa en pantallas de GitHub que solo ve el asistente.
5. **El camino sin trigger enseña lo mismo:** imagen → revisión → tráfico → rollback, en menos tiempo.

No es un tema de cuotas: con 40 personas en paralelo no hay límites compartidos, porque cada quien tiene su
proyecto y su cuenta de GitHub.

**Adoptado en la GUIA v2:** CP3 es la demo del trigger y los asistentes despliegan con `deploy --source`;
el flujo fork + trigger queda como anexo para casa, con la checklist de 2.5, 2.6 y el token de GitHub.
**Para la demo:** el repo de ensayo ya está conectado a Cloud Build; un push a `main` llega a producción en ~1 min.

## 5. Break: ¿se ve el desastre?

Merge de `demo/bad-release` + push → v2 en vivo en **84 s**, con el badge en `v2-promos` (el servicio no tenía
variables de entorno: gana el default del código). `scripts/loadgen.sh` a ~2 req/s:

| Revisión | Requests | 5xx | Latencia p95 |
|---|---|---|---|
| v1 (antes) | 199 | 0 | ~10 ms |
| v2 (`v2-promos`) | 365 | 58 (16% del total, ~32% de las órdenes) | **5.5 s** |

- **Métricas** (pestaña *Metrics* del servicio): por minuto, 13–20% de 5xx y p95 de 5.2–5.7 s solo en la
  revisión v2. Aparecen ~95 s después del tráfico (2.8).
- **Logs** con filtro `severity>=ERROR`: 58 entradas de la app (una por error, con el traceback completo en una
  sola entrada JSON) + 58 *request logs* con status 500. Así se ve cada una:
  ```
  La orden de cold_brew falló: promo engine crashed
  Traceback (most recent call last):
    File "/app/main.py", line 132, in ordenar
      orden = preparar_orden(cafe)
    File "/app/main.py", line 88, in preparar_orden
      "promo_pct": obtener_promo(cafe["id"]),  # NUEVO en v2
    File "/app/main.py", line 77, in obtener_promo
      raise RuntimeError("promo engine crashed")  # ...el motor truena 💥
  RuntimeError: promo engine crashed
  ```

## 6. Rollback

```bash
gcloud run revisions list --service cloud-cafe --region us-central1
gcloud run services update-traffic cloud-cafe --region us-central1 \
  --to-revisions=REVISION-SANA=100
```
- Con loadgen corriendo: el último request a v2 llegó **26 s** después de lanzar el comando; el comando regresó
  a los 29 s y desde ahí **todo verde**.
- Para volver a desplegar después de esto, ver **2.7** (`--to-latest`).

## 7. Fork y rescate

> **Decisión de diseño (7-oct):** en el taller nadie hace fork ni push; los asistentes clonan el repo original.
> Por eso se canceló la prueba de fork desde una organización. Esta sección solo aplica al anexo para casa.

**Paso exacto:** en `github.com/javi-salazar/gdg-cloud-cafe` → **Fork** → **desmarcar "Copy the `main` branch
only"** → *Create fork*.

**Rescate** para quien hizo el fork con la casilla marcada. Probado simulando un fork que solo trae `main`:
```bash
git remote add upstream https://github.com/javi-salazar/gdg-cloud-cafe.git
git fetch upstream demo/bad-release:demo/bad-release demo/fixed:demo/fixed
git push origin demo/bad-release demo/fixed
```
- Sin el rescate, CP4 falla con `merge: origin/demo/bad-release - not something we can merge`.
- Después del rescate aparecen `origin/demo/bad-release` y `origin/demo/fixed`, y el merge de CP4 funciona.
- El `git push` del rescate necesita autenticarse con GitHub (ver 4.3).
- **Si no hay push:** basta con `git fetch` y hacer el merge desde `upstream/demo/bad-release`; el camino con
  `deploy --source` no necesita las ramas en el fork.

## 8. Limpieza para re-ensayar

Deja el proyecto listo para otro ensayo; conserva billing, APIs, roles de IAM y la conexión con GitHub.
Medido: **~15 s**. Si algo ya no existe (por ejemplo, el repo `cloud-run-source-deploy` cuando no se usó
`--source`), ese comando falla con *not found* y no pasa nada.
```bash
gcloud run services delete cloud-cafe --region us-central1 --quiet
gcloud builds triggers delete deploy-main --quiet
gcloud artifacts repositories delete cloud-cafe --location us-central1 --quiet
gcloud artifacts repositories delete cloud-run-source-deploy --location us-central1 --quiet
gcloud storage rm -r gs://run-sources-TU_PROJECT_ID-us-central1
```
Para volver a empezar: `./scripts/setup.sh` (recrea el repo `cloud-cafe`) y seguir desde CP2.
**Re-ensayo probado:** después de la limpieza, `setup.sh` (21 s) + recrear el trigger + un build → servicio
público otra vez en ~1.5 min. Si el trigger se borró, se recrea con el comando de 4.1.
La GitHub App se revoca en GitHub → Settings → Applications.

## 9. Costo real

Uso medido en todo el ensayo, con los precios de lista y la capa gratuita mensual por cuenta de billing:

| Servicio | Uso | Capa gratuita | Costo |
|---|---|---|---|
| Cloud Build (e2-standard-2) | 8 builds, 7.8 min | 2,500 min | $0 (sin capa: $0.047) |
| Cloud Run | 1,029 requests, 546 s de instancia (1 vCPU, 512 MiB) | 2 M requests, 180k vCPU-s, 360k GiB-s | $0 (sin capa: $0.014) |
| Artifact Registry | < 250 MB durante < 2 h (imágenes de ~49 MB) | 0.5 GB | $0 |
| Cloud Logging | 0.9 MB | 50 GiB | $0 |
| Cloud Storage (fuentes) | KB | — | ~$0 |

**Total: ~US$0.00** (sin capa gratuita, ~US$0.06). Cada asistente usa menos que este ensayo, así que se
confirma la frase del pre-work ("menos de $1").
El reporte de facturación tarda hasta 24 h: *Billing → Reports*, filtrado por el proyecto.

## 10. Ajustes sugeridos a la GUIA v1

> **Estado en la GUIA v2:** ya incorpora 1, 3, 4, 6, 7, 8 y 9. Quedan abiertos: 2 (crear el proyecto y ligar
> billing desde el pre-work), la pregunta `(Y/n)` del punto 5 y los repos y el bucket de la limpieza (punto 10).

1. **CP0:** `verify.sh` marca ❌ en las APIs hasta correr `setup.sh` (que está en CP2), así que el checkpoint
   "¡Listo para el workshop!" no se cumple en CP0. → Mover `./scripts/setup.sh` a CP0, antes de `verify.sh`
   (son ~30 s).
2. **Pre-work:** crear el proyecto y ligar billing antes del evento (2.1).
3. **CP0:** si habrá commits o merges en Cloud Shell, agregar `git config --global user.name "Tu Nombre"` y
   `git config --global user.email "tu@correo"`. *Por confirmar en el Brief D.*
4. **CP1:** el comando de uvicorn funciona tal cual desde la raíz del repo (probado). *Por confirmar en el
   Brief D:* si `pip3 install` en Cloud Shell falla con `externally-managed-environment`, usar
   `python3 -m venv .venv && . .venv/bin/activate` antes del `pip install`.
5. **CP2:** ajustar los tiempos (setup ~30 s, primer deploy < 1 min) y avisar de la pregunta `(Y/n)` (2.3).
6. **CP3** (si queda como demo o bonus): el nombre del café está en `app/static/index.html` (`<h1>☕ Cloud
   Café</h1>`), no en una constante de `main.py`. Editar ahí además evita conflictos con el merge de CP4, que
   solo toca `main.py`. Agregar la cuenta de servicio del trigger (2.5) y "Only select repositories" (2.6).
7. **CP4 sin trigger:** `git merge origin/demo/bad-release` + `gcloud run deploy cloud-cafe --source .
   --region us-central1`. No hace falta `git push`.
8. **CP5:** avisar que las métricas tardan ~1.5 min (2.8). El comando de rollback funciona tal cual (~30 s).
9. **Bonus "El fix de verdad" y fin de CP7:** después de `update-traffic --to-revisions`, agregar
   `gcloud run services update-traffic cloud-cafe --region us-central1 --to-latest` (2.7).
10. **Limpieza:** agregar los dos repos de Artifact Registry y el bucket `run-sources-…` (sección 8), y revocar
    o acotar la GitHub App.

## 11. Cambios al repo hechos en este ensayo

1. **`fix(setup)`:** esperar a que las APIs respondan y no hacer preguntas (2.2). Sin esto, `setup.sh` fallaba
   a la primera en el 100% de los proyectos nuevos.
2. **`build`:** el paso de deploy usa `gcr.io/cloud-builders/gcloud`, que Cloud Build ya tiene en caché: se
   descarga en 0 s contra 30 s de `cloud-sdk:slim`. Commit → producción pasa de 96 s a 59 s.
3. **`docs`:** este archivo.
