/* =========================================================================
   Pallets del flujo TransferenciasAutomaticas, por mes y cliente
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
   Propósito: cuántos pallets IPPALL0003 salió el flujo cada mes, por
              cliente, y cuánto hay hoy en stock.
   Supuestos verificados (2026-10-08):
     - Solo OWTR del flujo: U_TipoMov TRANSFERENCIA o REVERSO, con
       U_EntregaRef y U_ClienteCod, artículo IPPALL0003
     - Ruta de salida: UIO_PT -> UIO_CLT o GYE_PT -> GYE_CLT
     - El REVERSO del propio flujo (CLT -> PT, con referencia) sí entra
     - No entran devoluciones manuales ni traslados desde producción
     - Por eso el saldo del flujo no cuadra con el OnHand de UIO_CLT/GYE_CLT:
       esas bodegas también reciben y devuelven pallets por otros documentos
     - Stock = OnHand de hoy del artículo, en planta y en bodega de clientes
   ========================================================================= */

WITH Flujo AS (
    SELECT
        TO_NVARCHAR(T."DocDate", 'YYYY-MM') AS "Mes",
        CASE
            WHEN W."WhsCode" IN ('UIO_CLT', 'GYE_CLT') THEN W."WhsCode"
            ELSE W."FromWhsCod"
        END AS "Bodega",
        T."U_ClienteCod" AS "Codigo",
        SUM(CASE WHEN T."U_TipoMov" = 'TRANSFERENCIA' THEN W."Quantity" ELSE 0 END) AS "Salieron",
        SUM(CASE WHEN T."U_TipoMov" = 'REVERSO' THEN W."Quantity" ELSE 0 END) AS "Regresaron"
    FROM OWTR T
    INNER JOIN WTR1 W
        ON W."DocEntry" = T."DocEntry"
    WHERE T."CANCELED" = 'N'
      AND W."ItemCode" = 'IPPALL0003'
      AND T."U_TipoMov" IN ('TRANSFERENCIA', 'REVERSO')
      AND NULLIF(TRIM(T."U_EntregaRef"), '') IS NOT NULL
      AND NULLIF(TRIM(T."U_ClienteCod"), '') IS NOT NULL
      AND (
            (W."FromWhsCod" IN ('UIO_PT', 'GYE_PT') AND W."WhsCode" IN ('UIO_CLT', 'GYE_CLT'))
         OR (T."U_TipoMov" = 'REVERSO'
             AND W."FromWhsCod" IN ('UIO_CLT', 'GYE_CLT')
             AND W."WhsCode" IN ('UIO_PT', 'GYE_PT'))
      )
    GROUP BY
        TO_NVARCHAR(T."DocDate", 'YYYY-MM'),
        CASE
            WHEN W."WhsCode" IN ('UIO_CLT', 'GYE_CLT') THEN W."WhsCode"
            ELSE W."FromWhsCod"
        END,
        T."U_ClienteCod"
),
PorMes AS (
    SELECT
        "Mes",
        "Bodega",
        "Codigo",
        "Salieron",
        "Regresaron",
        "Salieron" - "Regresaron" AS "NetoMes",
        SUM("Salieron" - "Regresaron") OVER (
            PARTITION BY "Bodega", "Codigo"
            ORDER BY "Mes"
        ) AS "SaldoAcumulado"
    FROM Flujo
),
Resultado AS (
    SELECT
        1 AS "Orden",
        'Por mes' AS "Analisis",
        P."Mes",
        P."Bodega",
        H."WhsName" AS "BodegaNombre",
        P."Codigo" AS "Cliente",
        C."CardName" AS "NombreCliente",
        P."Salieron",
        P."Regresaron",
        P."NetoMes",
        P."SaldoAcumulado",
        CAST(NULL AS DECIMAL(19, 6)) AS "Stock"
    FROM PorMes P
    INNER JOIN OWHS H
        ON H."WhsCode" = P."Bodega"
    LEFT JOIN OCRD C
        ON C."CardCode" = P."Codigo"

    UNION ALL

    SELECT
        0,
        'Stock',
        NULL,
        S."WhsCode",
        H."WhsName",
        NULL,
        CASE
            WHEN S."WhsCode" IN ('UIO_PT', 'GYE_PT') THEN 'En planta'
            ELSE 'En bodega de clientes'
        END,
        NULL,
        NULL,
        NULL,
        NULL,
        S."OnHand"
    FROM OITW S
    INNER JOIN OWHS H
        ON H."WhsCode" = S."WhsCode"
    WHERE S."ItemCode" = 'IPPALL0003'
      AND S."WhsCode" IN ('UIO_PT', 'GYE_PT', 'UIO_CLT', 'GYE_CLT')
)
SELECT
    "Analisis",
    "Mes",
    "Bodega",
    "BodegaNombre",
    "Cliente",
    "NombreCliente",
    "Salieron",
    "Regresaron",
    "NetoMes",
    "SaldoAcumulado",
    "Stock"
FROM Resultado
ORDER BY "Orden", "NombreCliente", "Mes", "Bodega";
