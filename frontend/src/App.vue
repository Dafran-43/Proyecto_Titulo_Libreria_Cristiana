
<script setup>
import { computed, onMounted, ref } from 'vue'

const API_BASE = 'http://localhost:3000'
const API_URL = `${API_BASE}/api/libros`
const API_SOLICITUDES = `${API_BASE}/api/solicitudes-reserva`
const API_ADMIN = `${API_BASE}/api/admin`

// Catálogo
const libros = ref([])
const busqueda = ref('')
const terminoAplicado = ref('')
const temaSeleccionado = ref('Todos')
const cargando = ref(true)
const error = ref('')

// Reservas de clientes
const libroReserva = ref(null)
const nombreReserva = ref('')
const contactoReserva = ref('')
const mensajeReserva = ref('')
const errorReserva = ref(false)
const enviandoReserva = ref(false)

// Recomendaciones
const recomendacion = ref('')

// Administración
const correoAdmin = ref('')
const passwordAdmin = ref('')
const administrador = ref(null)
const solicitudesAdmin = ref([])
const cargandoAdmin = ref(false)
const procesandoId = ref(null)
const mensajeAdmin = ref('')
const errorAdmin = ref(false)
const verificandoSesion = ref(true)

const temas = computed(() => [
  'Todos',
  ...new Set(libros.value.map(libro => libro.tema).filter(Boolean))
])

const librosFiltrados = computed(() => {
  const termino = terminoAplicado.value.toLocaleLowerCase('es').trim()

  return libros.value.filter(libro => {
    const coincideTema =
      temaSeleccionado.value === 'Todos' ||
      libro.tema === temaSeleccionado.value

    const texto = `${libro.titulo} ${libro.tema} ${libro.descripcion} ${libro.autor}`
      .toLocaleLowerCase('es')

    return coincideTema && (!termino || texto.includes(termino))
  })
})

const solicitudesPendientes = computed(() =>
  solicitudesAdmin.value.filter(s => s.estado === 'pendiente').length
)

function formatoPrecio(precio) {
  return new Intl.NumberFormat('es-CL', {
    style: 'currency',
    currency: 'CLP',
    maximumFractionDigits: 0
  }).format(precio)
}

function formatoFecha(fecha) {
  if (!fecha) return 'Sin fecha'

  const valor = new Date(fecha)
  if (Number.isNaN(valor.getTime())) return fecha

  return valor.toLocaleString('es-CL', {
    dateStyle: 'short',
    timeStyle: 'short'
  })
}

async function leerRespuesta(respuesta) {
  const datos = await respuesta.json().catch(() => ({}))

  if (!respuesta.ok) {
    throw new Error(datos.mensaje || `Error HTTP ${respuesta.status}`)
  }

  return datos
}

// Cargar libros desde PostgreSQL
async function cargarLibros() {
  cargando.value = true
  error.value = ''

  try {
    const respuesta = await fetch(API_URL)
    const datos = await leerRespuesta(respuesta)

    if (!Array.isArray(datos)) {
      throw new Error('Formato de catálogo inesperado')
    }

    libros.value = datos.map(libro => ({
      id: libro.id_libro,
      titulo: libro.titulo,
      precio: Number(libro.precio),
      descripcion: libro.descripcion || '',
      tema: libro.tema || libro.nombre_categoria || libro.categoria || '',
      autor: libro.autor || libro.nombre_autor || '',
      imagen: libro.imagen_url || ''
    }))
  } catch (e) {
    console.error(e)
    error.value = 'No se pudo cargar el catálogo. Comprueba que el servidor esté encendido.'
  } finally {
    cargando.value = false
  }
}

function buscarLibros() {
  terminoAplicado.value = busqueda.value

  document.getElementById('catalogo')?.scrollIntoView({
    behavior: 'smooth'
  })
}

// Recomendaciones por reglas
function recomendar(tema) {
  const reglas = {
    orar: ['oración', 'orar'],
    fe: ['fe', 'cristianismo'],
    crecer: ['vida cristiana', 'conocimiento de dios', 'santidad'],
    misiones: ['misiones', 'misionera']
  }

  const palabras = reglas[tema] || []

  const encontrado = libros.value.find(libro => {
    const texto = `${libro.titulo} ${libro.tema} ${libro.descripcion}`
      .toLocaleLowerCase('es')

    return palabras.some(palabra => texto.includes(palabra))
  })

  recomendacion.value = encontrado
    ? `Te recomendamos «${encontrado.titulo}». Puedes encontrarlo en nuestro catálogo.`
    : 'Por el momento no encontramos un libro para ese interés.'
}

// Solicitudes de reserva
function elegirReserva(libro) {
  libroReserva.value = libro
  mensajeReserva.value = ''
  errorReserva.value = false

  document.getElementById('reservas')?.scrollIntoView({
    behavior: 'smooth'
  })
}

async function enviarInteres() {
  if (enviandoReserva.value) return

  errorReserva.value = false

  if (
    !libroReserva.value ||
    !nombreReserva.value.trim() ||
    !contactoReserva.value.trim()
  ) {
    mensajeReserva.value = 'Selecciona un libro y completa tus datos.'
    errorReserva.value = true
    return
  }

  enviandoReserva.value = true
  mensajeReserva.value = ''

  try {
    const respuesta = await fetch(API_SOLICITUDES, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        id_libro: libroReserva.value.id,
        nombre_cliente: nombreReserva.value.trim(),
        contacto_cliente: contactoReserva.value.trim()
      })
    })

    const datos = await leerRespuesta(respuesta)

    const numero = datos.solicitud?.id_solicitud
    const estado = datos.solicitud?.estado || 'pendiente'

    mensajeReserva.value =
      `Solicitud N.º ${numero ?? 'registrada'} guardada correctamente. Estado: ${estado}.`

    nombreReserva.value = ''
    contactoReserva.value = ''
  } catch (e) {
    console.error(e)
    errorReserva.value = true
    mensajeReserva.value = `No se pudo registrar la reserva: ${e.message}`
  } finally {
    enviandoReserva.value = false
  }
}

// Consultar sesión del administrador
async function verificarSesion() {
  verificandoSesion.value = true

  try {
    const respuesta = await fetch(`${API_ADMIN}/sesion`, {
      credentials: 'include'
    })

    if (respuesta.status === 401) {
      administrador.value = null
      return
    }

    const datos = await leerRespuesta(respuesta)

    administrador.value = datos.usuario || null

    if (administrador.value) {
      await cargarSolicitudes()
    }
  } catch (e) {
    console.error('No se pudo verificar la sesión:', e)
    administrador.value = null
  } finally {
    verificandoSesion.value = false
  }
}

// Iniciar sesión
async function iniciarSesionAdmin() {
  mensajeAdmin.value = ''
  errorAdmin.value = false

  if (!correoAdmin.value.trim() || !passwordAdmin.value) {
    mensajeAdmin.value = 'Ingresa tu correo y contraseña.'
    errorAdmin.value = true
    return
  }

  cargandoAdmin.value = true

  try {
    const respuesta = await fetch(`${API_ADMIN}/login`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        correo: correoAdmin.value.trim(),
        password: passwordAdmin.value
      })
    })

    const datos = await leerRespuesta(respuesta)

    administrador.value = datos.usuario || null
    passwordAdmin.value = ''

    if (!administrador.value) {
      throw new Error('No se recibieron los datos del administrador.')
    }

    mensajeAdmin.value = 'Sesión iniciada correctamente.'

    await cargarSolicitudes()
  } catch (e) {
    administrador.value = null
    errorAdmin.value = true
    mensajeAdmin.value = e.message
  } finally {
    cargandoAdmin.value = false
  }
}

// Consultar reservas
async function cargarSolicitudes() {
  cargandoAdmin.value = true

  try {
    const respuesta = await fetch(`${API_ADMIN}/solicitudes-reserva`, {
      credentials: 'include'
    })

    if (respuesta.status === 401) {
      administrador.value = null
      solicitudesAdmin.value = []
      throw new Error('La sesión ha expirado. Inicia sesión nuevamente.')
    }

    const datos = await leerRespuesta(respuesta)

    if (!Array.isArray(datos)) {
      throw new Error('Formato de solicitudes inesperado.')
    }

    solicitudesAdmin.value = datos
  } catch (e) {
    console.error(e)
    errorAdmin.value = true
    mensajeAdmin.value = e.message
  } finally {
    cargandoAdmin.value = false
  }
}

// Cambiar estado de una reserva
async function cambiarEstado(solicitud, nuevoEstado) {
  if (procesandoId.value !== null) return

  const confirmado = window.confirm(
    `¿Deseas cambiar la solicitud N.º ${solicitud.id_solicitud} a "${nuevoEstado}"?`
  )

  if (!confirmado) return

  procesandoId.value = solicitud.id_solicitud
  mensajeAdmin.value = ''
  errorAdmin.value = false

  try {
    const respuesta = await fetch(
      `${API_ADMIN}/solicitudes-reserva/${solicitud.id_solicitud}/estado`,
      {
        method: 'PATCH',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          estado: nuevoEstado
        })
      }
    )

    await leerRespuesta(respuesta)

    await cargarSolicitudes()

    mensajeAdmin.value =
      `Solicitud N.º ${solicitud.id_solicitud} actualizada a "${nuevoEstado}".`
  } catch (e) {
    errorAdmin.value = true
    mensajeAdmin.value = e.message
  } finally {
    procesandoId.value = null
  }
}

// Cerrar sesión
async function cerrarSesionAdmin() {
  mensajeAdmin.value = ''
  errorAdmin.value = false

  try {
    const respuesta = await fetch(`${API_ADMIN}/logout`, {
      method: 'POST',
      credentials: 'include'
    })

    await leerRespuesta(respuesta)

    administrador.value = null
    solicitudesAdmin.value = []
    correoAdmin.value = ''
    passwordAdmin.value = ''

    mensajeAdmin.value = 'Sesión cerrada correctamente.'
  } catch (e) {
    errorAdmin.value = true
    mensajeAdmin.value = `No se pudo cerrar la sesión: ${e.message}`
  }
}

onMounted(() => {
  cargarLibros()
  verificarSesion()
})
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
      <a href="#administracion">Administración</a>
    </nav>

    <main id="inicio">
      <section class="bienvenida">
        <h2>Bienvenidos a nuestra Librería Cristiana</h2>
        <p>
          Descubre libros cristianos, explora diferentes temáticas
          y encuentra lecturas para tu crecimiento espiritual.
        </p>

        <form class="buscador" @submit.prevent="buscarLibros">
          <input
            v-model="busqueda"
            type="search"
            placeholder="Buscar por título, autor o temática"
            aria-label="Buscar libros"
          />
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
            <option v-for="tema in temas" :key="tema" :value="tema">
              {{ tema }}
            </option>
          </select>
        </div>

        <p v-if="cargando">Cargando libros desde PostgreSQL...</p>

        <div v-else-if="error" class="aviso-error" role="alert">
          <p>{{ error }}</p>
          <button type="button" @click="cargarLibros">Reintentar</button>
        </div>

        <p v-else-if="librosFiltrados.length === 0">
          No se encontraron libros.
        </p>

        <div v-else class="cuadricula">
          <article
            v-for="libro in librosFiltrados"
            :key="libro.id"
            class="tarjeta"
          >
            <div class="portada">
              <img
                v-if="libro.imagen"
                :src="libro.imagen"
                :alt="`Portada de ${libro.titulo}`"
              />
              <span v-else aria-hidden="true">📖</span>
            </div>

            <div class="contenido-tarjeta">
              <span class="tematica">{{ libro.tema }}</span>
              <h3>{{ libro.titulo }}</h3>
              <p v-if="libro.autor"><strong>Autor:</strong> {{ libro.autor }}</p>
              <p>{{ libro.descripcion }}</p>
              <strong class="precio">{{ formatoPrecio(libro.precio) }}</strong>
              <button type="button" @click="elegirReserva(libro)">
                Me interesa reservar
              </button>
            </div>
          </article>
        </div>
      </section>

      <section id="recomendaciones" class="seccion">
        <h2>Recomendaciones de lectura</h2>
        <p>
          Selecciona un interés para recibir una recomendación
          basada en los libros disponibles.
        </p>

        <div class="opciones">
          <button type="button" @click="recomendar('orar')">
            Quiero aprender a orar
          </button>
          <button type="button" @click="recomendar('fe')">
            Quiero fortalecer mi fe
          </button>
          <button type="button" @click="recomendar('crecer')">
            Quiero crecer espiritualmente
          </button>
          <button type="button" @click="recomendar('misiones')">
            Me interesan las misiones
          </button>
        </div>

        <p v-if="recomendacion" class="resultado" role="status">
          {{ recomendacion }}
        </p>
      </section>

      <section id="reservas" class="seccion">
        <h2>Reserva de libros</h2>
        <p>Selecciona un libro y completa tus datos para solicitar una reserva.</p>

        <p v-if="libroReserva" class="seleccion">
          Libro seleccionado: <strong>{{ libroReserva.titulo }}</strong>
        </p>
        <p v-else>Primero selecciona un libro del catálogo.</p>

        <form class="formulario" @submit.prevent="enviarInteres">
          <label for="nombre">Nombre</label>
          <input
            id="nombre"
            v-model="nombreReserva"
            type="text"
            placeholder="Tu nombre"
            required
          />

          <label for="contacto">Correo electrónico o teléfono</label>
          <input
            id="contacto"
            v-model="contactoReserva"
            type="text"
            placeholder="Tu contacto"
            required
          />

          <button
            type="submit"
            :disabled="!libroReserva || enviandoReserva"
          >
            {{ enviandoReserva ? 'Registrando...' : 'Enviar solicitud de reserva' }}
          </button>
        </form>

        <p
          v-if="mensajeReserva"
          :class="errorReserva ? 'aviso-error resultado' : 'resultado'"
          role="status"
        >
          {{ mensajeReserva }}
        </p>

        <small>
          Versión de prueba: las solicitudes se guardan en PostgreSQL.
          La reserva no modifica automáticamente el inventario.
          Utiliza datos ficticios durante las pruebas.
        </small>
      </section>

      <!-- Panel administrativo -->
      <section id="administracion" class="seccion">
        <h2>Panel de administración</h2>

        <p v-if="verificandoSesion">
          Verificando sesión del administrador...
        </p>

        <template v-else-if="!administrador">
          <p>
            Acceso exclusivo para el administrador de la Librería Cristiana.
          </p>

          <form class="formulario" @submit.prevent="iniciarSesionAdmin">
            <label for="correo-admin">Correo del administrador</label>
            <input
              id="correo-admin"
              v-model="correoAdmin"
              type="email"
              autocomplete="username"
              placeholder="Correo electrónico"
              required
            />

            <label for="password-admin">Contraseña</label>
            <input
              id="password-admin"
              v-model="passwordAdmin"
              type="password"
              autocomplete="current-password"
              placeholder="Contraseña"
              required
            />

            <button type="submit" :disabled="cargandoAdmin">
              {{ cargandoAdmin ? 'Ingresando...' : 'Iniciar sesión' }}
            </button>
          </form>
        </template>

        <template v-else>
          <div class="barra-admin">
            <div>
              <p>
                Bienvenido,
                <strong>{{ administrador.nombre }}</strong>
              </p>
              <small>Rol: {{ administrador.rol }}</small>
            </div>

            <button
              type="button"
              class="boton-secundario"
              @click="cerrarSesionAdmin"
            >
              Cerrar sesión
            </button>
          </div>

          <div class="resumen-admin">
            <div class="dato-admin">
              <strong>{{ solicitudesAdmin.length }}</strong>
              <span>Solicitudes totales</span>
            </div>

            <div class="dato-admin">
              <strong>{{ solicitudesPendientes }}</strong>
              <span>Solicitudes pendientes</span>
            </div>
          </div>

          <div class="barra-admin">
            <h3>Solicitudes de reserva</h3>
            <button
              type="button"
              :disabled="cargandoAdmin"
              @click="cargarSolicitudes"
            >
              {{ cargandoAdmin ? 'Actualizando...' : 'Actualizar lista' }}
            </button>
          </div>

          <p v-if="cargandoAdmin">Consultando solicitudes...</p>

          <p v-else-if="solicitudesAdmin.length === 0">
            No hay solicitudes registradas.
          </p>

          <div v-else class="tabla-contenedor">
            <table class="tabla-reservas">
              <thead>
                <tr>
                  <th>N.º</th>
                  <th>Libro</th>
                  <th>Cliente</th>
                  <th>Contacto</th>
                  <th>Fecha</th>
                  <th>Estado</th>
                  <th>Acciones</th>
                </tr>
              </thead>

              <tbody>
                <tr
                  v-for="solicitud in solicitudesAdmin"
                  :key="solicitud.id_solicitud"
                >
                  <td>{{ solicitud.id_solicitud }}</td>
                  <td>{{ solicitud.libro || solicitud.id_libro }}</td>
                  <td>{{ solicitud.nombre_cliente }}</td>
                  <td>{{ solicitud.contacto_cliente }}</td>
                  <td>{{ formatoFecha(solicitud.fecha_solicitud) }}</td>

                  <td>
                    <span
                      class="estado"
                      :class="`estado-${solicitud.estado}`"
                    >
                      {{ solicitud.estado }}
                    </span>
                  </td>

                  <td>
                    <div class="acciones">
                      <button
                        v-if="solicitud.estado === 'pendiente'"
                        type="button"
                        :disabled="procesandoId !== null"
                        @click="cambiarEstado(solicitud, 'confirmada')"
                      >
                        Confirmar
                      </button>

                      <button
                        v-if="solicitud.estado === 'pendiente'"
                        type="button"
                        class="boton-cancelar"
                        :disabled="procesandoId !== null"
                        @click="cambiarEstado(solicitud, 'cancelada')"
                      >
                        Cancelar
                      </button>

                      <span v-if="solicitud.estado !== 'pendiente'">
                        Gestionada
                      </span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>

        <p
          v-if="mensajeAdmin"
          :class="errorAdmin ? 'aviso-error resultado' : 'resultado'"
          role="status"
        >
          {{ mensajeAdmin }}
        </p>
      </section>
    </main>

    <footer>
      <p>Proyecto de Título - Librería Cristiana</p>
    </footer>
  </div>
</template>

<style scoped>
.pagina {
  min-height: 100vh;
  background: #f7f5ef;
  color: #333;
  font-family: Arial, sans-serif;
}

.encabezado {
  background: #254735;
  color: white;
  text-align: center;
  padding: 35px 20px;
}

.encabezado h1 {
  margin: 0 0 12px;
  font-size: 2.3rem;
}

.encabezado p {
  margin: 0;
}

.menu {
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
  gap: 25px;
  background: #d8c7a0;
  padding: 15px;
}

.menu a {
  color: #254735;
  text-decoration: none;
  font-weight: bold;
}

.menu a:hover {
  text-decoration: underline;
}

main {
  max-width: 1100px;
  margin: auto;
  padding: 25px;
}

.bienvenida {
  text-align: center;
  padding: 35px 15px;
}

h2, h3 {
  color: #254735;
}

.bienvenida p {
  line-height: 1.7;
  max-width: 850px;
  margin: 18px auto;
}

.buscador {
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 25px;
}

.buscador input {
  width: 350px;
  max-width: 100%;
  padding: 12px;
  border: 1px solid #bbb;
  border-radius: 5px;
  background: white;
  color: #333;
}

button {
  padding: 12px 18px;
  background: #254735;
  color: white;
  border: 0;
  border-radius: 5px;
  cursor: pointer;
  font: inherit;
}

button:hover {
  background: #37634b;
}

button:disabled {
  opacity: .55;
  cursor: not-allowed;
}

.seccion {
  background: white;
  padding: 26px;
  margin-bottom: 22px;
  border-radius: 10px;
  scroll-margin-top: 15px;
}

.titulo-seccion {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 15px;
  flex-wrap: wrap;
}

.titulo-seccion h2 {
  margin: 0 0 12px;
}

.filtros {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  margin: 16px 0 22px;
}

.filtros select {
  padding: 10px;
  border: 1px solid #ccc;
  border-radius: 5px;
  background: white;
  color: #333;
  min-width: 175px;
}

.cuadricula {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
  gap: 18px;
}

.tarjeta {
  border: 1px solid #e7e2d7;
  border-radius: 9px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.portada {
  height: 115px;
  background: #e9e2d2;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 48px;
}

.portada img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.contenido-tarjeta {
  padding: 17px;
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 10px;
}

.tematica {
  color: #37634b;
  font-size: .85rem;
  font-weight: bold;
}

.tarjeta h3 {
  margin: 0;
  font-size: 1.1rem;
  line-height: 1.35;
}

.tarjeta p {
  margin: 0;
  line-height: 1.5;
  flex: 1;
}

.precio {
  font-size: 1.1rem;
  color: #254735;
}

.tarjeta button {
  width: 100%;
}

.opciones {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(185px, 1fr));
  gap: 10px;
  margin-top: 18px;
}

.resultado {
  padding: 14px;
  background: #f1f5ed;
  border-left: 4px solid #254735;
  border-radius: 4px;
  margin-top: 18px;
}

.seleccion {
  background: #f7f5ef;
  padding: 12px;
  border-radius: 5px;
}

.formulario {
  display: grid;
  gap: 10px;
  max-width: 460px;
  margin: 20px 0;
}

.formulario input {
  padding: 12px;
  border: 1px solid #bbb;
  border-radius: 5px;
  font: inherit;
}

.formulario button {
  margin-top: 6px;
}

.aviso-error {
  color: #8c2525;
}

/* Administración */
.barra-admin {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 15px;
  margin: 20px 0;
}

.barra-admin h3 {
  margin: 0;
}

.boton-secundario {
  background: #666;
}

.boton-cancelar {
  background: #9d3535;
}

.boton-cancelar:hover {
  background: #7b2929;
}

.resumen-admin {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 15px;
  margin: 20px 0;
}

.dato-admin {
  padding: 20px;
  background: #f1f5ed;
  border: 1px solid #dce7d7;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.dato-admin strong {
  font-size: 2rem;
  color: #254735;
}

.tabla-contenedor {
  overflow-x: auto;
  margin-top: 20px;
}

.tabla-reservas {
  width: 100%;
  border-collapse: collapse;
  min-width: 850px;
  font-size: .9rem;
}

.tabla-reservas th,
.tabla-reservas td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #ddd;
  vertical-align: middle;
}

.tabla-reservas th {
  background: #254735;
  color: white;
}

.tabla-reservas tbody tr:hover {
  background: #f7f5ef;
}

.estado {
  display: inline-block;
  padding: 6px 10px;
  border-radius: 20px;
  font-weight: bold;
  text-transform: capitalize;
}

.estado-pendiente {
  background: #fff0c2;
  color: #765500;
}

.estado-confirmada {
  background: #d9efdf;
  color: #205b30;
}

.estado-cancelada {
  background: #f5d9d9;
  color: #8c2525;
}

.acciones {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.acciones button {
  padding: 8px 12px;
  font-size: .85rem;
}

footer {
  text-align: center;
  background: #254735;
  color: white;
  padding: 15px;
}

@media (max-width: 600px) {
  main {
    padding: 14px;
  }

  .seccion {
    padding: 18px;
  }

  .encabezado h1 {
    font-size: 1.9rem;
  }
}
</style>
