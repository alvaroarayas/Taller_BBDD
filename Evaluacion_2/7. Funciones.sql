-- Evaluacion Parcial 2 - Panel de Inteligencia de Negocio
-- FUNCIONES ALMACENADAS
-- Se crean antes que los procedimientos, porque los procedimientos las llaman.

SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------
-- FUNCION CON PARAMETROS: porcentaje de comision segun el tramo
-- Recibe el total vendido en el mes y retorna el porcentaje del
-- tramo en EV_COMISIONVENDEDOR. Si el total no cae en ningun
-- tramo retorna NULL (el procedimiento decide que hacer).
-- La usa: pr_calcular_comisiones
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_porcentaje_comision (
    p_total_ventas IN EV_COMISION_VENTA_VENDEDOR.total_ventas%TYPE
) RETURN NUMBER IS
    v_porcentaje EV_COMISIONVENDEDOR.comision%TYPE;
BEGIN
    SELECT
        comision
    INTO v_porcentaje
    FROM
        EV_COMISIONVENDEDOR
    WHERE
        p_total_ventas BETWEEN ventaminima AND ventamaxima;

    RETURN v_porcentaje;
EXCEPTION
    WHEN no_data_found THEN
        RETURN NULL;
END;
/

-- ---------------------------------------------------------------
-- FUNCION CON PARAMETROS: categoria que corresponde a las ventas
-- Recibe las ventas de un trimestre y retorna la categoria segun
-- los tramos de 3 millones definidos por el negocio.
-- La usa: pr_auditar_categoria (y se puede usar en un SELECT)
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_categoria_por_ventas (
    p_ventas IN NUMBER
) RETURN VARCHAR2 IS
BEGIN
    IF p_ventas >= 15000000 THEN
        RETURN 'A';   -- desde 15.000.000
    ELSIF p_ventas >= 12000000 THEN
        RETURN 'B';   -- 12.000.000 hasta 14.999.999
    ELSIF p_ventas >= 9000000 THEN
        RETURN 'C';   -- 9.000.000 hasta 11.999.999
    ELSIF p_ventas >= 6000000 THEN
        RETURN 'D';   -- 6.000.000 hasta 8.999.999
    ELSE
        RETURN 'E';   -- hasta 5.999.999
    END IF;
END;
/

-- ---------------------------------------------------------------
-- FUNCION SIN PARAMETROS: monto de ventas sin vendedor
-- Retorna el monto total de las ventas que no tienen vendedor
-- asignado y que por eso quedan fuera del calculo de comisiones.
-- SUM siempre retorna una fila (no produce NO_DATA_FOUND); si no
-- hay ventas sin vendedor retorna NULL, por eso se usa NVL.
-- La usa: pr_auditar_calidad_datos
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ventas_sin_vendedor RETURN NUMBER IS
    v_monto NUMBER;
BEGIN
    SELECT
        NVL(SUM(a.precio * d.cantidad), 0)
    INTO v_monto
    FROM
        EV_VENTA v
        JOIN EV_DETALLEVENTA d ON (v.id_venta = d.id_venta)
        JOIN EV_ARTICULO a ON (d.id_articulo = a.id_articulo)
    WHERE
        v.id_vendedor IS NULL;

    RETURN v_monto;
END;
/


-- ===============================================================
-- PRUEBAS DE LAS FUNCIONES DESDE SQL
-- ===============================================================

-- porcentaje de comision: un total dentro de un tramo y uno fuera de todos
SELECT
    fn_porcentaje_comision(120000)   AS "Tramo 120.000",
    fn_porcentaje_comision(99999999) AS "Fuera de tramo"
FROM
    dual;

-- categoria que corresponde a cada vendedor segun sus ventas del 2do trimestre 2021
SELECT
    v.id_vendedor,
    v.nombres || ' ' || v.apellidos                        AS vendedor,
    v.id_categoria                                         AS categoria_asignada,
    SUM(a.precio * d.cantidad)                             AS ventas_trimestre,
    fn_categoria_por_ventas(SUM(a.precio * d.cantidad))    AS categoria_calculada
FROM
    EV_VENDEDOR v
    JOIN EV_VENTA vt ON (v.id_vendedor = vt.id_vendedor)
    JOIN EV_DETALLEVENTA d ON (vt.id_venta = d.id_venta)
    JOIN EV_ARTICULO a ON (d.id_articulo = a.id_articulo)
WHERE
    EXTRACT(YEAR FROM vt.fecha_venta) = 2021
    AND EXTRACT(MONTH FROM vt.fecha_venta) BETWEEN 4 AND 6
GROUP BY
    v.id_vendedor,
    v.nombres,
    v.apellidos,
    v.id_categoria
ORDER BY
    ventas_trimestre DESC;

-- monto de ventas sin vendedor
SELECT
    fn_ventas_sin_vendedor AS "Ventas sin vendedor"
FROM
    dual;
