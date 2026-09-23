-- Creacion de las tablas de resultados de los frentes del Panel de Inteligencia de Negocio

-- auditoria de categoria de vendedores
DROP TABLE EV_AUDITORIA_CATEGORIA_VENDEDOR CASCADE CONSTRAINTS;

CREATE TABLE EV_AUDITORIA_CATEGORIA_VENDEDOR (
  anno               NUMBER(4)  NOT NULL,
  trimestre          NUMBER(1)  NOT NULL,
  id_vendedor        NUMBER(6)  NOT NULL,
  ventas_trimestre   NUMBER(10),
  categoria_asignada CHAR(1),
  categoria_calculada CHAR(1),
  resultado          VARCHAR2(10),
  estado_revision    VARCHAR2(10) DEFAULT 'PENDIENTE' NOT NULL,
  CONSTRAINT pk_ev_audcat PRIMARY KEY (anno, trimestre, id_vendedor),
  CONSTRAINT ck_ev_audcat_estado CHECK (estado_revision IN ('PENDIENTE', 'APROBADO', 'RECHAZADO')),
  CONSTRAINT fk_ev_audcat_vendedor FOREIGN KEY (id_vendedor) REFERENCES EV_VENDEDOR (id_vendedor)
);

--  auditoria de calidad de datos
DROP TABLE EV_AUDITORIA_CALIDAD_DATOS CASCADE CONSTRAINTS;

CREATE TABLE EV_AUDITORIA_CALIDAD_DATOS (
  regla           VARCHAR2(25)  NOT NULL,
  id_registro     NUMBER        NOT NULL,
  tipo            VARCHAR2(6)   NOT NULL,
  tabla_revisar   VARCHAR2(25),
  descripcion     VARCHAR2(100),
  accion_sugerida VARCHAR2(100),
  fecha_auditoria DATE,
  estado_revision VARCHAR2(10) DEFAULT 'PENDIENTE' NOT NULL,
  CONSTRAINT pk_ev_audcal PRIMARY KEY (regla, id_registro),
  CONSTRAINT ck_ev_audcal_tipo CHECK (tipo IN ('ERROR', 'AVISO')),
  CONSTRAINT ck_ev_audcal_estado CHECK (estado_revision IN ('PENDIENTE', 'APROBADO', 'RECHAZADO'))
);