SET SERVEROUTPUT ON;

-- auditoria de vendedores
-- Llena la tabla EV_COMISION_VENTA_VENDEDOR (anno, mes, vendedor, total de ventas, monto de comision)
-- aplicando los tramos de la tabla EV_COMISIONVENDEDOR sobre las ventas netas de cada vendedor por mes.
-- Ademas de cargar la tabla, muestra por pantalla el resultado de cada vendedor por mes.

DECLARE
  -- VARRAY con lista de meses a procesar (abril, mayo y junio) y el año de las ventas
  TYPE Meses_Lista IS VARRAY(3) OF NUMBER;
  v_meses Meses_Lista := Meses_Lista(4, 5, 6);
  v_anno NUMBER := 2021;


  TYPE Comision_rec IS RECORD (
    anno           EV_COMISION_VENTA_VENDEDOR.anno%TYPE,
    mes            EV_COMISION_VENTA_VENDEDOR.mes%TYPE,
    id_vendedor    EV_COMISION_VENTA_VENDEDOR.id_vendedor%TYPE,
    total_ventas   EV_COMISION_VENTA_VENDEDOR.total_ventas%TYPE,
    porcentaje     NUMBER,
    monto_comision EV_COMISION_VENTA_VENDEDOR.monto_comision%TYPE
  );
  v_comision Comision_rec;

  -- CURSOR SIN PARAMETROS: todos los vendedores
  CURSOR cur_vendedores IS
    SELECT id_vendedor AS id_vendedor,
           nombres || ' ' || apellidos AS nombre
    FROM EV_VENDEDOR
    ORDER BY id_vendedor;

  -- CURSOR CON PARAMETROS: ventas netas de un vendedor en un mes
  CURSOR cur_total_mes(p_id_vendedor EV_VENDEDOR.id_vendedor%TYPE,
                       p_anno NUMBER,
                       p_mes NUMBER) IS
    SELECT NVL(SUM(a.precio * d.cantidad), 0) AS total_ventas
    FROM EV_VENTA v
    JOIN EV_DETALLEVENTA d ON (v.id_venta = d.id_venta)
    JOIN EV_ARTICULO a ON (d.id_articulo = a.id_articulo)
    WHERE v.id_vendedor = p_id_vendedor
      AND EXTRACT(YEAR FROM v.fecha_venta) = p_anno
      AND EXTRACT(MONTH FROM v.fecha_venta) = p_mes;

  -- EXCEPCION DEFINIDA POR USUARIO
  ex_venta_sin_vendedor EXCEPTION;

  v_sin_vendedor NUMBER;
  v_filas NUMBER := 0;

BEGIN
  -- dejar la tabla vacia para poder ejecutar el bloque mas de una vez
  EXECUTE IMMEDIATE 'TRUNCATE TABLE EV_COMISION_VENTA_VENDEDOR';

  -- LOOP que recorre cada vendedor (cursor sin parametros)
  FOR reg_vendedor IN cur_vendedores LOOP

    -- se anida un segundo loop para recorrer cada mes de la lista (varray)
    FOR i IN 1..v_meses.COUNT LOOP

      v_comision.anno := v_anno;
      v_comision.mes := v_meses(i);
      v_comision.id_vendedor := reg_vendedor.id_vendedor;

      -- se anida un tercer loop para total del vendedor en ese mes (cursor con parametros)
      FOR reg_total IN cur_total_mes(reg_vendedor.id_vendedor, v_anno, v_meses(i)) LOOP
        v_comision.total_ventas := reg_total.total_ventas;
      END LOOP;

      -- buscar el tramo que le corresponde al total
      SELECT comision
        INTO v_comision.porcentaje
      FROM EV_COMISIONVENDEDOR
      WHERE v_comision.total_ventas BETWEEN ventaminima AND ventamaxima;

      -- calcular la comision 
      v_comision.monto_comision := ROUND(v_comision.total_ventas * v_comision.porcentaje / 100);

      INSERT INTO EV_COMISION_VENTA_VENDEDOR
             (anno, mes, id_vendedor, total_ventas, monto_comision)
      VALUES (v_comision.anno, v_comision.mes, v_comision.id_vendedor,
              v_comision.total_ventas, v_comision.monto_comision);

      DBMS_OUTPUT.PUT_LINE('ID: ' || reg_vendedor.id_vendedor ||
                           ' VENDEDOR: ' || reg_vendedor.nombre ||
                           ' | MES: ' || v_comision.mes || '/' || v_comision.anno ||
                           ' | VENTAS: $' || TO_CHAR(v_comision.total_ventas, 'FM999G999G990') ||
                           ' | COMISION ' || v_comision.porcentaje || '%: $' ||
                           TO_CHAR(v_comision.monto_comision, 'FM999G999G990'));

      v_filas := v_filas + 1;

    END LOOP;
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE(' ');
  DBMS_OUTPUT.PUT_LINE('Filas registradas en COMISION_VENTA_VENDEDOR: ' || v_filas);

  -- regla de negocio: toda venta debe tener vendedor
  SELECT COUNT(*)
    INTO v_sin_vendedor
  FROM EV_VENTA
  WHERE id_vendedor IS NULL;

  IF v_sin_vendedor > 0 THEN
    RAISE ex_venta_sin_vendedor;
  END IF;

EXCEPTION
  WHEN ex_venta_sin_vendedor THEN
    DBMS_OUTPUT.PUT_LINE('Aviso: existen ' || v_sin_vendedor ||
                         ' ventas sin vendedor, no se incluyeron en el calculo.');
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('No existe tramo de comision para el vendedor ' ||
                         v_comision.id_vendedor || ' con total ' || v_comision.total_ventas);
  WHEN TOO_MANY_ROWS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Hay mas de un tramo de comision para el total ' ||
                         v_comision.total_ventas);
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/

-- verificacion
SELECT anno, mes, COUNT(*) AS vendedores, SUM(total_ventas) AS ventas, SUM(monto_comision) AS comisiones
FROM EV_COMISION_VENTA_VENDEDOR
GROUP BY anno, mes
ORDER BY anno, mes;