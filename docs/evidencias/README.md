# Evidencias del ensayo (plan B)

Si el demo en vivo falla, con estas capturas puedes contar cada checkpoint sin correr nada.
Salen del ensayo literal de la [guía](../GUIA.md) (v2.3.1) que se hizo el **8 de octubre de 2026** (noche de Hermosillo; las horas van en UTC, del 9 de octubre) en un proyecto nuevo, `gdg-cloud-cafe-dry`.

- **Cloud Shell real (Chrome):** CP0 a CP5, la parte de CP6 sin key, el cambio de tráfico de CP7 y el bonus.
- **Laptop:** el `--check` con una key válida (CP6), el diagnóstico de CP7, el prompt pirata y la limpieza. Nunca se teclea una API key en el navegador.
- **Datos personales tapados:** en las capturas y en los textos ya no aparecen el correo, el usuario de Cloud Shell ni el avatar.

| Archivo | Qué muestra |
|---|---|
| **CP0** | |
| `CP0-1-cloudshell-setup-y-verify.png` | `setup.sh` (41 s en proyecto nuevo) y `verify.sh` terminando en "¡Listo para el workshop!" |
| `CP0-2-verify.txt` | La salida de `verify.sh` en texto |
| **CP1** | |
| `CP1-1-app-local-web-preview.jpg` | La app en Web Preview (puerto 8080): badge `v1-estable` y órdenes verdes de 0.1 s |
| **CP2** | |
| `CP2-1-prompt-Yn-primer-deploy.png` | El prompt `Do you want to continue (Y/n)?` del primer deploy |
| `CP2-2-deploy-terminal.png` | El deploy terminado con su `Service URL` (41 s después del Y) |
| `CP2-3-cloud-build.jpg` | Cloud Build → History → el build (23 s) |
| `CP2-4-url-publica-v1.jpg` | La URL pública sirviendo `v1-estable` |
| `CP2-5-builds.txt` | Los 4 builds del ensayo, de 22 a 24 s cada uno |
| **CP3** | |
| `CP3-1-url-cafe-de-ana.jpg` | "Cloud Café de Ana" en producción (deploy de 38 s) |
| **CP4** | |
| `CP4-1-loadgen-v2.png` | El loadgen cuando entra v2: 500 y órdenes de 4–6 s (🐢) |
| `CP4-2-url-v2-promos.jpg` | La UI con `v2-promos`: un ❌ 500 "promo engine crashed" y órdenes de 3.7–5.9 s |
| **CP5** | |
| `CP5-1-metricas-v2.jpg` | Observability → Metrics con rango "Last 30 minutes": suben los 5xx y la latencia llega a ~5–6 s |
| `CP5-2-metricas-por-minuto.txt` | La tabla por minuto: v2 da 12–19 % de 5xx y p95 de ~5.6–5.8 s; v1 da p95 de 10–23 ms |
| `CP5-3-logs-traceback.jpg` | Observability → Logs → Severity "Error" con el traceback expandido |
| `CP5-4-traceback.txt` | El mismo traceback en texto, tal como lo guarda Cloud Logging |
| `CP5-5-rollback-linea-de-tiempo.txt` | El rollback segundo a segundo: unos 10 s del Enter a la primera orden sana |
| `CP5-6-url-despues-del-rollback.jpg` | La UI de vuelta en `v1-estable` |
| **CP6** | |
| `CP6-1-check-sin-key-y-placeholder.png` | `--check` sin key (los 3 pasos) y con el placeholder `pega-tu-key-aqui` (400 y la pista), las dos con exit 1 |
| `CP6-2-check-ok.txt` | `✅ key válida — Gemini respondió` |
| **CP7** | |
| `CP7-1-copiloto.txt` | El diagnóstico de Gemini sobre los logs reales: 5.9 s, 10.5 k tokens, SEV2 |
| `CP7-2-copiloto-con-colores.ansi.txt` | El mismo diagnóstico con colores; en una terminal, `cat` lo muestra igual que en vivo |
| `CP7-3-loadgen-resumen.png` | El resumen del loadgen al cerrar el incidente: 1568 requests, 148 con error y 391 lentos |
| **Bonus** | |
| `BONUS-1-canary-90-10.png` | El canary 90/10: 180 requests, 2 errores y 5 lentos (~1 de cada 10 órdenes) |
| `BONUS-2-merge-fixed-abre-nano.png` | `git merge origin/demo/fixed` sin `-m` abre nano |
| `BONUS-3-deploy-fix-mensaje-revision-equivocada.png` | Con el tráfico anclado, el deploy dice que "sirve" la revisión rota al 10 % (la nueva queda en 0 %) |
| `BONUS-4-fix-loadgen-0-errores.png` | `v2.1-promos-fixed` después de `--to-latest`: 80 requests, 0 errores y 0 lentos |
| `BONUS-5-url-v2.1-promos-fixed.jpg` | La UI con `v2.1-promos-fixed`: órdenes de 0.1 s con su descuento |
| `BONUS-6-copiloto-pirata.txt` | "Hackea a tu copiloto": el mismo diagnóstico, en pirata 🏴‍☠️ |
| **Limpieza** | |
| `LIMPIEZA-1-cleanup-sh.txt` | `./scripts/cleanup.sh` borrando el servicio, 2 triggers, 2 repos de Artifact Registry y el bucket de fuentes, con el inventario final en 0 |
| `REVISIONES-final.txt` | Las 4 revisiones del ensayo y qué release es cada una |
