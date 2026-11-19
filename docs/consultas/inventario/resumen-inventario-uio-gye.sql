-- =============================================================================
-- Resumen Inventario por Sucursal – Réplica Informe Auditoría de Stocks
-- Movimientos TransType 59 (Entrada) / 60 (Salida) – Secciones GYE y UIO
-- Fuentes HANA: OIGN/IGN1 (59) y OIGE/IGE1 (60)
-- Excluye grupos de artículos 106, 107, 108
-- Ajustar YEAR / MONTH en el WHERE de cada CTE según el período requerido
-- =============================================================================

WITH Movimientos AS (
    -- TransType 59: Entradas de mercancía
    SELECT
        H."DocDate"                      AS "DocDate",
        '59'                             AS "TransType",
        CAST(H."DocNum" AS NVARCHAR(20)) AS "BASE_REF",
        L."ItemCode",
        L."LineNum"                      AS "TransSeq",
        L."WhsCode"                      AS "Warehouse",
        L."Quantity"                     AS "InQty",
        0                                AS "OutQty",
        L."Price"                        AS "CalcPrice"
    FROM EMPAQPLAST_PROD.OIGN H
    INNER JOIN EMPAQPLAST_PROD.IGN1 L ON L."DocEntry" = H."DocEntry"
    WHERE H."CANCELED" = 'N'
      AND (L."WhsCode" LIKE 'GYE%' OR L."WhsCode" LIKE 'UIO%')
      AND YEAR(H."DocDate") = 2026 AND MONTH(H."DocDate") = 1

    UNION ALL

    -- TransType 60: Salidas de mercancía
    SELECT
        H."DocDate"                      AS "DocDate",
        '60'                             AS "TransType",
        CAST(H."DocNum" AS NVARCHAR(20)) AS "BASE_REF",
        L."ItemCode",
        L."LineNum"                      AS "TransSeq",
        L."WhsCode"                      AS "Warehouse",
        0                                AS "InQty",
        L."Quantity"                     AS "OutQty",
        L."Price"                        AS "CalcPrice"
    FROM EMPAQPLAST_PROD.OIGE H
    INNER JOIN EMPAQPLAST_PROD.IGE1 L ON L."DocEntry" = H."DocEntry"
    WHERE H."CANCELED" = 'N'
      AND (L."WhsCode" LIKE 'GYE%' OR L."WhsCode" LIKE 'UIO%')
      AND YEAR(H."DocDate") = 2026 AND MONTH(H."DocDate") = 1
),
ResumenInventario AS (
    SELECT
        T0."DocDate"   AS "Fecha_Contabilización",
        T0."TransType" AS "Tipo_Transacción",
        CASE
            WHEN T0."TransType" = '59' THEN 'Entrada Mercancías'
            WHEN T0."TransType" = '60' THEN 'Salida Mercancías'
            ELSE 'Otros'
        END            AS "Documento",
        T0."BASE_REF"  AS "No_Documento",
        T0."ItemCode"  AS "Codigo",
        T1."ItemName"  AS "Descripción",
        T0."Warehouse" AS "Almacen",
        CASE
            WHEN T0."Warehouse" LIKE 'GYE%' THEN 'GYE'
            WHEN T0."Warehouse" LIKE 'UIO%' THEN 'UIO'
            ELSE T0."Warehouse"
        END            AS "Sucursal",
        (T0."InQty" - T0."OutQty") AS "Cantidad_Neta",
        T0."CalcPrice" AS "Costo_Unidad",
        -- Último movimiento por ítem / tipo de transacción / almacén
        ROW_NUMBER() OVER (
            PARTITION BY T0."ItemCode", T0."TransType", T0."Warehouse"
            ORDER BY T0."DocDate" DESC, T0."TransSeq" DESC
        )              AS "Ranking"
    FROM Movimientos T0
    INNER JOIN EMPAQPLAST_PROD.OITM T1 ON T0."ItemCode" = T1."ItemCode"
    WHERE T1."ItmsGrpCod" NOT IN (106, 107, 108)
)
SELECT
    "Sucursal",
    "Fecha_Contabilización",
    "Tipo_Transacción",
    "Documento",
    "No_Documento",
    "Codigo",
    "Descripción",
    "Almacen",
    "Cantidad_Neta",
    "Costo_Unidad"
FROM ResumenInventario
WHERE "Ranking" = 1
ORDER BY "Sucursal" ASC, "Codigo" ASC, "Almacen" ASC, "Fecha_Contabilización" DESC;
