<script setup>
import { computed, onMounted, ref } from 'vue'

const API_URL = 'http://localhost:3000/api/libros'
const libros = ref([])
const busqueda = ref('')
const terminoAplicado = ref('')
const temaSeleccionado = ref('Todos')
const cargando = ref(true)
const error = ref('')
const libroReserva = ref(null)
const nombreReserva = ref('')
const contactoReserva = ref('')
const mensajeReserva = ref('')
const recomendacion = ref('')

const temas = computed(() => ['Todos', ...new Set(libros.value.map((libro) => libro.tema))])
const librosFiltrados = computed(() => {
  const termino = terminoAplicado.value.toLocaleLowerCase('es').trim()
  return libros.value.filter((libro) => {
    const coincideTema = temaSeleccionado.value === 'Todos' || libro.tema === temaSeleccionado.value
    const texto = `${libro.titulo} ${libro.tema} ${libro.descripcion}`.toLocaleLowerCase('es')
    return coincideTema && (!termino || texto.includes(termino))
  })
})

const formatoPrecio = (precio) => new Intl.NumberFormat('es-CL', {
  style: 'currency', currency: 'CLP', maximumFractionDigits: 0
}).format(precio)

async function cargarLibros() {
  cargando.value = true
  error.value = ''
  try {
    const respuesta = await fetch(API_URL)
    if (!respuesta.ok) throw new Error(`Error HTTP ${respuesta.status}`)
    const datos = await respuesta.json()
    if (!Array.isArray(datos)) throw new Error('Formato de respuesta inesperado')
    libros.value = datos.map((libro) => ({
      id: libro.id_libro,
      titulo: libro.titulo,
      precio: Number(libro.precio),
      descripcion: libro.descripcion || '',
      tema: libro.tema || libro.nombre_categoria || libro.categoria || '',
      imagen: libro.imagen_url || ''
    }))
  } catch (e) {
    console.error('Error al consultar los libros:', e)
    error.value = 'No se pudo cargar el catálogo. Comprueba que el backend esté encendido en el puerto 3000.'
  } finally {
    cargando.value = false
  }
}

function buscarLibros() {
  terminoAplicado.value = busqueda.value
  document.getElementById('catalogo')?.scrollIntoView({ behavior: 'smooth' })
}

function recomendar(tema) {
  const reglas = {
    orar: ['oración', 'orar'],
    fe: ['fe', 'cristianismo'],
    crecer: ['vida cristiana', 'conocimiento de dios', 'santidad'],
    misiones: ['misiones', 'misionera']
  }
  const palabras = reglas[tema] || []
  const encontrado = libros.value.find((libro) => {
    const texto = `${libro.titulo} ${libro.tema} ${libro.descripcion}`.toLocaleLowerCase('es')
    return palabras.some((palabra) => texto.includes(palabra))
  })
  recomendacion.value = encontrado
    ? `Te recomendamos «${encontrado.titulo}». Puedes encontrarlo en nuestro catálogo.`
    : 'Por el momento no encontramos un libro para ese interés.'
}

function elegirReserva(libro) {
  libroReserva.value = libro
  mensajeReserva.value = ''
  document.getElementById('reservas')?.scrollIntoView({ behavior: 'smooth' })
}

function enviarInteres() {
  if (!libroReserva.value || !nombreReserva.value.trim() || !contactoReserva.value.trim()) {
    mensajeReserva.value = 'Selecciona un libro y completa tu nombre y contacto.'
    return
  }
  mensajeReserva.value = 'Datos ingresados correctamente. Esta es una demostración: la reserva aún no se guarda en la base de datos.'
}

onMounted(cargarLibros)
</script>

<template>
  <div class="pagina">
    <header class="encabezado">
      <h1>Librería Cristiana</h1>
      <p>Literatura que inspira, enseña y fortalece la fe</p>
    </header>

    <nav class="menu" aria-label="Navegación principal">
      <a href="#inicio">Inicio</a>
      <a href="#catalogo">Catálogo</a>
      <a href="#recomendaciones">Recomendaciones</a>
      <a href="#reservas">Reservas</a>
    </nav>

    <main id="inicio">
      <section class="bienvenida">
        <h2>Bienvenidos a nuestra Librería Cristiana</h2>
        <p>Un espacio donde podrás descubrir libros cristianos, explorar diferentes temáticas y encontrar lecturas que acompañen tu crecimiento espiritual.</p>
        <form class="buscador" @submit.prevent="buscarLibros">
          <input v-model="busqueda" type="search" placeholder="Buscar libros por título o temática" aria-label="Buscar libros" />
          <button type="submit">Buscar</button>
        </form>
      </section>

      <section id="catalogo" class="seccion">
        <div class="titulo-seccion">
          <h2>Catálogo de libros</h2>
          <span>{{ librosFiltrados.length }} libro(s)</span>
        </div>
        <div class="filtros">
          <label for="tema">Filtrar por temática:</label>
          <select id="tema" v-model="temaSeleccionado">
            <option v-for="tema in temas" :key="tema" :value="tema">{{ tema }}</option>
          </select>
        </div>
        <p v-if="cargando" role="status">Cargando libros desde PostgreSQL...</p>
        <div v-else-if="error" class="aviso-error" role="alert">
          <p>{{ error }}</p>
          <button type="button" @click="cargarLibros">Reintentar</button>
        </div>
        <p v-else-if="librosFiltrados.length === 0">No se encontraron libros con los filtros seleccionados.</p>
        <div v-else class="cuadricula">
          <article v-for="libro in librosFiltrados" :key="libro.id" class="tarjeta">
            <div class="portada">
              <img v-if="libro.imagen" :src="libro.imagen" :alt="`Portada de ${libro.titulo}`" />
              <span v-else aria-hidden="true">📖</span>
            </div>
            <div class="contenido-tarjeta">
              <span class="tematica">{{ libro.tema }}</span>
              <h3>{{ libro.titulo }}</h3>
              <p>{{ libro.descripcion }}</p>
              <strong class="precio">{{ formatoPrecio(libro.precio) }}</strong>
              <button type="button" @click="elegirReserva(libro)">Me interesa reservar</button>
            </div>
          </article>
        </div>
      </section>

      <section id="recomendaciones" class="seccion">
        <h2>Recomendaciones de lectura</h2>
        <p>¿Qué tema te interesa? Selecciona una opción para recibir una recomendación basada en nuestro catálogo.</p>
        <div class="opciones">
          <button type="button" @click="recomendar('orar')">Quiero aprender a orar</button>
          <button type="button" @click="recomendar('fe')">Quiero fortalecer mi fe</button>
          <button type="button" @click="recomendar('crecer')">Quiero crecer espiritualmente</button>
          <button type="button" @click="recomendar('misiones')">Me interesan las misiones</button>
        </div>
        <p v-if="recomendacion" class="resultado" role="status">{{ recomendacion }}</p>
      </section>

      <section id="reservas" class="seccion">
        <h2>Reserva de libros</h2>
        <p>Selecciona un libro del catálogo y completa tus datos para demostrar cómo funcionará la solicitud de reserva para retiro en librería.</p>
        <p v-if="libroReserva" class="seleccion">Libro seleccionado: <strong>{{ libroReserva.titulo }}</strong></p>
        <p v-else>Primero selecciona «Me interesa reservar» en un libro.</p>
        <form class="formulario" @submit.prevent="enviarInteres">
          <label for="nombre">Nombre</label>
          <input id="nombre" v-model="nombreReserva" type="text" placeholder="Tu nombre" required />
          <label for="contacto">Correo electrónico o teléfono</label>
          <input id="contacto" v-model="contactoReserva" type="text" placeholder="Tu contacto" required />
          <button type="submit" :disabled="!libroReserva">Registrar interés (demostración)</button>
        </form>
        <p v-if="mensajeReserva" class="resultado" role="status">{{ mensajeReserva }}</p>
        <small>Esta versión aún no registra reservas reales ni modifica el inventario.</small>
      </section>
    </main>

    <footer><p>Proyecto de Título - Librería Cristiana</p></footer>
  </div>
</template>

<style scoped>
.pagina{min-height:100vh;background:#f7f5ef;color:#333;font-family:Arial,sans-serif}
.encabezado{background:#254735;color:white;text-align:center;padding:35px 20px}
.encabezado h1{margin:0 0 12px;font-size:2.3rem}
.encabezado p{margin:0}
.menu{display:flex;justify-content:center;flex-wrap:wrap;gap:25px;background:#d8c7a0;padding:15px}
.menu a{color:#254735;text-decoration:none;font-weight:bold}
.menu a:hover{text-decoration:underline}
main{max-width:1100px;margin:auto;padding:25px}
.bienvenida{text-align:center;padding:35px 15px}
h2,h3{color:#254735}
.bienvenida p{line-height:1.7;max-width:850px;margin:18px auto}
.buscador{display:flex;justify-content:center;flex-wrap:wrap;gap:10px;margin-top:25px}
.buscador input{width:350px;max-width:100%;padding:12px;border:1px solid #bbb;border-radius:5px;background:white;color:#333}
button{padding:12px 18px;background:#254735;color:white;border:0;border-radius:5px;cursor:pointer;font:inherit}
button:hover{background:#37634b}
button:disabled{opacity:.55;cursor:not-allowed}
.seccion{background:white;padding:26px;margin-bottom:22px;border-radius:10px;scroll-margin-top:15px}
.titulo-seccion{display:flex;justify-content:space-between;align-items:center;gap:15px;flex-wrap:wrap}
.titulo-seccion h2{margin:0 0 12px}
.filtros{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:16px 0 22px}
.filtros select{padding:10px;border:1px solid #ccc;border-radius:5px;background:white;color:#333;min-width:175px}
.cuadricula{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:18px}
.tarjeta{border:1px solid #e7e2d7;border-radius:9px;overflow:hidden;display:flex;flex-direction:column}
.portada{height:115px;background:#e9e2d2;display:flex;align-items:center;justify-content:center;font-size:48px}
.portada img{width:100%;height:100%;object-fit:contain}
.contenido-tarjeta{padding:17px;display:flex;flex:1;flex-direction:column;gap:10px}
.tematica{color:#37634b;font-size:.85rem;font-weight:bold}
.tarjeta h3{margin:0;font-size:1.1rem;line-height:1.35}
.tarjeta p{margin:0;line-height:1.5;flex:1}
.precio{font-size:1.1rem;color:#254735}
.tarjeta button{width:100%}
.opciones{display:grid;grid-template-columns:repeat(auto-fit,minmax(185px,1fr));gap:10px;margin-top:18px}
.resultado{padding:14px;background:#f1f5ed;border-left:4px solid #254735;border-radius:4px;margin-top:18px}
.seleccion{background:#f7f5ef;padding:12px;border-radius:5px}
.formulario{display:grid;gap:10px;max-width:460px;margin:20px 0}
.formulario input{padding:12px;border:1px solid #bbb;border-radius:5px;font:inherit}
.formulario button{margin-top:6px}
.aviso-error{color:#8c2525}
footer{text-align:center;background:#254735;color:white;padding:15px}
@media(max-width:600px){main{padding:14px}.seccion{padding:18px}.encabezado h1{font-size:1.9rem}}
</style>
