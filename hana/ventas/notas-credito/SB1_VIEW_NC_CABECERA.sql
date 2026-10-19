/* =========================================================================
   SB1_VIEW_NC_CABECERA
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
   Propósito: cabecera de Notas de Crédito de clientes (ORIN) para el BI
              de Gerencia. Una fila por documento.

   Qué discrimina SB1_VIEW_VENTA_CABECERA_TDW / _DETALLE_TDW
   (reconstruido el 2026-10-16 comparando las vistas contra ORIN/RIN1;
   la definición SQL no es visible con el usuario actual):

     1. Cabecera de ventas: incluye NCUIO1 y NCGYE con montos EN NEGATIVO
        y excluye anuladas (CANCELED <> 'N') y la serie CANCEL.
     2. Detalle de ventas: además omite toda línea cuya cuenta NO empieza
        por 41. Quedan fuera, en el histórico vigente:
            42010102  Otros Ingresos             159 líneas   80,863.47
            19010101  Cuenta de Orden Deudora      9 líneas   12,004.08
            42010101  Venta de Activos Fijos      18 líneas    2,130.66
        Esas NC sí aparecen en la cabecera de ventas (el DocTotal las
        suma) y desaparecen en el detalle (0 líneas). El tablero de
        ventas, si mide por detalle, no las ve.

   Esta vista no aplica ese corte de cuenta. Trae toda NC vigente y
   marca cuánto de la base está dentro y fuera del detalle de ventas.

   Montos POSITIVOS, como en el módulo de Nota de crédito.
   En la vista de ventas el mismo DocTotal va con signo negativo.

   Factura modificada: ORIN."U_D_MODIFICADO" = OINV."U_N_DOCSRI".
   Desde 2024 el número SRI no se repite entre facturas vigentes
   (HAVING COUNT = 1). Si en el futuro se repitiera, la factura
   queda en NULL en lugar de duplicar la nota de crédito.

   Relación Power BI: DocEntry (1) -> SB1_VIEW_NC_DETALLE.DocEntry (*).
   Sumar DocTotal solo desde esta cabecera. El subtotal de líneas
   no incluye IVA; DocTotal sí.

   Despliegue: ejecutar este script en EMPAQPLAST_PROD.
   ========================================================================= */

CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_NC_CABECERA AS
WITH ClaseLinea AS (
    SELECT
        L."DocEntry",
        CASE
            WHEN L."AcctCode" = '41030101' THEN 'Devolucion en ventas'
            WHEN L."AcctCode" = '41020102' THEN 'Rebate'
            WHEN L."AcctCode" = '41020101' THEN 'Descuento en ventas'
            WHEN L."AcctCode" IN ('42010102', '42010101') THEN 'Otros ingresos'
            WHEN L."AcctCode" = '19010101' THEN 'Cuenta de orden'
            WHEN L."AcctCode" LIKE '41%' THEN 'Otra cuenta de ventas'
            ELSE 'Otra cuenta'
        END AS "Clase",
        L."LineTotal",
        CASE
            WHEN L."AcctCode" LIKE '41%' THEN L."LineTotal"
            ELSE 0
        END AS "BaseVista",
        CASE
            WHEN L."AcctCode" NOT LIKE '41%' OR L."AcctCode" IS NULL THEN L."LineTotal"
            ELSE 0
        END AS "BaseFuera"
    FROM RIN1 L
),
Resumen AS (
    SELECT
        "DocEntry",
        COUNT(*)                          AS "Lineas",
        COUNT(DISTINCT "Clase")           AS "NClases",
        MIN("Clase")                       AS "ClaseUnica",
        SUM("LineTotal")                   AS "BaseLineas",
        SUM("BaseVista")                   AS "BaseEnVistaVentas",
        SUM("BaseFuera")                   AS "BaseFueraVistaVentas"
    FROM ClaseLinea
    GROUP BY "DocEntry"
),
Factura AS (
    SELECT
        F."U_N_DOCSRI",
        MIN(F."DocEntry")    AS "DocEntry",
        MIN(F."DocNum")      AS "DocNum",
        MIN(F."DocDate")     AS "DocDate",
        MIN(F."DocTotal")    AS "DocTotal",
        MIN(S."SeriesName")  AS "SeriesName"
    FROM OINV F
    INNER JOIN NNM1 S
        ON S."Series" = F."Series"
    WHERE F."CANCELED" = 'N'
      AND IFNULL(F."U_N_DOCSRI", '') <> ''
    GROUP BY F."U_N_DOCSRI"
    HAVING COUNT(*) = 1
)
SELECT
    H."DocEntry"                                             AS "DocEntry",
    H."DocNum"                                               AS "DocNum",
    S."SeriesName"                                           AS "SeriesName",
    RIGHT(S."SeriesName", 3)                                 AS "Sucursal",
    CASE RIGHT(S."SeriesName", 3)
        WHEN 'GYE' THEN 'Guayaquil'
        WHEN 'IO1' THEN 'Quito'
        ELSE RIGHT(S."SeriesName", 3)
    END                                                      AS "SucursalNombre",
    H."CardCode"                                             AS "CardCode",
    H."CardName"                                             AS "CardName",
    IFNULL(C."LicTradNum", '')                               AS "Ruc",
    IFNULL(G."GroupName", '')                                AS "GrupoCliente",
    H."SlpCode"                                              AS "SlpCode",
    CASE
        WHEN H."SlpCode" = -1 OR V."SlpName" IS NULL THEN 'Sin vendedor'
        ELSE V."SlpName"
    END                                                      AS "Vendedor",
    CASE H."DocStatus"
        WHEN 'O' THEN 'Abierto'
        WHEN 'C' THEN 'Cerrado'
        ELSE H."DocStatus"
    END                                                      AS "Estado",
    CAST(H."DocDate" AS DATE)                                AS "DocDate",
    CAST(H."DocDueDate" AS DATE)                             AS "DocDueDate",
    CAST(H."TaxDate" AS DATE)                                AS "TaxDate",
    H."DocCur"                                               AS "Moneda",
    CAST(H."DocTotal" - H."VatSum" AS DECIMAL(19, 2))        AS "BaseImponible",
    CAST(H."VatSum" AS DECIMAL(19, 2))                       AS "VatSum",
    CAST(H."DiscPrcnt" AS DECIMAL(19, 2))                    AS "DiscPrcnt",
    CAST(H."DiscSum" AS DECIMAL(19, 2))                      AS "DiscSum",
    CAST(H."DocTotal" AS DECIMAL(19, 2))                     AS "DocTotal",
    CAST(H."PaidToDate" AS DECIMAL(19, 2))                   AS "Aplicado",
    CAST(H."DocTotal" - H."PaidToDate" AS DECIMAL(19, 2))    AS "Saldo",
    IFNULL(P."PymntGroup", '')                               AS "PymntGroup",
    IFNULL(H."PeyMethod", '')                                AS "PeyMethod",
    P."ExtraDays"                                            AS "ExtraDays",
    CAST(REPLACE(REPLACE(REPLACE(IFNULL(H."Comments", ''),
        CHAR(13), ' '), CHAR(10), ' '), '~', ' ')
        AS NVARCHAR(254))                                    AS "Comentarios",
    IFNULL(H."U_M_DEVOLUCION", '')                           AS "MotivoCodigo",
    CASE H."U_M_DEVOLUCION"
        WHEN '01' THEN 'No cumple con las medidas'
        WHEN '02' THEN 'Producto con humedad'
        WHEN '03' THEN 'No cumple con el olor'
        WHEN '04' THEN 'Producto con cuerpos extraños'
        WHEN '05' THEN 'Producto no cumple CA vs FT'
        WHEN '06' THEN 'Producto no cumple con el color'
        WHEN '07' THEN 'N/A'
        WHEN '08' THEN 'Calidad'
        WHEN '09' THEN 'Refacturacion'
        WHEN '10' THEN 'Descuento clientes'
        WHEN '11' THEN 'Muestras clientes'
        WHEN '12' THEN 'Error de despacho'
        WHEN '13' THEN 'Descuento por promocion'
        ELSE IFNULL(H."U_M_DEVOLUCION", '')
    END                                                      AS "Motivo",
    IFNULL(H."U_D_MODIFICADO", '')                           AS "DocModificado",
    CAST(H."U_F_MODIFICADO" AS DATE)                         AS "FechaDocModificado",
    F."DocEntry"                                             AS "FacturaDocEntry",
    F."DocNum"                                               AS "FacturaDocNum",
    IFNULL(F."SeriesName", '')                               AS "FacturaSerie",
    CAST(F."DocDate" AS DATE)                                AS "FacturaFecha",
    CAST(F."DocTotal" AS DECIMAL(19, 2))                     AS "FacturaTotal",
    IFNULL(H."U_N_DOCSRI", '')                               AS "NumeroSRI",
    IFNULL(H."U_NO_AUTORI", '')                              AS "Autorizacion",
    IFNULL(U."U_NAME", '')                                   AS "Usuario",
    CASE
        WHEN R."NClases" = 1 THEN R."ClaseUnica"
        WHEN R."NClases" > 1 THEN 'Mixta'
        ELSE 'Sin lineas'
    END                                                      AS "Clase",
    IFNULL(R."Lineas", 0)                                    AS "Lineas",
    CAST(IFNULL(R."BaseLineas", 0) AS DECIMAL(19, 2))        AS "BaseLineas",
    CAST(IFNULL(R."BaseEnVistaVentas", 0) AS DECIMAL(19, 2)) AS "BaseEnVistaVentas",
    CAST(IFNULL(R."BaseFueraVistaVentas", 0) AS DECIMAL(19, 2)) AS "BaseFueraVistaVentas"
FROM ORIN H
INNER JOIN NNM1 S
    ON S."Series" = H."Series"
LEFT JOIN OCRD C
    ON C."CardCode" = H."CardCode"
LEFT JOIN OCRG G
    ON G."GroupCode" = C."GroupCode"
LEFT JOIN OSLP V
    ON V."SlpCode" = H."SlpCode"
LEFT JOIN OCTG P
    ON P."GroupNum" = H."GroupNum"
LEFT JOIN OUSR U
    ON U."USERID" = H."UserSign"
LEFT JOIN Resumen R
    ON R."DocEntry" = H."DocEntry"
LEFT JOIN Factura F
    ON F."U_N_DOCSRI" = H."U_D_MODIFICADO"
   AND IFNULL(H."U_D_MODIFICADO", '') <> ''
WHERE H."CANCELED" = 'N';
