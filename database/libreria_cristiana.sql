--
-- PostgreSQL database dump
--

\restrict m64epIwGckfLDmsXstgWdQU1edyd23fMc72ExqLoQ8iqCy47GVu4GCppr8s5TFN

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

-- Started on 2026-11-17 23:03:06

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 220 (class 1259 OID 16400)
-- Name: autores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.autores (
    id_autor integer NOT NULL,
    nombre character varying(150) NOT NULL,
    nacionalidad character varying(100),
    biografia text
);


--
-- TOC entry 219 (class 1259 OID 16399)
-- Name: autores_id_autor_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.autores ALTER COLUMN id_autor ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.autores_id_autor_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 218 (class 1259 OID 16390)
-- Name: categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias (
    id_categoria integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text
);


--
-- TOC entry 217 (class 1259 OID 16389)
-- Name: categorias_id_categoria_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.categorias ALTER COLUMN id_categoria ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categorias_id_categoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 16460)
-- Name: detalle_reservas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detalle_reservas (
    id_detalle integer NOT NULL,
    id_reserva integer NOT NULL,
    id_libro integer NOT NULL,
    cantidad integer DEFAULT 1 NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    CONSTRAINT chk_cantidad_positiva CHECK ((cantidad > 0)),
    CONSTRAINT chk_precio_no_negativo CHECK ((precio_unitario >= (0)::numeric))
);


--
-- TOC entry 227 (class 1259 OID 16459)
-- Name: detalle_reservas_id_detalle_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.detalle_reservas ALTER COLUMN id_detalle ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.detalle_reservas_id_detalle_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 222 (class 1259 OID 16408)
-- Name: libros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.libros (
    id_libro integer NOT NULL,
    titulo character varying(200) NOT NULL,
    isbn character varying(20),
    descripcion text,
    precio numeric(10,2) NOT NULL,
    imagen_url text,
    id_autor integer NOT NULL,
    id_categoria integer NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT libros_precio_check CHECK ((precio >= (0)::numeric))
);


--
-- TOC entry 221 (class 1259 OID 16407)
-- Name: libros_id_libro_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.libros ALTER COLUMN id_libro ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.libros_id_libro_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 16444)
-- Name: reservas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservas (
    id_reserva integer NOT NULL,
    id_usuario integer NOT NULL,
    fecha_reserva timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    fecha_retiro date,
    punto_entrega character varying(200),
    observaciones text,
    CONSTRAINT chk_estado_reserva CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'confirmada'::character varying, 'retirada'::character varying, 'cancelada'::character varying])::text[])))
);


--
-- TOC entry 225 (class 1259 OID 16443)
-- Name: reservas_id_reserva_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.reservas ALTER COLUMN id_reserva ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.reservas_id_reserva_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 231 (class 1259 OID 16494)
-- Name: sesiones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sesiones (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp(6) without time zone NOT NULL
);


--
-- TOC entry 230 (class 1259 OID 16481)
-- Name: solicitudes_reserva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitudes_reserva (
    id_solicitud integer NOT NULL,
    id_libro integer NOT NULL,
    nombre_cliente character varying(150) NOT NULL,
    contacto_cliente character varying(150) NOT NULL,
    fecha_solicitud timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    CONSTRAINT chk_estado_solicitud CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'confirmada'::character varying, 'cancelada'::character varying])::text[])))
);


--
-- TOC entry 229 (class 1259 OID 16480)
-- Name: solicitudes_reserva_id_solicitud_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.solicitudes_reserva ALTER COLUMN id_solicitud ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.solicitudes_reserva_id_solicitud_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 16430)
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido character varying(100) NOT NULL,
    correo character varying(150) NOT NULL,
    password_hash character varying(255) NOT NULL,
    telefono character varying(20),
    rol character varying(20) DEFAULT 'cliente'::character varying NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_rol_usuario CHECK (((rol)::text = ANY ((ARRAY['cliente'::character varying, 'administrador'::character varying])::text[])))
);


--
-- TOC entry 223 (class 1259 OID 16429)
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.usuarios ALTER COLUMN id_usuario ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.usuarios_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 4796 (class 2606 OID 16406)
-- Name: autores autores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.autores
    ADD CONSTRAINT autores_pkey PRIMARY KEY (id_autor);


--
-- TOC entry 4792 (class 2606 OID 16398)
-- Name: categorias categorias_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_nombre_key UNIQUE (nombre);


--
-- TOC entry 4794 (class 2606 OID 16396)
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id_categoria);


--
-- TOC entry 4808 (class 2606 OID 16467)
-- Name: detalle_reservas detalle_reservas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_reservas
    ADD CONSTRAINT detalle_reservas_pkey PRIMARY KEY (id_detalle);


--
-- TOC entry 4798 (class 2606 OID 16418)
-- Name: libros libros_isbn_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libros
    ADD CONSTRAINT libros_isbn_key UNIQUE (isbn);


--
-- TOC entry 4800 (class 2606 OID 16416)
-- Name: libros libros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libros
    ADD CONSTRAINT libros_pkey PRIMARY KEY (id_libro);


--
-- TOC entry 4806 (class 2606 OID 16453)
-- Name: reservas reservas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_pkey PRIMARY KEY (id_reserva);


--
-- TOC entry 4815 (class 2606 OID 16500)
-- Name: sesiones session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sesiones
    ADD CONSTRAINT session_pkey PRIMARY KEY (sid);


--
-- TOC entry 4812 (class 2606 OID 16488)
-- Name: solicitudes_reserva solicitudes_reserva_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_reserva
    ADD CONSTRAINT solicitudes_reserva_pkey PRIMARY KEY (id_solicitud);


--
-- TOC entry 4810 (class 2606 OID 16469)
-- Name: detalle_reservas uq_reserva_libro; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_reservas
    ADD CONSTRAINT uq_reserva_libro UNIQUE (id_reserva, id_libro);


--
-- TOC entry 4802 (class 2606 OID 16442)
-- Name: usuarios usuarios_correo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_correo_key UNIQUE (correo);


--
-- TOC entry 4804 (class 2606 OID 16440)
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- TOC entry 4813 (class 1259 OID 16501)
-- Name: IDX_session_expire; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IDX_session_expire" ON public.sesiones USING btree (expire);


--
-- TOC entry 4819 (class 2606 OID 16475)
-- Name: detalle_reservas fk_detalle_libro; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_reservas
    ADD CONSTRAINT fk_detalle_libro FOREIGN KEY (id_libro) REFERENCES public.libros(id_libro);


--
-- TOC entry 4820 (class 2606 OID 16470)
-- Name: detalle_reservas fk_detalle_reserva; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_reservas
    ADD CONSTRAINT fk_detalle_reserva FOREIGN KEY (id_reserva) REFERENCES public.reservas(id_reserva);


--
-- TOC entry 4816 (class 2606 OID 16419)
-- Name: libros fk_libros_autores; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libros
    ADD CONSTRAINT fk_libros_autores FOREIGN KEY (id_autor) REFERENCES public.autores(id_autor);


--
-- TOC entry 4817 (class 2606 OID 16424)
-- Name: libros fk_libros_categorias; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libros
    ADD CONSTRAINT fk_libros_categorias FOREIGN KEY (id_categoria) REFERENCES public.categorias(id_categoria);


--
-- TOC entry 4818 (class 2606 OID 16454)
-- Name: reservas fk_reservas_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT fk_reservas_usuarios FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- TOC entry 4821 (class 2606 OID 16489)
-- Name: solicitudes_reserva fk_solicitud_libro; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_reserva
    ADD CONSTRAINT fk_solicitud_libro FOREIGN KEY (id_libro) REFERENCES public.libros(id_libro);


-- Completed on 2026-11-17 23:03:06

--
-- PostgreSQL database dump complete
--

\unrestrict m64epIwGckfLDmsXstgWdQU1edyd23fMc72ExqLoQ8iqCy47GVu4GCppr8s5TFN

