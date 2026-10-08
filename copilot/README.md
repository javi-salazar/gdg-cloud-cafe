# 🤖 Copiloto de incidentes

Lee los logs de tu servicio de Cloud Run y le pide a Gemini un diagnóstico, como lo haría un on-call senior: resumen, síntomas, hipótesis de causa raíz citando tus logs, acción inmediata y severidad.

```text
gcloud logging read  ──►  copilot.py  ──►  Gemini (API REST)  ──►  diagnóstico en tu terminal
 (errores, 5xx, lentos)   (los resume)       (PROMPT_INCIDENTE)
```

## Setup en 3 pasos

1. **Saca tu API key de Gemini** (gratis): [aistudio.google.com/apikey](https://aistudio.google.com/apikey) → Create API key.
   Créala en un proyecto **sin facturación**: en uno con facturación, Gemini pide prepago y responde `402`.
2. **Activa el entorno de CP1** (ya trae `requests`) y exporta la key en esa misma pestaña:

   ```bash
   cd gdg-cloud-cafe && source .venv/bin/activate
   export GEMINI_API_KEY="pega-tu-key-aquí"
   ```

3. **Llama al copiloto** con el incidente en curso (y el loadgen corriendo un par de minutos):

   ```bash
   python3 copilot/copilot.py --minutes 10
   ```

| Flag | Default | Qué hace |
|---|---|---|
| `--minutes N` | `15` | cuántos minutos hacia atrás leer |
| `--service NOMBRE` | `cloud-cafe` | el servicio de Cloud Run |
| `--raw` | | muestra también los logs que se le envían a Gemini |

## Ejemplo de salida

Real, del ensayo del 8 de octubre de 2026: release `v2-promos` en producción, 3 minutos de `loadgen.sh` y
`--minutes 15`.

```text
🤖 Copiloto de incidentes · cloud-cafe · últimos 15 min
📥 Leyendo logs con gcloud logging read...
🧠 Le mando 200 entradas (19 KB) a gemini-3.5-flash...

🔥 Resumen
El endpoint POST /api/order presenta errores 500 intermitentes y alta latencia en la revisión cloud-cafe-00002-rxc.
Esto afecta a los usuarios que intentan realizar compras de café a través de la aplicación.

📊 Síntomas observados
- Errores: Múltiples respuestas HTTP 500 rápidas (de 3 a 5 ms) en POST /api/order desde las 19:19:13 UTC, asociadas al mensaje "La orden de [producto] falló: promo engine crashed" en la revisión cloud-cafe-00002-rxc (release v2-promos).
- Latencia: Múltiples peticiones POST /api/order con respuesta 200 OK tardan entre 3.0 y 6.0 segundos, experimentando una lentitud crítica en la misma revisión.

🧠 Hipótesis de causa raíz
La nueva lógica de promociones en la revisión cloud-cafe-00002-rxc (release v2-promos) tiene un bug de software que interrumpe la ejecución del código, respaldado por "RuntimeError: promo engine crashed". Ambos síntomas (errores 500 y latencia de hasta 6 segundos) ocurren simultáneamente en el endpoint "POST /api/order" bajo la misma revisión, sugiriendo que la integración del motor de promociones ("promo_pct": obtener_promo(cafe["id"])) genera bloqueos que ralentizan las órdenes exitosas y colapsa directamente con un "RuntimeError" en ciertos casos.

✅ Acción inmediata sugerida
Mitigar inmediatamente el impacto desviando el 100% del tráfico de Cloud Run hacia una revisión previa que se conozca como estable (REVISION-SANA).
Comando de gcloud:
gcloud run services update-traffic cloud-cafe --to-revisions=REVISION-SANA=100 --region=us-central1

⚠️ Severidad estimada
SEV2 - Degradación seria para muchos usuarios. No es SEV1 porque el servicio no está totalmente caído (aún se procesan peticiones 200 OK), pero el flujo principal de compras está severamente degradado por fallas y lentitud extrema. Para confirmar el porcentaje exacto de transacciones afectadas, se debe revisar la métrica de "Request count" agrupada por código de estado en Cloud Monitoring.

Esto es una hipótesis para verificar, no un veredicto.

⏱️  gemini-3.5-flash respondió en 10.4 s (10499 tokens de entrada)
```

En tu terminal sale con colores. Cada corrida redacta distinto: Gemini no responde dos veces igual.

## Cómo funciona (y qué puedes cambiar)

- **Los logs.** `gcloud logging read` con `FILTRO`: severidad WARNING o peor, más los requests del request log de Cloud Run que terminaron en 5xx o tardaron 1 s o más, de los últimos N minutos. Como máximo 200 entradas o ~30 KB (quedan las más nuevas), y cada traceback repetido viaja una sola vez.
- **El prompt.** `PROMPT_INCIDENTE`, en español. Edítalo y vuelve a correr: pídele formato de postmortem, o que responda como pirata 🏴‍☠️.
- **El modelo.** `MODEL` (`gemini-3.5-flash`). Para cambiarlo, usa otro nombre de [la lista oficial](https://ai.google.dev/gemini-api/docs/models).
- **Costo.** $0 con una key del free tier (~10 mil tokens por diagnóstico).
- **Sus límites.** Solo ve errores y requests lentos: los rápidos que salen bien no viajan, así que no sabe qué porcentaje del tráfico falla. Y da hipótesis, no veredictos: verifica antes de copiar y pegar un comando que te sugiera.

## Si algo falla

| Mensaje | Qué hacer |
|---|---|
| `Falta tu API key de Gemini` | `export GEMINI_API_KEY=...` en ESTA pestaña: cada pestaña de Cloud Shell es una sesión distinta. |
| `ModuleNotFoundError` | `source .venv/bin/activate` |
| `No encontré logs` | Genera tráfico ~2 min con `./scripts/loadgen.sh` y revisa que el tráfico vaya a la revisión rota. |
| `Gemini respondió 402` | Tu key es de un proyecto con facturación: crea otra en uno sin facturación. |
| `Gemini respondió 429` | Límite del free tier: espera ~30 s y reintenta. |
| `Gemini respondió 503` | Gemini está saturado. El copiloto ya reintentó 2 veces; espera un minuto. |
