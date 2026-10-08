<!-- GUIA.md v2.2 — 8-oct-2026. Cambios sobre v2.1 (hallazgos del Brief C): (1) la API key de Gemini DEBE crearse en un proyecto sin facturación (en proyectos con billing la API es prepago → 402); (2) 402 y 503 agregados a los 🛟 de CP6/CP7; (3) el 17-oct es SÁBADO, no viernes (corregido en todo el texto). El copiloto usa gemini-3.5-flash con 2 reintentos ante 503 y filtro de errores + latencia. PENDIENTE: ensayo literal del Brief D. -->

# ☕ Ship it, Break it, Fix it — Guía del workshop

GDG Hermosillo · sábado 17 de octubre de 2026 · 2.5 horas CI/CD en Cloud Run + tu copiloto de incidentes con Gemini

---

## Cómo funciona esta guía

* El workshop avanza por checkpoints (CP0 a CP7). Nadie se queda atrás: no pasamos al siguiente hasta que casi todos tengan la ✅ del actual.
* Trabaja en pareja: uno teclea (driver), el otro lee la guía y navega la consola (navigator). Cambien de rol cuando quieran.
* Cada bloque de comandos es copy-paste. No teclees a mano lo que puedas copiar.
* ¿Te atoraste? Sticky rojo en tu laptop y un helper llega; mientras, tu pareja sigue. Cada checkpoint trae una caja 🛟 ¿Te perdiste? para alcanzarnos.
* Todo corre en Cloud Shell (una terminal en tu navegador): da igual si tu laptop es Windows, Mac o Linux, y no instalarás nada en ella.

> 💡 Donde veas `TU_PROJECT_ID`, pon el tuyo. Región de todo el workshop: `us-central1`.

---

## 📋 Pre-work (hazlo ANTES del evento, ~10 min)

1. Cuenta de Google personal (no la del trabajo si tiene restricciones).
2. Facturación habilitada en GCP: redime el crédito del evento con el link que te llegó por correo, o activa el [free trial](https://cloud.google.com/free) ($300 USD; pide tarjeta pero este workshop consume menos de $1 — medido).
3. Crea tu proyecto del workshop: [console.cloud.google.com](https://console.cloud.google.com/) → selector de proyectos (arriba a la izquierda) → New project → nómbralo `cloud-cafe-tunombre` → Create. Verifica que quede ligado a tu facturación (menú ☰ → Billing; si dice que no tiene, usa Link a billing account). Anota tu Project ID (puede diferir del nombre).
4. API key de Gemini (gratis, sin tarjeta): [aistudio.google.com/apikey](https://aistudio.google.com/apikey) → Create API key → ⚠️ créala en un proyecto nuevo o sin facturación (la opción por default de AI Studio) — NO dentro de tu proyecto `cloud-cafe-tunombre`: en proyectos con facturación la API de Gemini es de prepago y tu key respondería `402` el sábado. Guárdala donde la encuentres.
5. El día del evento: laptop con Chrome + cargador. Es todo. (Cuenta de GitHub: opcional — solo si al final quieres llevarte tu propia copia del repo.)

---

## CP0 — Despega tu entorno (al llegar)

1. Entra a [console.cloud.google.com](https://console.cloud.google.com/) y selecciona tu proyecto `cloud-cafe-tunombre` (el del pre-work). ¿No lo creaste? Sin drama, son 2 minutos: paso 3 del pre-work, aquí arriba.

2. Abre Cloud Shell: icono de terminal `>_` arriba a la derecha de la consola → Continue → autoriza.

3. Clona el repo del workshop, preséntate con git y prepara tu proyecto (el `setup.sh` habilita las APIs y deja todo listo — tarda ~1 min):

```bash
git clone https://github.com/javi-salazar/gdg-cloud-cafe.git
cd gdg-cloud-cafe
git config --global user.name "Tu Nombre"
git config --global user.email "tu@correo.com"
gcloud config set project TU_PROJECT_ID
./scripts/setup.sh
./scripts/verify.sh
```

✅ Checkpoint CP0: `verify.sh` termina con "¡Listo para el workshop!"

🛟 ¿Te perdiste?

* `verify.sh` marca ❌ en billing → tu proyecto no tiene facturación: consola → Billing → Link a billing account (la del crédito/trial), y corre `setup.sh` de nuevo.
* Cualquier otro ❌ → `setup.sh` y `verify.sh` son seguros de repetir las veces que haga falta.

---

# 🚀 Bloque 1 — SHIP IT

## CP1 — El café abre sus puertas (local)

Conoce la app: un café en línea con menú y órdenes. Córrela dentro de Cloud Shell:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8080 --app-dir .
```

Ábrela con Web Preview: botón `👁️ / ⬒` arriba a la derecha de Cloud Shell → Preview on port 8080.

Explora: el badge dice `v1-estable` (fíjate en él — va a contar la historia de hoy), ordena un café → sale verde con su latencia. Detén el server con `Ctrl+C` cuando termines.

✅ CP1: viste el menú y una orden exitosa en verde.

🛟 ¿Te perdiste? `ModuleNotFoundError` → te faltó activar el entorno: `source .venv/bin/activate` y reintenta. Puerto ocupado → `--port 8081` y preview en 8081.

---

## CP2 — Primer deploy a producción 🌎

Un solo comando construye tu contenedor, lo sube y lo publica:

```bash
gcloud run deploy cloud-cafe --source . --region us-central1 --allow-unauthenticated
```

> ✋ La primera vez te va a preguntar `Do you want to continue (Y/n)?` — quiere crear el repositorio donde guardará tus imágenes. Responde `Y` y Enter.

El primer deploy tarda ~1–2 min. Mientras corre, abre en la consola Cloud Build → History: eso que ves es tu código convirtiéndose en imagen y desplegándose — un pipeline de una tecla.

Al terminar te da una URL `https://cloud-cafe-....run.app`. Ábrela. Ese es TU servicio en producción: HTTPS, infraestructura de Google, y escala a cero cuando nadie lo usa (por eso cuesta ~$0).

✅ CP2: tu URL pública sirve el café con badge `v1-estable`. Mándale la URL a alguien que no esté aquí. 😎

🛟 ¿Te perdiste?

* `billing account not found` → catch-up de billing en CP0 y reintenta.
* Error de permisos/APIs → `./scripts/setup.sh` otra vez y reintenta el deploy.
* Se te cerró Cloud Shell → ábrelo de nuevo, `cd gdg-cloud-cafe` y sigue: nada se pierde.

---

## CP3 — El pipeline: de `git push` a producción

Primero mira la demo 👀: el facilitador va a conectar su repo a Cloud Build con un trigger — a partir de ahí, cada `git push` a `main` construye y despliega solo, sin tocar gcloud. Eso es CI/CD completo, y queda documentado en el anexo de esta guía para que lo montes en casa con calma (requiere autorizar la GitHub App, ~10 min la primera vez).

Ahora tú, con tu "pipeline manual" (mismo resultado, lo disparas tú): personaliza tu café y vuelve a desplegar.

1. Abre el editor de Cloud Shell (botón Open Editor o `edit app/static/index.html`) y cambia el nombre del café por el tuyo: "Cloud Café de Ana".

2. Guarda el cambio en git y despliega:

```bash
git add -A && git commit -m "feat: el café ya tiene dueño"
gcloud run deploy cloud-cafe --source . --region us-central1
```

(~45–60 segundos: ya no es el primer build.)

✅ CP3: tu URL muestra el nuevo nombre. Commit → producción, repetible las veces que quieras.

🛟 ¿Te perdiste? `git commit` pide identidad → corre los dos `git config` de CP0. El deploy reusó la URL de siempre — no se crea un servicio nuevo, se crea una revisión nueva (guarda ese concepto para CP5).

---

# 💥 Bloque 2 — BREAK IT

## CP4 — El release del viernes

Narrativa: marketing quiere promociones hoy. El equipo manda el release v2 sin probarlo mucho… Súbelo a producción (la rama ya viene en tu clone):

```bash
git merge origin/demo/bad-release -m "release: v2 con promos 🎉"
gcloud run deploy cloud-cafe --source . --region us-central1
```

Mientras despliega, abre otra pestaña de Cloud Shell (botón `+`) y genera tráfico de clientes:

```bash
cd gdg-cloud-cafe
./scripts/loadgen.sh https://TU-URL.run.app
```

Cuando el deploy termine, mira tu UI: badge `v2-promos`… y las órdenes empiezan a salir en rojo o tardan una eternidad. El loadgen escupe 500s. Felicidades: acabas de romper producción. 🎉 (A propósito. Eso es lo que lo hace divertido.)

✅ CP4: badge `v2-promos` y errores visibles en UI y loadgen.

🛟 ¿Te perdiste? `not something we can merge` → te falta el fetch: `git fetch origin` y reintenta. Conflicto de merge por tu cambio de CP3 → `git merge --abort`, luego `git checkout app/static/index.html` y reintenta el merge (tu nombre se pierde, el drama continúa).

---

## CP5 — Leer el desastre y revertirlo

1. Ve el daño como lo vería tu equipo de guardia: consola → Cloud Run → cloud-cafe:

* Pestaña Metrics: error rate y latencia (⏱️ dale ~2 min — las métricas tardan en aparecer; mientras, mira el loadgen).
* Pestaña Logs: filtra severidad `Error` — ahí está el traceback del promo engine. Ese texto exacto lo va a leer Gemini en el bloque 3.

En números reales de este mismo demo: v2 tira 13–20% de errores y un p95 de ~5.5 s, contra ~10 ms de v1. Eso, en tu empresa, es el teléfono sonando a las 3 AM.

2. A las 3 AM no debuggeas: restauras. Cloud Run guarda cada deploy como una revisión inmutable — regresa el tráfico a la anterior:

```bash
gcloud run revisions list --service cloud-cafe --region us-central1
gcloud run services update-traffic cloud-cafe --region us-central1 \
  --to-revisions REVISION-SANA=100
```

(La sana es la anterior a la del merge; en la lista se ve la hora de cada una. También se puede desde la consola: Revisions → ⋮ → Manage traffic.)

3. Refresca la UI (~26 segundos después): badge de vuelta a la versión sana, loadgen en verde. Tiempo de recuperación: medio minuto.

> ⚠️ Regla de la casa desde este momento: acabas de "anclar" el tráfico a una revisión específica. A partir de aquí, los deploys nuevos salen con 0% de tráfico hasta que lo liberes con:
>
> ```bash
> gcloud run services update-traffic cloud-cafe --region us-central1 --to-latest
> ```
>
> (Y ojo: el mensaje de gcloud tras el rollback puede nombrar una revisión que no es — confía en la lista, no en el mensaje.)

> 🧠 La moraleja del bloque: la velocidad segura no viene de deployar poco — viene de que cada cambio sea chico y reversible. El código roto sigue en `main`; en la vida real ahora harías el fix con calma (está resuelto en `demo/fixed`, por si quieres verlo).

✅ CP5: servicio restaurado, órdenes en verde otra vez.

---

# 🤖 Bloque 3 — FIX IT con Gemini

## CP6 — Enciende tu copiloto

El escenario: volvió a pasar (siempre vuelve a pasar), pero ahora tienes un copiloto que lee los logs por ti.

1. En la pestaña donde vas a trabajar, activa el entorno y configura tu API key (la del pre-work; si no la tienes: [aistudio.google.com/apikey](https://aistudio.google.com/apikey), 2 min, gratis — en un proyecto sin facturación):

```bash
cd gdg-cloud-cafe && source .venv/bin/activate
export GEMINI_API_KEY="pega-tu-key-aquí"
python3 copilot/copilot.py --help
```

(La key vive solo en tu sesión de Cloud Shell; no queda guardada en ningún archivo.)

✅ CP6: ves la ayuda del copiloto sin errores.

🛟 ¿Te perdiste? Error de key → exporta la variable en ESTA pestaña (cada pestaña es una sesión distinta). `ModuleNotFoundError` → te faltó el `source .venv/bin/activate`. Error 402 (prepayment credits are depleted) → tu key nació en un proyecto con facturación: crea una nueva en AI Studio dentro de un proyecto sin billing y re-exporta.

---

## CP7 — Tu primer incidente diagnosticado por AI

1. Revive el incidente: manda el tráfico de vuelta a la revisión rota y deja el loadgen corriendo ~2 min para generar evidencia fresca:

```bash
gcloud run services update-traffic cloud-cafe --region us-central1 \
  --to-revisions REVISION-ROTA=100
```

2. Llama a tu copiloto:

```bash
python3 copilot/copilot.py --minutes 10
```

3. Lee el diagnóstico: resumen, síntomas, hipótesis de causa raíz citando tus logs reales, acción sugerida y severidad. Compáralo con lo que TÚ viste en CP5: ¿coincide? ¿le creerías a las 3 AM?

4. Cierra el incidente como profesional: tráfico de vuelta a la revisión sana (comando de CP5) y `Ctrl+C` al loadgen.

✅ CP7: tienes un diagnóstico generado por Gemini a partir de los logs de TU servicio. Eso es AIOps en 2026 — y lo acabas de construir tú.

> 🧠 Discusión: la AI es excelente leyéndose el toil (resumir logs, triage inicial); la decisión de QUÉ hacer sigue siendo tuya. Por eso se llama copiloto.

🛟 ¿Te perdiste? "No encontré logs" → el loadgen no corrió contra la revisión rota: verifica el traffic split y dale 2 min más. Error 429 → espera 30 seg (free tier de Gemini) y reintenta. Error 503 → el modelo anda saturado: el copiloto reintenta solo dos veces; si persiste, dale unos segundos y vuelve a correrlo. Error 402 → tu key vive en un proyecto con facturación: crea una en un proyecto sin billing (caja de CP6).

---

## 🏁 Bonus para rápidos

* Canary release: manda 90/10 entre la revisión sana y la rota (`--to-revisions SANA=90,ROTA=10`) y observa en el loadgen cómo solo ~1 de cada 10 órdenes sufre. Así se prueba un release con el 10% de los usuarios.
* El fix de verdad: `git merge origin/demo/fixed`, deploy con `--source`, y libera el tráfico (`--to-latest` — la regla de la casa de CP5). Badge `v2.1-promos-fixed`, 0 errores. El ciclo completo: ship → break → rollback → fix → ship.
* Hackea a tu copiloto: edita `PROMPT_INCIDENTE` en `copilot/copilot.py` (pídele formato de postmortem, o que responda como pirata 🏴‍☠️) y vuelve a correrlo.
* Llévate tu copia: haz fork del repo a tu cuenta de GitHub (desmarca "Copy the `main` branch only" para llevarte también las ramas del demo) y monta el trigger de Cloud Build con calma en casa — pasos en el anexo.

---

## 🧹 Limpieza (importante si usaste free trial)

Lo de hoy cuesta ~$0 dentro del free tier (medido: $0.06 sin él). Para dejar todo impecable:

```bash
./scripts/cleanup.sh
```

(Borra el servicio, las imágenes de Artifact Registry —incluido el repo `cloud-run-source-deploy` que creó el deploy— y los buckets del build, con confirmación antes de cada cosa.)

O la opción nuclear, que borra absolutamente todo:

```bash
gcloud projects delete TU_PROJECT_ID
```

---

## 📎 Anexo para casa: el pipeline con trigger (lo que viste en la demo)

1. Haz fork del repo (con las ramas demo) y conéctalo: consola → Cloud Build → Triggers → Connect repository → GitHub → autoriza la GitHub App. 💡 GitHub te va a sugerir darle acceso a todos tus repos — elige Only select repositories y selecciona solo tu fork.
2. Crea el trigger: Create trigger → evento Push to a branch → rama `^main$` → Cloud Build configuration file (`cloudbuild.yaml`) → y asígnale la cuenta de servicio de Cloud Build (si la dejas vacía, el error es un críptico `INVALID_ARGUMENT`).
3. Para pushear desde Cloud Shell necesitas autenticarte con GitHub (`gh auth login` o un token personal).
4. Push a `main` → mira Cloud Build → History → tu URL se actualiza sola en ~1 min. Eso es CI/CD.

---

## 📚 Para seguir

* Todos los recursos de SRE/DevOps de la charla de julio + los de hoy: [sre-talk-gdg.web.app](https://sre-talk-gdg.web.app/)
* Este repo queda público — issues y PRs bienvenidos.
* ¿Dudas de SRE, de GCP o de cómo entrarle a esta carrera? LinkedIn: javier-salazar-dev. Mi bandeja está abierta.

Hecho con ☕ para GDG Hermosillo — Javier Salazar, oct 2026.
