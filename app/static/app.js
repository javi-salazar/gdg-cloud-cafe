// Cloud Café — la lógica de la página, sin frameworks.

const menuEl = document.getElementById("menu");
const ordenesEl = document.getElementById("ordenes");
const releaseEl = document.getElementById("release");
const contadorEl = document.getElementById("contador");
const vacioEl = document.getElementById("vacio");

let exitos = 0;
let errores = 0;

// Cada respuesta de la API trae el header X-Release: lo ponemos en el badge.
function leerRelease(respuesta) {
  const release = respuesta.headers.get("X-Release") || "?";
  releaseEl.textContent = release;
  return release;
}

// 1) Pedimos el menú a la API y dibujamos un botón "Ordenar" por café.
async function cargarMenu() {
  try {
    const respuesta = await fetch("/api/menu");
    leerRelease(respuesta);
    const menu = await respuesta.json();
    for (const cafe of menu) {
      const boton = crear("button", "", "Ordenar");
      boton.addEventListener("click", () => ordenar(cafe));
      const fila = crear("li", "", "");
      fila.append(crear("span", "nombre", cafe.name), crear("span", "precio", `$${cafe.price}`), boton);
      menuEl.append(fila);
    }
  } catch (error) {
    menuEl.append(crear("li", "", "😢 No se pudo cargar el menú"));
  }
}

// 2) Ordenamos: POST /api/order y pintamos el resultado en verde o en rojo.
async function ordenar(cafe) {
  const linea = agregarLinea(`⏳ Preparando ${cafe.name}…`);
  const inicio = performance.now();
  try {
    const respuesta = await fetch("/api/order", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ item: cafe.id }),
    });
    const segundos = ((performance.now() - inicio) / 1000).toFixed(1);
    const release = leerRelease(respuesta);
    const datos = await respuesta.json().catch(() => ({})); // por si no viene JSON
    const detalle = `${segundos} s · release ${release}`;

    if (respuesta.ok) {
      let texto = `✅ Orden #${datos.order_id} · ${cafe.name} · lista en ~${datos.eta_min} min`;
      if (datos.promo_pct) texto += ` · 🎉 ${datos.promo_pct}% de descuento`;
      pintar(linea, "ok", texto, detalle);
      exitos++;
    } else {
      const motivo = typeof datos.detail === "string" ? datos.detail : "respuesta inesperada";
      pintar(linea, "error", `❌ Error ${respuesta.status} · ${cafe.name} · ${motivo}`, detalle);
      errores++;
    }
  } catch (error) {
    pintar(linea, "error", `❌ Sin respuesta del servidor · ${cafe.name}`, error.message);
    errores++;
  }
  contadorEl.textContent = `✅ ${exitos} · ❌ ${errores}`;
}

// --- Ayudantes ---------------------------------------------------------------

// Crea un elemento con su clase y su texto (textContent: nada de HTML inyectado).
function crear(etiqueta, clase, texto) {
  const el = document.createElement(etiqueta);
  if (clase) el.className = clase;
  el.textContent = texto;
  return el;
}

// Agrega una orden "en preparación" hasta arriba; guardamos solo las últimas 12.
function agregarLinea(texto) {
  vacioEl.hidden = true;
  const linea = crear("li", "pendiente", texto);
  ordenesEl.prepend(linea);
  while (ordenesEl.children.length > 12) ordenesEl.lastElementChild.remove();
  return linea;
}

// Cambia una orden a verde ("ok") o rojo ("error"), con el detalle abajo.
function pintar(linea, clase, texto, detalle) {
  linea.className = clase;
  linea.textContent = texto;
  linea.append(crear("small", "", detalle));
}

cargarMenu();
