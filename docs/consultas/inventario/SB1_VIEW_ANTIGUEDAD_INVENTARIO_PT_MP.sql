/* =========================================================================
   SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP
   Esquema: EMPAQPLAST_PROD   |   Motor: SAP HANA
   Ticket GLPI 2621 — Tablero de antigüedad de producto terminado y materia prima

   Granularidad: una fila por artículo + lote + bodega con stock positivo.
   Los artículos sin lote salen una fila por artículo + bodega, con lote 'SIN LOTE'.

   FECHA DE REFERENCIA (verificado 2026-10-16 en producción):

   Producto terminado (grupo 102)
     El lote es la orden de Beas: OBTN.DistNumber = BEAS_FTPOS.BELNR_ID.
     487 de 495 lotes con stock cruzan así. La fecha es la ÚLTIMA entrada de
     mercancías no anulada de esa orden (OIGN / IGN1.U_beas_belnrid, mismo
     artículo). No se usa BEAS_FTPOS.ENDZEIT: es la fecha planificada.
     Ejemplo orden 11648: fin planificado 2026-10-01, entrada real 2026-10-16.
     Tampoco se usa OBTN.MnfDate como regla principal: en 315 lotes esa fecha
     es solo el primer día de producción y la orden sigue recibiendo después
     (316 lotes tienen entradas en más de un día).
     Si la orden no tiene entrada vigente, se usa MnfDate y luego InDate.
     Hoy eso cubre 10 lotes (8 no existen en Beas y 2 órdenes sin entrada).

   Materia prima (grupo 101)
     Fecha de entrada del lote = OBTN.InDate. En los lotes con stock coincide
     con la primera entrada: pedido (OITL DocType 20, 302 lotes) o entrada
     directa (DocType 59, 26 lotes). Es la admisión del lote, no un reingreso
     posterior del mismo número de lote (33 lotes de compra tienen más de una).

   Producto terminado no producido (grupo 114)
     Tapas compradas, sin lote, en bodega UIO_PT. No vienen de Beas.
     Se toma la última entrada de mercancía del artículo.

   No incluye semielaborado (grupo 103).

   VALOR
     OADM.PriceSys = 'Y': costo promedio por bodega (OITW.AvgPrice), moneda USD.
     Valor = cantidad en stock x costo de esa bodega.
     Contraste 2026-10-16 contra OITW.StockValue: diferencia de centavos
     por redondeo (MP 2,816,816.91 y PT+114 1,078,077.40).

   RANGOS (días hasta la fecha de corte)
     0 a 30 Normal | 31 a 60 Atención | 61 a 90 Alerta | más de 90 Crítico.
     Sin fecha de referencia: Sin fecha. Orden_Rango sirve para ordenar en Power BI.

   Peso_Kg: si la unidad es KG, la cantidad. Si no, cantidad x IWeight1 / 1000
   (IWeight1 está en gramos en el maestro de producto terminado).

   Despliegue: ejecutar este script en EMPAQPLAST_PROD. No modifica documentos.
   ========================================================================= */

CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP AS
WITH PROD AS (
    SELECT
        L."ItemCode",
        L."U_beas_belnrid" AS "Orden_Beas",
        MAX(G."DocDate") AS "Ultima_Produccion"
    FROM IGN1 L
    INNER JOIN OIGN G
        ON G."DocEntry" = L."DocEntry"
       AND G."CANCELED" = 'N'
    INNER JOIN OITM M
        ON M."ItemCode" = L."ItemCode"
       AND M."ItmsGrpCod" = 102
    WHERE L."U_beas_belnrid" > 0
      AND L."Quantity" > 0
    GROUP BY
        L."ItemCode",
        L."U_beas_belnrid"
),
ENTRADA_ART AS (
    SELECT
        X."ItemCode",
        MAX(X."DocDate") AS "Ultima_Entrada"
    FROM (
        SELECT
            D."ItemCode",
            C."DocDate"
        FROM PDN1 D
        INNER JOIN OPDN C
            ON C."DocEntry" = D."DocEntry"
           AND C."CANCELED" = 'N'
        INNER JOIN OITM M
            ON M."ItemCode" = D."ItemCode"
        WHERE M."ManBtchNum" = 'N'
          AND M."ItmsGrpCod" IN (101, 114)
          AND D."Quantity" > 0

        UNION ALL

        SELECT
            D."ItemCode",
            C."DocDate"
        FROM IGN1 D
        INNER JOIN OIGN C
            ON C."DocEntry" = D."DocEntry"
           AND C."CANCELED" = 'N'
        INNER JOIN OITM M
            ON M."ItemCode" = D."ItemCode"
        WHERE M."ManBtchNum" = 'N'
          AND M."ItmsGrpCod" IN (101, 114)
          AND D."Quantity" > 0
    ) X
    GROUP BY X."ItemCode"
)
SELECT
    S."Tipo_Inventario",
    S."Codigo_Grupo",
    S."Grupo",
    S."Codigo_Articulo",
    S."Descripcion",
    S."Unidad",
    S."Maneja_Lote",
    S."Lote",
    S."Orden_Beas",
    S."Bodega",
    S."Nombre_Bodega",
    S."Sucursal",
    S."Cantidad",
    S."Peso_Kg",
    S."Costo_Unitario",
    S."Valor_Inventario",
    S."Fecha_Referencia",
    S."Origen_Fecha",
    S."Dias_Antiguedad",
    CASE
        WHEN S."Fecha_Referencia" IS NULL THEN 'Sin fecha'
        WHEN S."Dias_Antiguedad" <= 30 THEN 'Normal'
        WHEN S."Dias_Antiguedad" <= 60 THEN 'Atención'
        WHEN S."Dias_Antiguedad" <= 90 THEN 'Alerta'
        ELSE 'Crítico'
    END AS "Rango_Antiguedad",
    CASE
        WHEN S."Fecha_Referencia" IS NULL THEN 5
        WHEN S."Dias_Antiguedad" <= 30 THEN 1
        WHEN S."Dias_Antiguedad" <= 60 THEN 2
        WHEN S."Dias_Antiguedad" <= 90 THEN 3
        ELSE 4
    END AS "Orden_Rango",
    CURRENT_DATE AS "Fecha_Corte"
FROM (
    SELECT
        CASE
            WHEN M."ItmsGrpCod" = 101 THEN 'Materia prima'
            ELSE 'Producto terminado'
        END AS "Tipo_Inventario",
        M."ItmsGrpCod" AS "Codigo_Grupo",
        G."ItmsGrpNam" AS "Grupo",
        M."ItemCode" AS "Codigo_Articulo",
        M."ItemName" AS "Descripcion",
        M."InvntryUom" AS "Unidad",
        'Y' AS "Maneja_Lote",
        B."DistNumber" AS "Lote",
        P."Orden_Beas",
        Q."WhsCode" AS "Bodega",
        H."WhsName" AS "Nombre_Bodega",
        CASE
            WHEN Q."WhsCode" LIKE 'UIO%' THEN 'Quito'
            WHEN Q."WhsCode" LIKE 'GYE%' THEN 'Guayaquil'
            ELSE 'Otra'
        END AS "Sucursal",
        Q."Quantity" AS "Cantidad",
        CASE
            WHEN M."InvntryUom" = 'KG' THEN Q."Quantity"
            WHEN COALESCE(M."IWeight1", 0) > 0
                THEN ROUND(Q."Quantity" * M."IWeight1" / 1000, 3)
            ELSE NULL
        END AS "Peso_Kg",
        COALESCE(W."AvgPrice", 0) AS "Costo_Unitario",
        ROUND(Q."Quantity" * COALESCE(W."AvgPrice", 0), 2) AS "Valor_Inventario",
        TO_DATE(
            CASE
                WHEN M."ItmsGrpCod" = 102
                    THEN COALESCE(P."Ultima_Produccion", B."MnfDate", B."InDate")
                ELSE B."InDate"
            END
        ) AS "Fecha_Referencia",
        CASE
            WHEN M."ItmsGrpCod" = 102 AND P."Ultima_Produccion" IS NOT NULL
                THEN 'Ultima produccion Beas'
            WHEN M."ItmsGrpCod" = 102 AND B."MnfDate" IS NOT NULL
                THEN 'Fecha de fabricacion del lote'
            WHEN M."ItmsGrpCod" = 102
                THEN 'Fecha de ingreso del lote'
            ELSE 'Entrada de mercancia del lote'
        END AS "Origen_Fecha",
        DAYS_BETWEEN(
            TO_DATE(
                CASE
                    WHEN M."ItmsGrpCod" = 102
                        THEN COALESCE(P."Ultima_Produccion", B."MnfDate", B."InDate")
                    ELSE B."InDate"
                END
            ),
            CURRENT_DATE
        ) AS "Dias_Antiguedad"
    FROM OBTQ Q
    INNER JOIN OBTN B
        ON B."AbsEntry" = Q."MdAbsEntry"
    INNER JOIN OITM M
        ON M."ItemCode" = Q."ItemCode"
    INNER JOIN OITB G
        ON G."ItmsGrpCod" = M."ItmsGrpCod"
    INNER JOIN OITW W
        ON W."ItemCode" = Q."ItemCode"
       AND W."WhsCode" = Q."WhsCode"
    INNER JOIN OWHS H
        ON H."WhsCode" = Q."WhsCode"
    LEFT JOIN PROD P
        ON P."ItemCode" = B."ItemCode"
       AND TO_NVARCHAR(P."Orden_Beas") = B."DistNumber"
    WHERE Q."Quantity" > 0
      AND M."ManBtchNum" = 'Y'
      AND M."ItmsGrpCod" IN (101, 102)

    UNION ALL

    SELECT
        CASE
            WHEN M."ItmsGrpCod" = 101 THEN 'Materia prima'
            ELSE 'Producto terminado'
        END AS "Tipo_Inventario",
        M."ItmsGrpCod" AS "Codigo_Grupo",
        G."ItmsGrpNam" AS "Grupo",
        M."ItemCode" AS "Codigo_Articulo",
        M."ItemName" AS "Descripcion",
        M."InvntryUom" AS "Unidad",
        'N' AS "Maneja_Lote",
        'SIN LOTE' AS "Lote",
        CAST(NULL AS INTEGER) AS "Orden_Beas",
        W."WhsCode" AS "Bodega",
        H."WhsName" AS "Nombre_Bodega",
        CASE
            WHEN W."WhsCode" LIKE 'UIO%' THEN 'Quito'
            WHEN W."WhsCode" LIKE 'GYE%' THEN 'Guayaquil'
            ELSE 'Otra'
        END AS "Sucursal",
        W."OnHand" AS "Cantidad",
        CASE
            WHEN M."InvntryUom" = 'KG' THEN W."OnHand"
            WHEN COALESCE(M."IWeight1", 0) > 0
                THEN ROUND(W."OnHand" * M."IWeight1" / 1000, 3)
            ELSE NULL
        END AS "Peso_Kg",
        COALESCE(W."AvgPrice", 0) AS "Costo_Unitario",
        ROUND(W."OnHand" * COALESCE(W."AvgPrice", 0), 2) AS "Valor_Inventario",
        TO_DATE(E."Ultima_Entrada") AS "Fecha_Referencia",
        'Ultima entrada del articulo' AS "Origen_Fecha",
        DAYS_BETWEEN(TO_DATE(E."Ultima_Entrada"), CURRENT_DATE) AS "Dias_Antiguedad"
    FROM OITW W
    INNER JOIN OITM M
        ON M."ItemCode" = W."ItemCode"
    INNER JOIN OITB G
        ON G."ItmsGrpCod" = M."ItmsGrpCod"
    INNER JOIN OWHS H
        ON H."WhsCode" = W."WhsCode"
    LEFT JOIN ENTRADA_ART E
        ON E."ItemCode" = W."ItemCode"
    WHERE W."OnHand" > 0
      AND M."ManBtchNum" = 'N'
      AND M."ItmsGrpCod" IN (101, 114)
) S;

-- GRANT SELECT ON EMPAQPLAST_PROD.SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP TO EMPAQPLAST;
