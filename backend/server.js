
require('dotenv').config()

const express = require('express')
const cors = require('cors')
const { Pool } = require('pg')
const bcrypt = require('bcrypt')
const session = require('express-session')
const PgSession = require('connect-pg-simple')(session)

const app = express()
const PORT = process.env.PORT || 3000

app.use(cors({
  origin: ['http://localhost:5173', 'http://127.0.0.1:5173'],
  credentials: true
}))
app.use(express.json({ limit: '20kb' }))

// Conexion a PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
})

// Sesiones persistentes en PostgreSQL (solo desarrollo local HTTP).
if (!process.env.SESSION_SECRET || process.env.SESSION_SECRET.length < 64) {
  throw new Error('SESSION_SECRET debe tener al menos 64 caracteres')
}

app.use(session({
  store: new PgSession({
    pool,
    tableName: 'sesiones',
    createTableIfMissing: true
  }),
  name: 'libreria.sid',
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: false, // Cambiar a true con HTTPS en produccion
    sameSite: 'lax',
    maxAge: 2 * 60 * 60 * 1000
  }
}))

// Las rutas administrativas exigen una sesion iniciada.
async function verificarAdministrador(req, res, next) {
  try {
    const id = req.session?.administrador?.id_usuario
    if (!Number.isSafeInteger(id)) {
      return res.status(401).json({ mensaje: 'Debes iniciar sesion como administrador' })
    }
    const resultado = await pool.query(
      `SELECT id_usuario, nombre, correo, rol, activo
       FROM public.usuarios WHERE id_usuario = $1`,
      [id]
    )
    const usuario = resultado.rows[0]
    if (!usuario || !usuario.activo || usuario.rol !== 'administrador') {
      return res.status(403).json({ mensaje: 'Acceso no autorizado' })
    }
    req.administrador = usuario
    next()
  } catch (error) {
    console.error('Error al verificar administrador:', error.message)
    res.status(500).json({ mensaje: 'No se pudo verificar la sesion' })
  }
}

// Comprobar funcionamiento del servidor
app.get('/', (req, res) => {
  res.json({
    mensaje: 'Servidor de Libreria Cristiana funcionando correctamente'
  })
})

// Iniciar sesion del administrador
app.post('/api/admin/login', async (req, res) => {
  try {
    const { correo, password } = req.body || {}

    if (
      typeof correo !== 'string' ||
      typeof password !== 'string' ||
      !correo.trim() ||
      !password
    ) {
      return res.status(400).json({
        mensaje: 'Debes ingresar correo y contraseña'
      })
    }

    if (correo.length > 150 || password.length > 128) {
      return res.status(400).json({
        mensaje: 'Datos de inicio de sesion invalidos'
      })
    }

    const resultado = await pool.query(
      `SELECT
         id_usuario,
         nombre,
         correo,
         password_hash,
         rol,
         activo
       FROM public.usuarios
       WHERE LOWER(correo) = LOWER($1)
       LIMIT 1`,
      [correo.trim()]
    )

    if (resultado.rows.length === 0) {
      return res.status(401).json({
        mensaje: 'Credenciales incorrectas'
      })
    }

    const usuario = resultado.rows[0]

    if (
      !usuario.activo ||
      usuario.rol !== 'administrador'
    ) {
      return res.status(403).json({
        mensaje: 'Acceso no autorizado'
      })
    }

    const passwordCorrecta = await bcrypt.compare(
      password,
      usuario.password_hash
    )

    if (!passwordCorrecta) {
      return res.status(401).json({
        mensaje: 'Credenciales incorrectas'
      })
    }

    // Renovar identificador para evitar fijacion de sesion.
    await new Promise((resolve, reject) => {
      req.session.regenerate(error => error ? reject(error) : resolve())
    })
    req.session.administrador = { id_usuario: usuario.id_usuario }
    await new Promise((resolve, reject) => {
      req.session.save(error => error ? reject(error) : resolve())
    })

    res.json({
      mensaje: 'Sesion del administrador iniciada correctamente',
      usuario: {
        id_usuario: usuario.id_usuario,
        nombre: usuario.nombre,
        correo: usuario.correo,
        rol: usuario.rol
      }
    })

  } catch (error) {
    console.error('Error de autenticacion:', error.message)

    res.status(500).json({
      mensaje: 'No se pudo verificar el inicio de sesion'
    })
  }
})

// Consultar sesion actual
app.get('/api/admin/sesion', verificarAdministrador, (req, res) => {
  const { id_usuario, nombre, correo, rol } = req.administrador
  res.json({ autenticado: true, usuario: { id_usuario, nombre, correo, rol } })
})

// Cerrar sesion
app.post('/api/admin/logout', (req, res) => {
  req.session.destroy(error => {
    if (error) {
      console.error('Error al cerrar sesion:', error.message)
      return res.status(500).json({ mensaje: 'No se pudo cerrar la sesion' })
    }
    res.clearCookie('libreria.sid', { httpOnly: true, sameSite: 'lax', secure: false })
    res.json({ mensaje: 'Sesion cerrada correctamente' })
  })
})

// Obtener catalogo de libros
app.get('/api/libros', async (req, res) => {
  try {
    const consulta = `
      SELECT
        l.*,
        c.nombre AS tema
      FROM public.libros AS l
      LEFT JOIN public.categorias AS c
        ON l.id_categoria = c.id_categoria
      ORDER BY l.id_libro
    `

    const resultado = await pool.query(consulta)
    res.json(resultado.rows)

  } catch (error) {
    console.error('Error al consultar libros:', error.message)

    res.status(500).json({
      mensaje: 'No se pudieron obtener los libros'
    })
  }
})

// Registrar solicitud de reserva con datos del cliente
app.post('/api/solicitudes-reserva', async (req, res) => {
  try {
    const {
      id_libro,
      nombre_cliente,
      contacto_cliente
    } = req.body || {}

    const libroId = Number(id_libro)

    if (
      !Number.isSafeInteger(libroId) ||
      libroId <= 0 ||
      typeof nombre_cliente !== 'string' ||
      typeof contacto_cliente !== 'string' ||
      !nombre_cliente.trim() ||
      !contacto_cliente.trim()
    ) {
      return res.status(400).json({
        mensaje: 'Debes indicar un libro, nombre y contacto validos'
      })
    }

    const nombre = nombre_cliente.trim()
    const contacto = contacto_cliente.trim()

    if (nombre.length > 150 || contacto.length > 150) {
      return res.status(400).json({
        mensaje: 'El nombre y el contacto no pueden superar 150 caracteres'
      })
    }

    const libro = await pool.query(
      'SELECT id_libro, titulo FROM public.libros WHERE id_libro = $1',
      [libroId]
    )

    if (libro.rows.length === 0) {
      return res.status(404).json({
        mensaje: 'El libro seleccionado no existe'
      })
    }

    const consulta = `
      INSERT INTO public.solicitudes_reserva
        (id_libro, nombre_cliente, contacto_cliente)
      VALUES ($1, $2, $3)
      RETURNING
        id_solicitud,
        id_libro,
        nombre_cliente,
        contacto_cliente,
        fecha_solicitud,
        estado
    `

    const resultado = await pool.query(
      consulta,
      [libroId, nombre, contacto]
    )

    res.status(201).json({
      mensaje: 'Solicitud de reserva registrada correctamente',
      solicitud: resultado.rows[0],
      libro: libro.rows[0].titulo
    })

  } catch (error) {
    console.error('Error al registrar solicitud:', error.message)

    res.status(500).json({
      mensaje: 'No se pudo registrar la solicitud de reserva'
    })
  }
})

// Registrar reserva tecnica con usuario existente
// Ruta conservada para las pruebas anteriores
app.post('/api/reservas', async (req, res) => {
  let cliente
  let transaccionIniciada = false

  try {
    const idUsuario = Number(req.body?.id_usuario)
    const idLibro = Number(req.body?.id_libro)

    if (
      !Number.isSafeInteger(idUsuario) ||
      idUsuario <= 0 ||
      !Number.isSafeInteger(idLibro) ||
      idLibro <= 0
    ) {
      return res.status(400).json({
        mensaje: 'Debes indicar un usuario y un libro validos'
      })
    }

    cliente = await pool.connect()

    await cliente.query('BEGIN')
    transaccionIniciada = true

    const libro = await cliente.query(
      'SELECT id_libro, precio FROM public.libros WHERE id_libro = $1',
      [idLibro]
    )

    if (libro.rows.length === 0) {
      await cliente.query('ROLLBACK')
      transaccionIniciada = false

      return res.status(404).json({
        mensaje: 'El libro no existe'
      })
    }

    const usuario = await cliente.query(
      'SELECT id_usuario FROM public.usuarios WHERE id_usuario = $1',
      [idUsuario]
    )

    if (usuario.rows.length === 0) {
      await cliente.query('ROLLBACK')
      transaccionIniciada = false

      return res.status(404).json({
        mensaje: 'El usuario no existe'
      })
    }

    const reserva = await cliente.query(
      `INSERT INTO public.reservas (id_usuario)
       VALUES ($1)
       RETURNING id_reserva, id_usuario, estado`,
      [idUsuario]
    )

    const idReserva = reserva.rows[0].id_reserva

    await cliente.query(
      `INSERT INTO public.detalle_reservas
         (id_reserva, id_libro, cantidad, precio_unitario)
       VALUES ($1, $2, $3, $4)`,
      [idReserva, idLibro, 1, libro.rows[0].precio]
    )

    await cliente.query('COMMIT')
    transaccionIniciada = false

    res.status(201).json({
      mensaje: 'Reserva de prueba registrada correctamente',
      id_reserva: idReserva,
      id_usuario: idUsuario,
      id_libro: idLibro,
      estado: reserva.rows[0].estado
    })

  } catch (error) {
    if (cliente && transaccionIniciada) {
      try {
        await cliente.query('ROLLBACK')
      } catch (rollbackError) {
        console.error('Error al revertir reserva:', rollbackError.message)
      }
    }

    console.error('Error al registrar reserva:', error.message)

    res.status(500).json({
      mensaje: 'No se pudo registrar la reserva'
    })

  } finally {
    if (cliente) {
      cliente.release()
    }
  }
})

// Consultar todas las solicitudes (administrador)
app.get(
  '/api/admin/solicitudes-reserva',
  verificarAdministrador,
  async (req, res) => {
    try {
      const consulta = `
        SELECT
          s.id_solicitud,
          s.id_libro,
          l.titulo AS libro,
          s.nombre_cliente,
          s.contacto_cliente,
          s.fecha_solicitud,
          s.estado
        FROM public.solicitudes_reserva AS s
        INNER JOIN public.libros AS l
          ON s.id_libro = l.id_libro
        ORDER BY s.fecha_solicitud DESC, s.id_solicitud DESC
      `

      const resultado = await pool.query(consulta)

      res.json(resultado.rows)

    } catch (error) {
      console.error('Error al consultar solicitudes:', error.message)

      res.status(500).json({
        mensaje: 'No se pudieron consultar las solicitudes'
      })
    }
  }
)

// Cambiar estado de una solicitud (administrador)
app.patch(
  '/api/admin/solicitudes-reserva/:id/estado',
  verificarAdministrador,
  async (req, res) => {
    try {
      const idSolicitud = Number(req.params.id)
      const estado = req.body?.estado

      if (
        !Number.isSafeInteger(idSolicitud) ||
        idSolicitud <= 0
      ) {
        return res.status(400).json({
          mensaje: 'El ID de solicitud no es valido'
        })
      }

      const estadosPermitidos = [
        'pendiente',
        'confirmada',
        'cancelada'
      ]

      if (
        typeof estado !== 'string' ||
        !estadosPermitidos.includes(estado)
      ) {
        return res.status(400).json({
          mensaje: 'Estado invalido. Usa pendiente, confirmada o cancelada'
        })
      }

      const consulta = `
        UPDATE public.solicitudes_reserva
        SET estado = $1
        WHERE id_solicitud = $2
        RETURNING
          id_solicitud,
          id_libro,
          nombre_cliente,
          contacto_cliente,
          fecha_solicitud,
          estado
      `

      const resultado = await pool.query(
        consulta,
        [estado, idSolicitud]
      )

      if (resultado.rows.length === 0) {
        return res.status(404).json({
          mensaje: 'La solicitud no existe'
        })
      }

      res.json({
        mensaje: 'Estado actualizado correctamente',
        solicitud: resultado.rows[0]
      })

    } catch (error) {
      console.error('Error al actualizar estado:', error.message)

      res.status(500).json({
        mensaje: 'No se pudo actualizar el estado de la solicitud'
      })
    }
  }
)

// Iniciar servidor
async function iniciarServidor() {
  try {
    await pool.query('SELECT NOW()')

    console.log('Conexion a PostgreSQL realizada correctamente')

    app.listen(PORT, () => {
      console.log(`Servidor funcionando en http://localhost:${PORT}`)
    })

  } catch (error) {
    console.error('Error de conexion a PostgreSQL:', error.message)
    process.exitCode = 1
  }
}

iniciarServidor()
