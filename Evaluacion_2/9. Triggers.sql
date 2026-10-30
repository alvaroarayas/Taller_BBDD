-- Evaluacion Parcial 2 - Panel de Inteligencia de Negocio
-- TRIGGERS
-- Requiere: "6. Crear tablas y secuencias EP2.sql" ya ejecutado.
-- Nota: si se vuelve a ejecutar "1. CreaBase_2_nueva.sql", las tablas se
-- eliminan junto con sus triggers y hay que volver a ejecutar este script.

-- ---------------------------------------------------------------
-- TRIGGER A NIVEL DE FILA (BEFORE): validar venta con vendedor
-- Regla de negocio: toda venta debe tener un vendedor asignado.
-- La auditoria de calidad detecta las ventas antiguas sin vendedor;
-- este trigger impide que se registren nuevas.
-- ---------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ev_venta_valida_vendedor BEFORE
    INSERT OR UPDATE ON EV_VENTA
    FOR EACH ROW
BEGIN
    IF :new.id_vendedor IS NULL THEN
        raise_application_error(-20002, 'Toda venta debe tener un vendedor asignado');
    END IF;
END;
/

-- ---------------------------------------------------------------
-- TRIGGER A NIVEL DE FILA (AFTER): historial de categoria
-- Cada vez que cambia la categoria de un vendedor, guarda la
-- categoria anterior y la nueva en EV_HIST_CATEGORIA_VENDEDOR.
-- Se activa, por ejemplo, cuando pr_resolver_revision aprueba
-- una propuesta de la auditoria.
-- ---------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ev_vendedor_hist_categoria AFTER
    UPDATE OF id_categoria ON EV_VENDEDOR
    FOR EACH ROW
BEGIN
    -- solo se registra si la categoria realmente cambio
    IF :old.id_categoria <> :new.id_categoria THEN
        INSERT INTO EV_HIST_CATEGORIA_VENDEDOR VALUES (
            SEQ_EV_HIST_CATEGORIA.NEXTVAL,
            :old.id_vendedor,
            :old.id_categoria,
            :new.id_categoria,
            sysdate
        );
    END IF;
END;
/

-- ---------------------------------------------------------------
-- TRIGGER A NIVEL DE SENTENCIA (AFTER): log del detalle de ventas
-- Registra cada INSERT, UPDATE o DELETE sobre EV_DETALLEVENTA.
-- Un cambio en el detalle cambia los totales vendidos, por lo que
-- este registro indica que las comisiones deben recalcularse.
-- Se ejecuta una sola vez por sentencia, sin importar cuantas
-- filas afecte.
-- ---------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ev_detalleventa_log AFTER
    INSERT OR UPDATE OR DELETE ON EV_DETALLEVENTA
BEGIN
    IF inserting THEN
        INSERT INTO EV_LOG_OPERACIONES VALUES (
            SEQ_EV_LOG_OPERACIONES.NEXTVAL,
            'EV_DETALLEVENTA',
            'INSERT',
            sysdate
        );

    ELSIF updating THEN
        INSERT INTO EV_LOG_OPERACIONES VALUES (
            SEQ_EV_LOG_OPERACIONES.NEXTVAL,
            'EV_DETALLEVENTA',
            'UPDATE',
            sysdate
        );

    ELSIF deleting THEN
        INSERT INTO EV_LOG_OPERACIONES VALUES (
            SEQ_EV_LOG_OPERACIONES.NEXTVAL,
            'EV_DETALLEVENTA',
            'DELETE',
            sysdate
        );

    END IF;
END;
/
