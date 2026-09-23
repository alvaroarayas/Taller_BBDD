SET SERVEROUTPUT ON;

-- Frente: auditoria de calidad de datos

-- BLOQUE PL/SQL (requiere la tabla creada con crear_tablas_resultados.sql)
DECLARE
  -- CURSOR ventas sin vendedor
  CURSOR cur_ventas_sin_vendedor IS
    SELECT id_venta, id_cliente, fecha_venta
    FROM EV_VENTA
    WHERE id_vendedor IS NULL
    ORDER BY id_venta;

  -- CURSOR ventas sin lineas de detalle
  CURSOR cur_ventas_sin_detalle IS
    SELECT v.id_venta, v.id_vendedor, v.fecha_venta
    FROM EV_VENTA v
    LEFT JOIN EV_DETALLEVENTA d ON (v.id_venta = d.id_venta)
    WHERE d.id_venta IS NULL
    ORDER BY v.id_venta;

  -- CURSOR clientes que no tienen ninguna compra
  CURSOR cur_clientes_sin_compras IS
    SELECT c.id_cliente, c.nombre_cliente
    FROM EV_CLIENTE c
    LEFT JOIN EV_VENTA v ON (c.id_cliente = v.id_cliente)
    WHERE v.id_cliente IS NULL
    ORDER BY c.id_cliente;

  v_descripcion VARCHAR2(100);
  v_sin_vendedor NUMBER := 0;
  v_sin_detalle NUMBER := 0;
  v_sin_compras NUMBER := 0;
BEGIN
  -- dejar la tabla vacia para poder ejecutar el bloque mas de una vez
  EXECUTE IMMEDIATE 'TRUNCATE TABLE EV_AUDITORIA_CALIDAD_DATOS';

  -- ERROR: ventas sin vendedor
  FOR reg_venta IN cur_ventas_sin_vendedor LOOP
    v_descripcion := 'Venta del ' || TO_CHAR(reg_venta.fecha_venta, 'DD/MM/YYYY') ||
                     ' del cliente ' || reg_venta.id_cliente || ' sin vendedor asignado';
    INSERT INTO EV_AUDITORIA_CALIDAD_DATOS
           (regla, id_registro, tipo, tabla_revisar, descripcion, accion_sugerida, fecha_auditoria)
    VALUES ('VENTA_SIN_VENDEDOR', reg_venta.id_venta, 'ERROR', 'EV_VENTA',
            v_descripcion, 'Asignar el vendedor que realizo la venta', SYSDATE);
    DBMS_OUTPUT.PUT_LINE('ERROR | VENTA: ' || reg_venta.id_venta || ' | ' || v_descripcion ||
                         ' | REVISAR: EV_VENTA');
    v_sin_vendedor := v_sin_vendedor + 1;
  END LOOP;

  -- ERROR: ventas sin detalle
  FOR reg_venta IN cur_ventas_sin_detalle LOOP
    v_descripcion := 'Venta del ' || TO_CHAR(reg_venta.fecha_venta, 'DD/MM/YYYY') ||
                     ' del vendedor ' || NVL(TO_CHAR(reg_venta.id_vendedor), 'sin vendedor') ||
                     ' sin lineas de detalle';
    INSERT INTO EV_AUDITORIA_CALIDAD_DATOS
           (regla, id_registro, tipo, tabla_revisar, descripcion, accion_sugerida, fecha_auditoria)
    VALUES ('VENTA_SIN_DETALLE', reg_venta.id_venta, 'ERROR', 'EV_DETALLEVENTA',
            v_descripcion, 'Cargar las lineas de detalle de la venta o anularla si no corresponde', SYSDATE);
    DBMS_OUTPUT.PUT_LINE('ERROR | VENTA: ' || reg_venta.id_venta || ' | ' || v_descripcion ||
                         ' | REVISAR: EV_DETALLEVENTA');
    v_sin_detalle := v_sin_detalle + 1;
  END LOOP;

  -- AVISO: clientes sin compras (no es un error, no hay tabla que corregir)
  FOR reg_cliente IN cur_clientes_sin_compras LOOP
    v_descripcion := 'Cliente ' || reg_cliente.nombre_cliente || ' no registra compras';
    INSERT INTO EV_AUDITORIA_CALIDAD_DATOS
           (regla, id_registro, tipo, tabla_revisar, descripcion, accion_sugerida, fecha_auditoria)
    VALUES ('CLIENTE_SIN_COMPRAS', reg_cliente.id_cliente, 'AVISO', NULL,
            v_descripcion, 'Incluir al cliente en una campa?a comercial para incentivar su primera compra', SYSDATE);
    DBMS_OUTPUT.PUT_LINE('AVISO | CLIENTE: ' || reg_cliente.id_cliente || ' | ' || v_descripcion ||
                         ' | ACCION: campa?a comercial');
    v_sin_compras := v_sin_compras + 1;
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE(' ');
  DBMS_OUTPUT.PUT_LINE('Hallazgos registrados: ' || (v_sin_vendedor + v_sin_detalle) ||
                       ' errores (' || v_sin_vendedor || ' ventas sin vendedor, ' ||
                       v_sin_detalle || ' venta sin detalle) y ' ||
                       v_sin_compras || ' aviso (cliente sin compras)');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/

-- verificacion
SELECT regla, id_registro, tipo, tabla_revisar, descripcion, accion_sugerida, estado_revision
FROM EV_AUDITORIA_CALIDAD_DATOS
ORDER BY regla, id_registro;