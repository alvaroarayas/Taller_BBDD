-- Evaluacion Parcial 2 - Panel de Inteligencia de Negocio
-- PROCEDIMIENTOS ALMACENADOS
-- Requiere: "7. Funciones.sql" ya ejecutado.

SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------
-- PROCEDIMIENTO CON PARAMETROS: calculo de comisiones
-- Calcula la comision mensual de cada vendedor para los 3 meses
-- del trimestre indicado y la guarda en EV_COMISION_VENTA_VENDEDOR.
-- Llama a la funcion fn_porcentaje_comision.
-- ---------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_calcular_comisiones (
    p_anno      IN EV_COMISION_VENTA_VENDEDOR.anno%TYPE,
    p_trimestre IN NUMBER
) IS
    v_total      EV_COMISION_VENTA_VENDEDOR.total_ventas%TYPE;
    v_porcentaje NUMBER;
    v_monto      EV_COMISION_VENTA_VENDEDOR.monto_comision%TYPE;
    v_filas      NUMBER := 0;
BEGIN
    -- regla de negocio: el trimestre debe estar entre 1 y 4
    IF p_trimestre IS NULL OR p_trimestre NOT BETWEEN 1 AND 4 THEN
        raise_application_error(-20003, 'El trimestre debe estar entre 1 y 4');
    END IF;

    -- borrar solo el periodo que se va a recalcular (los demas trimestres se conservan)
    DELETE FROM EV_COMISION_VENTA_VENDEDOR
    WHERE
        anno = p_anno
        AND mes BETWEEN (p_trimestre * 3) - 2 AND (p_trimestre * 3);

    -- recorrer cada vendedor
    FOR vend IN (
        SELECT
            id_vendedor,
            nombres || ' ' || apellidos AS nombre
        FROM
            EV_VENDEDOR
        ORDER BY
            id_vendedor
    ) LOOP

        -- recorrer cada mes del trimestre (trimestre 2 = meses 4, 5 y 6)
        FOR v_mes IN (p_trimestre * 3) - 2 .. (p_trimestre * 3) LOOP

            -- total vendido por el vendedor en el mes
            SELECT
                NVL(SUM(a.precio * d.cantidad), 0)
            INTO v_total
            FROM
                EV_VENTA v
                JOIN EV_DETALLEVENTA d ON (v.id_venta = d.id_venta)
                JOIN EV_ARTICULO a ON (d.id_articulo = a.id_articulo)
            WHERE
                v.id_vendedor = vend.id_vendedor
                AND EXTRACT(YEAR FROM v.fecha_venta) = p_anno
                AND EXTRACT(MONTH FROM v.fecha_venta) = v_mes;

            -- la funcion entrega el porcentaje del tramo
            v_porcentaje := fn_porcentaje_comision(v_total);

            IF v_porcentaje IS NULL THEN
                raise_application_error(-20004, 'No existe tramo de comision para el total ' || v_total);
            END IF;

            v_monto := ROUND(v_total * v_porcentaje / 100);

            INSERT INTO EV_COMISION_VENTA_VENDEDOR (
                anno,
                mes,
                id_vendedor,
                total_ventas,
                monto_comision
            ) VALUES (
                p_anno,
                v_mes,
                vend.id_vendedor,
                v_total,
                v_monto
            );

            dbms_output.put_line('ID: ' || vend.id_vendedor
                                 || ' VENDEDOR: ' || vend.nombre
                                 || ' | MES: ' || v_mes || '/' || p_anno
                                 || ' | VENTAS: $' || TO_CHAR(v_total, 'FM999G999G990')
                                 || ' | COMISION ' || v_porcentaje || '%: $'
                                 || TO_CHAR(v_monto, 'FM999G999G990'));

            v_filas := v_filas + 1;
        END LOOP;
    END LOOP;

    COMMIT;
    dbms_output.put_line(' ');
    dbms_output.put_line('Trimestre ' || p_trimestre || '/' || p_anno || ': '
                         || v_filas || ' filas registradas en EV_COMISION_VENTA_VENDEDOR');
END;
/

-- ---------------------------------------------------------------
-- PROCEDIMIENTO CON PARAMETROS: auditoria de categoria
-- Compara la categoria asignada de cada vendedor con la que le
-- corresponde segun sus ventas del trimestre y guarda la propuesta
-- en EV_AUDITORIA_CATEGORIA_VENDEDOR (estado PENDIENTE).
-- Requiere que las comisiones del trimestre esten calculadas.
-- Llama a la funcion fn_categoria_por_ventas.
-- ---------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_auditar_categoria (
    p_anno      IN EV_AUDITORIA_CATEGORIA_VENDEDOR.anno%TYPE,
    p_trimestre IN EV_AUDITORIA_CATEGORIA_VENDEDOR.trimestre%TYPE
) IS
    v_hay_datos           NUMBER;
    v_categoria_calculada EV_AUDITORIA_CATEGORIA_VENDEDOR.categoria_calculada%TYPE;
    v_resultado           EV_AUDITORIA_CATEGORIA_VENDEDOR.resultado%TYPE;
    v_sube                NUMBER := 0;
    v_baja                NUMBER := 0;
    v_mantiene            NUMBER := 0;
BEGIN
    -- regla de negocio: no se puede auditar un trimestre sin comisiones calculadas
    -- (COUNT siempre retorna una fila: si no hay datos retorna 0)
    SELECT
        COUNT(*)
    INTO v_hay_datos
    FROM
        EV_COMISION_VENTA_VENDEDOR
    WHERE
        anno = p_anno
        AND mes BETWEEN (p_trimestre * 3) - 2 AND (p_trimestre * 3);

    IF v_hay_datos = 0 THEN
        raise_application_error(-20005, 'No hay comisiones calculadas para el trimestre '
                                        || p_trimestre || '/' || p_anno);
    END IF;

    -- borrar solo la auditoria del trimestre que se va a recalcular
    DELETE FROM EV_AUDITORIA_CATEGORIA_VENDEDOR
    WHERE
        anno = p_anno
        AND trimestre = p_trimestre;

    dbms_output.put_line('AUDITORIA DE CATEGORIA - TRIMESTRE ' || p_trimestre || '/' || p_anno);

    -- recorrer cada vendedor con sus ventas del trimestre
    FOR vend IN (
        SELECT
            v.id_vendedor,
            v.nombres || ' ' || v.apellidos AS nombre,
            v.id_categoria,
            NVL(SUM(c.total_ventas), 0)     AS ventas_trimestre
        FROM
            EV_VENDEDOR v
            LEFT JOIN EV_COMISION_VENTA_VENDEDOR c ON (v.id_vendedor = c.id_vendedor
                                                       AND c.anno = p_anno
                                                       AND c.mes BETWEEN (p_trimestre * 3) - 2 AND (p_trimestre * 3))
        GROUP BY
            v.id_vendedor,
            v.nombres,
            v.apellidos,
            v.id_categoria
        ORDER BY
            v.id_vendedor
    ) LOOP

        -- la funcion entrega la categoria que corresponde a las ventas
        v_categoria_calculada := fn_categoria_por_ventas(vend.ventas_trimestre);

        -- comparar: la letra A es menor que la B, asi que calculada < asignada significa que sube
        IF v_categoria_calculada = vend.id_categoria THEN
            v_resultado := 'MANTIENE';
            v_mantiene := v_mantiene + 1;
        ELSIF v_categoria_calculada < vend.id_categoria THEN
            v_resultado := 'SUBE';
            v_sube := v_sube + 1;
        ELSE
            v_resultado := 'BAJA';
            v_baja := v_baja + 1;
        END IF;

        INSERT INTO EV_AUDITORIA_CATEGORIA_VENDEDOR (
            anno,
            trimestre,
            id_vendedor,
            ventas_trimestre,
            categoria_asignada,
            categoria_calculada,
            resultado
        ) VALUES (
            p_anno,
            p_trimestre,
            vend.id_vendedor,
            vend.ventas_trimestre,
            vend.id_categoria,
            v_categoria_calculada,
            v_resultado
        );

        dbms_output.put_line('ID: ' || vend.id_vendedor
                             || ' VENDEDOR: ' || vend.nombre
                             || ' | VENTAS: $' || TO_CHAR(vend.ventas_trimestre, 'FM999G999G990')
                             || ' | ASIGNADA: ' || vend.id_categoria
                             || ' | CALCULADA: ' || v_categoria_calculada
                             || ' | ' || v_resultado);
    END LOOP;

    COMMIT;
    dbms_output.put_line(' ');
    dbms_output.put_line('Suben: ' || v_sube || ' | Bajan: ' || v_baja || ' | Mantienen: ' || v_mantiene);
END;
/

-- ---------------------------------------------------------------
-- PROCEDIMIENTO SIN PARAMETROS: auditoria de calidad de datos
-- Detecta ventas sin vendedor, ventas sin detalle y clientes sin
-- compras, y los guarda en EV_AUDITORIA_CALIDAD_DATOS.
-- Llama a la funcion fn_ventas_sin_vendedor.
-- ---------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_auditar_calidad_datos IS
    v_descripcion VARCHAR2(100);
    v_errores     NUMBER := 0;
    v_avisos      NUMBER := 0;
BEGIN
    -- este proceso revisa toda la base, por eso limpia toda la tabla
    DELETE FROM EV_AUDITORIA_CALIDAD_DATOS;

    -- ERROR: ventas sin vendedor
    FOR vta IN (
        SELECT
            id_venta,
            id_cliente,
            fecha_venta
        FROM
            EV_VENTA
        WHERE
            id_vendedor IS NULL
        ORDER BY
            id_venta
    ) LOOP
        v_descripcion := 'Venta del ' || TO_CHAR(vta.fecha_venta, 'DD/MM/YYYY')
                         || ' del cliente ' || vta.id_cliente || ' sin vendedor asignado';

        INSERT INTO EV_AUDITORIA_CALIDAD_DATOS (
            regla, id_registro, tipo, tabla_revisar, descripcion, accion_sugerida, fecha_auditoria
        ) VALUES (
            'VENTA_SIN_VENDEDOR', vta.id_venta, 'ERROR', 'EV_VENTA',
            v_descripcion, 'Asignar el vendedor que realizo la venta', sysdate
        );

        dbms_output.put_line('ERROR | VENTA: ' || vta.id_venta || ' | ' || v_descripcion);
        v_errores := v_errores + 1;
    END LOOP;

    -- ERROR: ventas sin detalle
    FOR vta IN (
        SELECT
            v.id_venta,
            v.id_vendedor,
            v.fecha_venta
        FROM
            EV_VENTA v
            LEFT JOIN EV_DETALLEVENTA d ON (v.id_venta = d.id_venta)
        WHERE
            d.id_venta IS NULL
        ORDER BY
            v.id_venta
    ) LOOP
        v_descripcion := 'Venta del ' || TO_CHAR(vta.fecha_venta, 'DD/MM/YYYY')
                         || ' del vendedor ' || NVL(TO_CHAR(vta.id_vendedor), 'sin vendedor')
                         || ' sin lineas de detalle';

        INSERT INTO EV_AUDITORIA_CALIDAD_DATOS (
            regla, id_registro, tipo, tabla_revisar, descripcion, accion_sugerida, fecha_auditoria
        ) VALUES (
            'VENTA_SIN_DETALLE', vta.id_venta, 'ERROR', 'EV_DETALLEVENTA',
            v_descripcion, 'Cargar las lineas de detalle de la venta o anularla si no corresponde', sysdate
        );

        dbms_output.put_line('ERROR | VENTA: ' || vta.id_venta || ' | ' || v_descripcion);
        v_errores := v_errores + 1;
    END LOOP;

    -- AVISO: clientes sin compras (no es un error, no hay tabla que corregir)
    FOR cli IN (
        SELECT
            c.id_cliente,
            c.nombre_cliente
        FROM
            EV_CLIENTE c
            LEFT JOIN EV_VENTA v ON (c.id_cliente = v.id_cliente)
        WHERE
            v.id_cliente IS NULL
        ORDER BY
            c.id_cliente
    ) LOOP
        v_descripcion := 'Cliente ' || cli.nombre_cliente || ' no registra compras';

        INSERT INTO EV_AUDITORIA_CALIDAD_DATOS (
            regla, id_registro, tipo, tabla_revisar, descripcion, accion_sugerida, fecha_auditoria
        ) VALUES (
            'CLIENTE_SIN_COMPRAS', cli.id_cliente, 'AVISO', NULL,
            v_descripcion, 'Contactar al cliente con una oferta comercial para incentivar su primera compra', sysdate
        );

        dbms_output.put_line('AVISO | CLIENTE: ' || cli.id_cliente || ' | ' || v_descripcion);
        v_avisos := v_avisos + 1;
    END LOOP;

    COMMIT;

    dbms_output.put_line(' ');
    dbms_output.put_line('Errores: ' || v_errores || ' | Avisos: ' || v_avisos);
    -- la funcion entrega el monto que queda fuera de las comisiones
    dbms_output.put_line('Monto de ventas sin vendedor, fuera de las comisiones: $'
                         || TO_CHAR(fn_ventas_sin_vendedor, 'FM999G999G990'));
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        dbms_output.put_line('ERROR: ' || sqlerrm);
END;
/

-- ---------------------------------------------------------------
-- PROCEDIMIENTO CON PARAMETROS IN y OUT: resolver una propuesta
-- Una persona del negocio aprueba o rechaza la propuesta de la
-- auditoria de categoria de un vendedor. Si la aprueba, se
-- actualiza la categoria en EV_VENDEDOR (esto activa el trigger
-- de historial). Devuelve en p_actualizados cuantas propuestas
-- se resolvieron (SQL%ROWCOUNT).
-- No hace COMMIT: quien lo llama confirma o deshace el cambio.
-- ---------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_resolver_revision (
    p_anno         IN EV_AUDITORIA_CATEGORIA_VENDEDOR.anno%TYPE,
    p_trimestre    IN EV_AUDITORIA_CATEGORIA_VENDEDOR.trimestre%TYPE,
    p_id_vendedor  IN EV_AUDITORIA_CATEGORIA_VENDEDOR.id_vendedor%TYPE,
    p_estado       IN EV_AUDITORIA_CATEGORIA_VENDEDOR.estado_revision%TYPE,
    p_actualizados OUT NUMBER
) IS
    v_categoria EV_AUDITORIA_CATEGORIA_VENDEDOR.categoria_calculada%TYPE;
BEGIN
    -- regla de negocio: solo se puede aprobar o rechazar
    IF p_estado IS NULL OR p_estado NOT IN ('APROBADO', 'RECHAZADO') THEN
        raise_application_error(-20001, 'El estado debe ser APROBADO o RECHAZADO');
    END IF;

    -- solo se resuelven propuestas que sigan pendientes
    UPDATE EV_AUDITORIA_CATEGORIA_VENDEDOR
    SET
        estado_revision = p_estado
    WHERE
        anno = p_anno
        AND trimestre = p_trimestre
        AND id_vendedor = p_id_vendedor
        AND estado_revision = 'PENDIENTE';

    p_actualizados := SQL%ROWCOUNT;

    IF p_actualizados = 0 THEN
        dbms_output.put_line('No hay propuesta pendiente para el vendedor ' || p_id_vendedor
                             || ' en el trimestre ' || p_trimestre || '/' || p_anno);
    ELSIF p_estado = 'APROBADO' THEN
        SELECT
            categoria_calculada
        INTO v_categoria
        FROM
            EV_AUDITORIA_CATEGORIA_VENDEDOR
        WHERE
            anno = p_anno
            AND trimestre = p_trimestre
            AND id_vendedor = p_id_vendedor;

        UPDATE EV_VENDEDOR
        SET
            id_categoria = v_categoria
        WHERE
            id_vendedor = p_id_vendedor;

        dbms_output.put_line('Propuesta APROBADA: el vendedor ' || p_id_vendedor
                             || ' queda en categoria ' || v_categoria);
    ELSE
        dbms_output.put_line('Propuesta RECHAZADA: el vendedor ' || p_id_vendedor
                             || ' mantiene su categoria');
    END IF;
END;
/
