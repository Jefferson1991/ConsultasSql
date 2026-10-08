/* =========================================================================
   Saldo de pallets por cliente y stock en bodega
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
   Propósito: cuántos pallets de madera hay con cada cliente y cuántos
              quedan en planta. Complementa el detalle guía/transferencia
              de Reporte Pallets.sql (flujo n8n TransferenciasAutomaticas).
   Supuestos verificados (2026-10-08):
     - Artículo: IPPALL0003 PALLETS DE MADERA
     - Sale de UIO_PT hacia UIO_CLT y de GYE_PT hacia GYE_CLT
     - Esas bodegas de cliente solo se mueven con transferencia (OINM 67)
     - El cliente sale de U_ClienteCod y, si viene vacío, de CardCode
     - La suma por cliente, incluido "SIN CLIENTE", cuadra con OITW.OnHand
     - Las devoluciones manuales a menudo no traen cliente: quedan en
       SIN CLIENTE y por eso el saldo nominal de un cliente puede ser
       mayor que el físico de la bodega
   ========================================================================= */

WITH SaldoCliente AS (
    SELECT
        M."Warehouse" AS "Bodega",
        COALESCE(
            NULLIF(TRIM(T."U_ClienteCod"), ''),
            NULLIF(TRIM(T."CardCode"), ''),
            'SIN CLIENTE'
        ) AS "Cliente",
        SUM(M."InQty") AS "Enviados",
        SUM(M."OutQty") AS "Devueltos",
        SUM(M."InQty" - M."OutQty") AS "Pallets"
    FROM OINM M
    INNER JOIN OWTR T
        ON T."DocEntry" = M."CreatedBy"
    WHERE M."TransType" = 67
      AND M."ItemCode" = 'IPPALL0003'
      AND M."Warehouse" IN ('UIO_CLT', 'GYE_CLT')
    GROUP BY
        M."Warehouse",
        COALESCE(
            NULLIF(TRIM(T."U_ClienteCod"), ''),
            NULLIF(TRIM(T."CardCode"), ''),
            'SIN CLIENTE'
        )
)
SELECT
    'Con cliente' AS "Tipo",
    S."Bodega",
    H."WhsName" AS "BodegaNombre",
    S."Cliente",
    C."CardName" AS "NombreCliente",
    S."Enviados",
    S."Devueltos",
    S."Pallets"
FROM SaldoCliente S
INNER JOIN OWHS H
    ON H."WhsCode" = S."Bodega"
LEFT JOIN OCRD C
    ON C."CardCode" = S."Cliente"
WHERE S."Pallets" <> 0

UNION ALL

SELECT
    'En stock' AS "Tipo",
    S."WhsCode",
    H."WhsName",
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
  AND S."OnHand" <> 0

ORDER BY 1, 2, 8 DESC;
