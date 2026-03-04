-- =============================================================================
-- Stock Actual en Bodega por Sucursal – GYE y UIO
-- Réplica Informe Auditoría de Stocks
-- Base: OITW (saldos en tiempo real) + último movimiento de entrada/salida
-- Excluye grupos de artículos 106, 107, 108
-- =============================================================================

WITH UltimaEntrada AS (
    SELECT
        L."ItemCode",
        L."WhsCode",
        H."DocDate"  AS "Fecha_Ultima_Entrada",
        H."DocNum"   AS "No_Entrada",
        L."Quantity" AS "Cant_Ultima_Entrada",
        ROW_NUMBER() OVER (
            PARTITION BY L."ItemCode", L."WhsCode"
            ORDER BY H."DocDate" DESC, L."LineNum" DESC
        ) AS Rn
    FROM EMPAQPLAST_PROD.OIGN H
    INNER JOIN EMPAQPLAST_PROD.IGN1 L ON L."DocEntry" = H."DocEntry"
    WHERE H."CANCELED" = 'N'
      AND (L."WhsCode" LIKE 'GYE%' OR L."WhsCode" LIKE 'UIO%')
),
UltimaSalida AS (
    SELECT
        L."ItemCode",
        L."WhsCode",
        H."DocDate"  AS "Fecha_Ultima_Salida",
        H."DocNum"   AS "No_Salida",
        L."Quantity" AS "Cant_Ultima_Salida",
        ROW_NUMBER() OVER (
            PARTITION BY L."ItemCode", L."WhsCode"
            ORDER BY H."DocDate" DESC, L."LineNum" DESC
        ) AS Rn
    FROM EMPAQPLAST_PROD.OIGE H
    INNER JOIN EMPAQPLAST_PROD.IGE1 L ON L."DocEntry" = H."DocEntry"
    WHERE H."CANCELED" = 'N'
      AND (L."WhsCode" LIKE 'GYE%' OR L."WhsCode" LIKE 'UIO%')
)
SELECT
    CASE
        WHEN W."WhsCode" LIKE 'GYE%' THEN 'GYE'
        WHEN W."WhsCode" LIKE 'UIO%' THEN 'UIO'
    END                               AS "Sucursal",
    W."WhsCode"                       AS "Almacen",
    W2."WhsName"                      AS "Nombre_Almacen",
    W."ItemCode"                      AS "Codigo",
    T1."ItemName"                     AS "Descripción",
    -- Stock actual
    W."OnHand"                        AS "Stock_Disponible",
    W."IsCommited"                    AS "Comprometido",
    W."OnOrder"                       AS "En_Pedido",
    (W."OnHand" - W."IsCommited")     AS "Stock_Libre",
    W."AvgPrice"                      AS "Costo_Promedio",
    W."StockValue"                    AS "Valor_Stock",
    -- Último movimiento de entrada (TransType 59)
    E."Fecha_Ultima_Entrada",
    E."No_Entrada",
    E."Cant_Ultima_Entrada",
    -- Último movimiento de salida (TransType 60)
    S."Fecha_Ultima_Salida",
    S."No_Salida",
    S."Cant_Ultima_Salida"
FROM EMPAQPLAST_PROD.OITW W
INNER JOIN EMPAQPLAST_PROD.OITM T1 ON W."ItemCode" = T1."ItemCode"
INNER JOIN EMPAQPLAST_PROD.OWHS W2  ON W."WhsCode"  = W2."WhsCode"
LEFT  JOIN UltimaEntrada E ON E."ItemCode" = W."ItemCode" AND E."WhsCode" = W."WhsCode" AND E.Rn = 1
LEFT  JOIN UltimaSalida  S ON S."ItemCode" = W."ItemCode" AND S."WhsCode" = W."WhsCode" AND S.Rn = 1
WHERE W."OnHand" <> 0
  AND (W."WhsCode" LIKE 'GYE%' OR W."WhsCode" LIKE 'UIO%')
  AND T1."ItmsGrpCod" NOT IN (106, 107, 108)
ORDER BY "Sucursal" ASC, "Almacen" ASC, "Codigo" ASC;
