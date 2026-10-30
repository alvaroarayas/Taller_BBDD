-- Evaluacion Parcial 2 - Panel de Inteligencia de Negocio
-- Tablas y secuencias que usan los triggers del proyecto.
-- Ejecutar una sola vez, despues de "1. CreaBase_2_nueva.sql" y "2. Crear tablas resultados.sql".
-- (la primera vez los DROP daran error porque los objetos aun no existen, es normal)

-- historial de cambios de categoria de los vendedores
-- (lo llena el trigger trg_ev_vendedor_hist_categoria)
DROP TABLE EV_HIST_CATEGORIA_VENDEDOR CASCADE CONSTRAINTS;
DROP SEQUENCE SEQ_EV_HIST_CATEGORIA;

CREATE TABLE EV_HIST_CATEGORIA_VENDEDOR (
  id_historial       NUMBER     NOT NULL,
  id_vendedor        NUMBER(6)  NOT NULL,
  categoria_anterior CHAR(1),
  categoria_nueva    CHAR(1),
  fecha_cambio       DATE,
  CONSTRAINT pk_ev_histcat PRIMARY KEY (id_historial),
  CONSTRAINT fk_ev_histcat_vendedor FOREIGN KEY (id_vendedor) REFERENCES EV_VENDEDOR (id_vendedor)
);

CREATE SEQUENCE SEQ_EV_HIST_CATEGORIA START WITH 1 INCREMENT BY 1;

-- registro de operaciones sobre el detalle de ventas
-- (lo llena el trigger trg_ev_detalleventa_log)
DROP TABLE EV_LOG_OPERACIONES CASCADE CONSTRAINTS;
DROP SEQUENCE SEQ_EV_LOG_OPERACIONES;

CREATE TABLE EV_LOG_OPERACIONES (
  id_log          NUMBER       NOT NULL,
  tabla           VARCHAR2(30) NOT NULL,
  operacion       VARCHAR2(10) NOT NULL,
  fecha_operacion DATE,
  CONSTRAINT pk_ev_log PRIMARY KEY (id_log),
  CONSTRAINT ck_ev_log_operacion CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE SEQUENCE SEQ_EV_LOG_OPERACIONES START WITH 1 INCREMENT BY 1;
