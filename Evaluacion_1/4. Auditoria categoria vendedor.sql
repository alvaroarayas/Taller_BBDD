SET SERVEROUTPUT ON;

-- Frente: auditoria de categoria de vendedores (revision trimestral)

-- BLOQUE PL/SQL (requiere la tabla creada con crear_tablas_resultados.sql)
DECLARE
  -- trimestre a auditar (2 = abril, mayo y junio)
  v_anno NUMBER := 2021;
  v_trimestre NUMBER := 2;

  -- RECORD: una fila de la tabla de resultados
  TYPE Auditoria_rec IS RECORD (
    anno                EV_AUDITORIA_CATEGORIA_VENDEDOR.anno%TYPE,
    trimestre           EV_AUDITORIA_CATEGORIA_VENDEDOR.trimestre%TYPE,
    id_vendedor         EV_AUDITORIA_CATEGORIA_VENDEDOR.id_vendedor%TYPE,
    ventas_trimestre    EV_AUDITORIA_CATEGORIA_VENDEDOR.ventas_trimestre%TYPE,
    categoria_asignada  EV_AUDITORIA_CATEGORIA_VENDEDOR.categoria_asignada%TYPE,
    categoria_calculada EV_AUDITORIA_CATEGORIA_VENDEDOR.categoria_calculada%TYPE,
    resultado           EV_AUDITORIA_CATEGORIA_VENDEDOR.resultado%TYPE
  );
  v_auditoria Auditoria_rec;

  -- CURSOR SIN PARAMETROS: todos los vendedores con su categoria asignada
  CURSOR cur_vendedores IS
    SELECT id_vendedor, nombres || ' ' || apellidos AS nombre, id_categoria
    FROM EV_VENDEDOR
    ORDER BY id_vendedor;

  -- CURSOR CON PARAMETROS: ventas de un vendedor en los 3 meses del trimestre
  CURSOR cur_ventas_trimestre(p_id_vendedor EV_VENDEDOR.id_vendedor%TYPE,
                              p_anno NUMBER,
                              p_trimestre NUMBER) IS
    SELECT NVL(SUM(total_ventas), 0) AS ventas_trimestre
    FROM EV_COMISION_VENTA_VENDEDOR
    WHERE id_vendedor = p_id_vendedor
      AND anno = p_anno
      AND mes BETWEEN (p_trimestre * 3) - 2 AND (p_trimestre * 3);

  -- EXCEPCION DEFINIDA POR EL USUARIO
  ex_trimestre_sin_datos EXCEPTION;

  v_hay_datos NUMBER;
  v_id_cat EV_CATEGORIA.id_categoria%TYPE;
  v_filas NUMBER := 0;
  v_sube NUMBER := 0;
  v_baja NUMBER := 0;
  v_mantiene NUMBER := 0;
BEGIN
  -- regla de negocio: no se puede auditar un trimestre sin comisiones calculadas
  SELECT COUNT(*)
    INTO v_hay_datos
  FROM EV_COMISION_VENTA_VENDEDOR
  WHERE anno = v_anno
    AND mes BETWEEN (v_trimestre * 3) - 2 AND (v_trimestre * 3);

  IF v_hay_datos = 0 THEN
    RAISE ex_trimestre_sin_datos;
  END IF;

  -- dejar la tabla vacia para poder ejecutar el bloque mas de una vez
  EXECUTE IMMEDIATE 'TRUNCATE TABLE EV_AUDITORIA_CATEGORIA_VENDEDOR';

  DBMS_OUTPUT.PUT_LINE('AUDITORIA DE CATEGORIA - TRIMESTRE ' || v_trimestre || '/' || v_anno);

  -- LOOP 1: cada vendedor (cursor sin parametros)
  FOR reg_vendedor IN cur_vendedores LOOP

    v_auditoria.anno := v_anno;
    v_auditoria.trimestre := v_trimestre;
    v_auditoria.id_vendedor := reg_vendedor.id_vendedor;
    v_auditoria.categoria_asignada := reg_vendedor.id_categoria;

    -- LOOP 2: ventas del vendedor en el trimestre 
    FOR reg_ventas IN cur_ventas_trimestre(reg_vendedor.id_vendedor, v_anno, v_trimestre) LOOP
      v_auditoria.ventas_trimestre := reg_ventas.ventas_trimestre;
    END LOOP;

    -- categoria que le corresponde segun las ventas del trimestre
    IF v_auditoria.ventas_trimestre >= 15000000 THEN
      v_auditoria.categoria_calculada := 'A';   -- desde 15.000.000
    ELSIF v_auditoria.ventas_trimestre >= 12000000 THEN
      v_auditoria.categoria_calculada := 'B';   -- 12.000.000 hasta 14.999.999
    ELSIF v_auditoria.ventas_trimestre >= 9000000 THEN
      v_auditoria.categoria_calculada := 'C';   -- 9.000.000 hasta 11.999.999
    ELSIF v_auditoria.ventas_trimestre >= 6000000 THEN
      v_auditoria.categoria_calculada := 'D';   -- 6.000.000 hasta 8.999.999
    ELSE
      v_auditoria.categoria_calculada := 'E';   -- hasta 5.999.999
    END IF;

    -- la categoria calculada debe existir en la tabla de categorias
    -- (NO_DATA_FOUND si no existe)
    SELECT id_categoria
      INTO v_id_cat
    FROM EV_CATEGORIA
    WHERE id_categoria = v_auditoria.categoria_calculada;

    -- comparar: la letra A es menor que la B, asi que calculada < asignada significa que sube
    IF v_auditoria.categoria_calculada = v_auditoria.categoria_asignada THEN
      v_auditoria.resultado := 'MANTIENE';
      v_mantiene := v_mantiene + 1;
    ELSIF v_auditoria.categoria_calculada < v_auditoria.categoria_asignada THEN
      v_auditoria.resultado := 'SUBE';
      v_sube := v_sube + 1;
    ELSE
      v_auditoria.resultado := 'BAJA';
      v_baja := v_baja + 1;
    END IF;

    INSERT INTO EV_AUDITORIA_CATEGORIA_VENDEDOR
           (anno, trimestre, id_vendedor, ventas_trimestre,
            categoria_asignada, categoria_calculada, resultado)
    VALUES (v_auditoria.anno, v_auditoria.trimestre, v_auditoria.id_vendedor,
            v_auditoria.ventas_trimestre, v_auditoria.categoria_asignada,
            v_auditoria.categoria_calculada, v_auditoria.resultado);

    DBMS_OUTPUT.PUT_LINE('ID: ' || reg_vendedor.id_vendedor ||
                         ' VENDEDOR: ' || reg_vendedor.nombre ||
                         ' | VENTAS: $' || TO_CHAR(v_auditoria.ventas_trimestre, 'FM999G999G990') ||
                         ' | ASIGNADA: ' || v_auditoria.categoria_asignada ||
                         ' | CALCULADA: ' || v_auditoria.categoria_calculada ||
                         ' | ' || v_auditoria.resultado);

    v_filas := v_filas + 1;

  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE(' ');
  DBMS_OUTPUT.PUT_LINE('Trimestre ' || v_trimestre || '/' || v_anno || ' auditado.');
  DBMS_OUTPUT.PUT_LINE('Vendedores: ' || v_filas || ' | Suben: ' || v_sube ||
                       ' | Bajan: ' || v_baja || ' | Mantienen: ' || v_mantiene);

EXCEPTION
  WHEN ex_trimestre_sin_datos THEN
    DBMS_OUTPUT.PUT_LINE('No hay comisiones calculadas para el trimestre ' ||
                         v_trimestre || '/' || v_anno || ', no se puede auditar.');
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('La categoria ' || v_auditoria.categoria_calculada ||
                         ' no existe en EV_CATEGORIA.');
  WHEN TOO_MANY_ROWS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Hay mas de una categoria ' || v_auditoria.categoria_calculada ||
                         ' en EV_CATEGORIA.');
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/

-- verificacion
SELECT a.id_vendedor, v.nombres || ' ' || v.apellidos AS vendedor, a.ventas_trimestre,
       a.categoria_asignada, a.categoria_calculada, a.resultado, a.estado_revision
FROM EV_AUDITORIA_CATEGORIA_VENDEDOR a
JOIN EV_VENDEDOR v ON (a.id_vendedor = v.id_vendedor)
ORDER BY a.ventas_trimestre DESC;