
require('dotenv').config()

const express = require('express')
const cors = require('cors')
const { Pool } = require('pg')

const app = express()
const PORT = process.env.PORT || 3000

app.use(cors())
app.use(express.json())

// Configuración de la conexión a PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
})

// Comprobar que el servidor está funcionando
app.get('/', (req, res) => {
  res.json({
    mensaje: 'Servidor de Librería Cristiana funcionando correctamente'
  })
})

// Consultar los libros junto con su categoría
app.get('/api/libros', async (req, res) => {
  try {
    const consulta = `
      SELECT
        l.*,
        c.nombre AS tema
      FROM libros AS l
      LEFT JOIN categorias AS c
        ON l.id_categoria = c.id_categoria
      ORDER BY l.id_libro
    `

    const resultado = await pool.query(consulta)

    res.json(resultado.rows)
  } catch (error) {
    console.error('Error al consultar los libros:', error.message)

    res.status(500).json({
      mensaje: 'No se pudieron obtener los libros'
    })
  }
})

// Iniciar servidor y comprobar la conexión
async function iniciarServidor() {
  try {
    await pool.query('SELECT NOW()')

    console.log('Conexión a PostgreSQL realizada correctamente')

    app.listen(PORT, () => {
      console.log(`Servidor funcionando en http://localhost:${PORT}`)
    })
  } catch (error) {
    console.error('Error de conexión a PostgreSQL:', error.message)
  }
}

iniciarServidor()