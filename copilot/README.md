# 🤖 Copiloto de incidentes

Lee los logs de tu servicio de Cloud Run y le pide a Gemini un diagnóstico, como lo haría un on-call senior: resumen, síntomas, hipótesis de causa raíz citando tus logs, acción inmediata y severidad.

```text
gcloud logging read  ──►  copilot.py  ──►  Gemini (API REST)  ──►  diagnóstico en tu terminal
 (errores + 5xx)          (los resume)       (PROMPT_INCIDENTE)
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

Real, del ensayo del 7 de octubre de 2026: release `v2-promos` en producción y 3 minutos de `loadgen.sh`.

```text
🤖 Copiloto de incidentes · cloud-cafe · últimos 10 min
📥 Leyendo logs con gcloud logging read...
🧠 Le mando 106 entradas (10 KB) a gemini-3.5-flash...

🔥 Resumen
El servicio cloud-cafe presenta fallas al procesar compras en el endpoint POST /api/order, devolviendo respuestas 500 y afectando a los usuarios que intentan ordenar café.

📊 Síntomas observados
- Errores HTTP 500 persistentes en la ruta POST /api/order.
- Se observan más de 50 fallas en una ventana de 3 minutos (de 04:02:19 a 04:05:10 UTC).
- Los fallos ocurren exclusivamente en la revisión cloud-cafe-00002-rxc con la versión release v2-promos.
- La falla impacta múltiples tipos de bebidas (americano, espresso, cafe_de_olla, latte, cold_brew).

🧠 Hipótesis de causa raíz
La nueva lógica de promociones introducida en la versión v2-promos tiene un error de ejecución que provoca la caída sistemática del flujo de órdenes. Esto se evidencia en la traza donde la función obtener_promo genera una excepción al invocar un "raise RuntimeError("promo engine crashed")" que resulta en el mensaje "RuntimeError: promo engine crashed" dentro de /app/main.py.

✅ Acción inmediata sugerida
Mitigar el impacto realizando un rollback inmediato al 100% del tráfico hacia una revisión anterior que no contenga el release v2-promos.
Comando de gcloud:
gcloud run services update-traffic cloud-cafe --to-revisions=REVISION-SANA=100 --region=us-central1

⚠️ Severidad estimada
SEV2 - Degradación seria para muchos usuarios. El endpoint de creación de órdenes falla de forma constante, impidiendo compras. No se cataloga como SEV1 porque no disponemos del volumen total de transacciones para confirmar si afecta a la totalidad de los usuarios. Para corroborar el porcentaje de impacto real, se debe revisar la métrica run.googleapis.com/request_count agrupada por response_code_class en Cloud Monitoring.

Esto es una hipótesis para verificar, no un veredicto.

⏱️  gemini-3.5-flash respondió en 8.2 s (5289 tokens de entrada)
```

En tu terminal sale con colores. Cada corrida redacta distinto: Gemini no responde dos veces igual.

## Cómo funciona (y qué puedes cambiar)

- **Los logs.** `gcloud logging read` con `FILTRO`: severidad WARNING o peor, más los requests 5xx del request log de Cloud Run, de los últimos N minutos. Como máximo 200 entradas o ~30 KB, y cada traceback repetido viaja una sola vez.
- **El prompt.** `PROMPT_INCIDENTE`, en español. Edítalo y vuelve a correr: pídele formato de postmortem, o que responda como pirata 🏴‍☠️.
- **El modelo.** `MODEL` (`gemini-3.5-flash`). Para cambiarlo, usa otro nombre de [la lista oficial](https://ai.google.dev/gemini-api/docs/models).
- **Costo.** $0 con una key del free tier (~5 mil tokens por diagnóstico).
- **Sus límites.** Solo ve errores: no sabe qué porcentaje del tráfico falla ni ve la latencia de los requests que sí salen bien. Y da hipótesis, no veredictos: verifica antes de copiar y pegar un comando que te sugiera.

## Si algo falla

| Mensaje | Qué hacer |
|---|---|
| `Falta tu API key de Gemini` | `export GEMINI_API_KEY=...` en ESTA pestaña: cada pestaña de Cloud Shell es una sesión distinta. |
| `ModuleNotFoundError` | `source .venv/bin/activate` |
| `No encontré logs` | Genera tráfico ~2 min con `./scripts/loadgen.sh` y revisa que el tráfico vaya a la revisión rota. |
| `Gemini respondió 402` | Tu key es de un proyecto con facturación: crea otra en uno sin facturación. |
| `Gemini respondió 429` | Límite del free tier: espera ~30 s y reintenta. |
| `Gemini respondió 503` | Gemini está saturado. El copiloto ya reintentó 2 veces; espera un minuto. |
