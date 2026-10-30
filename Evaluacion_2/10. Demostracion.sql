-- Evaluacion Parcial 2 - Panel de Inteligencia de Negocio
-- DEMOSTRACION: ejecutar por partes (seleccionar y F5) durante la presentacion.
-- Requiere los scripts 6, 7, 8 y 9 ya ejecutados.

SET SERVEROUTPUT ON;

-- ===============================================================
-- PARTE 1: FUNCIONES USADAS EN SQL
-- ===============================================================
SELECT
    fn_porcentaje_comision(120000) AS "Comision % para 120.000",
    fn_categoria_por_ventas(13500000) AS "Categoria para 13.500.000",
    fn_ventas_sin_vendedor AS "Ventas sin vendedor"
FROM
    dual;


-- ===============================================================
-- PARTE 2: PROCEDIMIENTOS
-- ===============================================================

-- 2.1 calcular comisiones del 2do trimestre 2021 (llama a fn_porcentaje_comision)
BEGIN
    pr_calcular_comisiones(2021, 2);
END;
/

-- 2.2 trimestre invalido: RAISE_APPLICATION_ERROR (ORA-20003)
BEGIN
    pr_calcular_comisiones(2021, 5);
END;
/

-- 2.3 auditar la categoria del 2do trimestre (llama a fn_categoria_por_ventas)
BEGIN
    pr_auditar_categoria(2021, 2);
END;
/

-- 2.4 trimestre sin comisiones calculadas: RAISE_APPLICATION_ERROR (ORA-20005)
BEGIN
    pr_auditar_categoria(2021, 1);
END;
/

-- 2.5 auditoria de calidad de datos, sin parametros (llama a fn_ventas_sin_vendedor)
BEGIN
    pr_auditar_calidad_datos;
END;
/


-- ===============================================================
-- PARTE 3: RESOLVER UNA PROPUESTA + TRIGGER DE HISTORIAL
-- ===============================================================

-- propuestas pendientes
SELECT id_vendedor, ventas_trimestre, categoria_asignada, categoria_calculada, resultado, estado_revision
FROM EV_AUDITORIA_CATEGORIA_VENDEDOR
WHERE anno = 2021 AND trimestre = 2
ORDER BY id_vendedor;

-- 3.1 aprobar la propuesta del vendedor 35 (A -> D), parametro OUT
DECLARE
    v_actualizados NUMBER;
BEGIN
    pr_resolver_revision(p_anno => 2021, p_trimestre => 2, p_id_vendedor => 35,
                         p_estado => 'APROBADO', p_actualizados => v_actualizados);
    DBMS_OUTPUT.PUT_LINE('Propuestas resueltas: ' || v_actualizados);
END;
/

-- 3.2 volver a aprobarla: ya no esta pendiente (SQL%ROWCOUNT = 0)
DECLARE
    v_actualizados NUMBER;
BEGIN
    pr_resolver_revision(p_anno => 2021, p_trimestre => 2, p_id_vendedor => 35,
                         p_estado => 'APROBADO', p_actualizados => v_actualizados);
    DBMS_OUTPUT.PUT_LINE('Propuestas resueltas: ' || v_actualizados);
END;
/

-- 3.3 estado invalido: RAISE_APPLICATION_ERROR (ORA-20001)
DECLARE
    v_actualizados NUMBER;
BEGIN
    pr_resolver_revision(p_anno => 2021, p_trimestre => 2, p_id_vendedor => 50,
                         p_estado => 'OK', p_actualizados => v_actualizados);
END;
/

-- el vendedor 35 quedo en categoria D y el trigger guardo el historial
SELECT id_vendedor, nombres, apellidos, id_categoria FROM EV_VENDEDOR WHERE id_vendedor = 35;
SELECT * FROM EV_HIST_CATEGORIA_VENDEDOR ORDER BY id_historial;
SELECT id_vendedor, resultado, estado_revision FROM EV_AUDITORIA_CATEGORIA_VENDEDOR
WHERE anno = 2021 AND trimestre = 2 AND id_vendedor = 35;


-- ===============================================================
-- PARTE 4: TRIGGERS SOBRE VENTAS Y DETALLE
-- ===============================================================

-- 4.1 venta sin vendedor: la rechaza el trigger de fila BEFORE (ORA-20002)
INSERT INTO EV_VENTA VALUES (999, 1, NULL, SYSDATE);

-- 4.2 venta con vendedor: se acepta
INSERT INTO EV_VENTA VALUES (999, 1, 35, SYSDATE);

-- 4.3 operaciones sobre el detalle: el trigger de sentencia registra cada una
INSERT INTO EV_DETALLEVENTA VALUES (999, 1, 5);
UPDATE EV_DETALLEVENTA SET cantidad = cantidad WHERE id_venta = 1;   -- varias filas, un solo registro
DELETE FROM EV_DETALLEVENTA WHERE id_venta = 999;

SELECT * FROM EV_LOG_OPERACIONES ORDER BY id_log;


-- ===============================================================
-- PARTE 5: DEJAR LA BASE COMO ESTABA
-- Deshace la aprobacion, la venta de prueba y los registros de los
-- triggers (todo quedo en la misma transaccion, sin COMMIT).
-- ===============================================================
ROLLBACK;
