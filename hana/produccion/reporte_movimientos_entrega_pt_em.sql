-- =============================================================================
-- VALIDACIÓN EN HANA: ¿Existe BEAS_OINM?
-- Ejecute en HANA la consulta siguiente. Validado: la tabla SÍ existe en
-- EMPAQPLAST_PROD; este reporte NO la usa (solo documentos de marketing).
-- =============================================================================
SELECT
    CASE WHEN COUNT(*) > 0 THEN 'SÍ EXISTE' ELSE 'NO EXISTE' END AS "BEAS_OINM existe",
    (SELECT COUNT(*) FROM EMPAQPLAST_PROD.BEAS_OINM) AS "Registros en BEAS_OINM"
FROM SYS.TABLES
WHERE SCHEMA_NAME = 'EMPAQPLAST_PROD' AND TABLE_NAME = 'BEAS_OINM';
-- Este reporte usa solo ODLN/DLN1 (entregas = marketing), no BEAS_OINM ni OIGE/IGE1.


-- =============================================================================
-- Reporte: ENTRADAS DE MERCANCÍAS – TransType/ObjType 59
-- Base: OIGN (Entrada de mercancía) + IGN1 (líneas). ObjType 59 = Entrada mercancía
-- Filtros: Sucursales UIO–GYE, bodegas UIO_PROD y GYE_PROD
-- Incluye: Grupo de artículos, Nº orden de trabajo (si aplica)
-- =============================================================================
-- OIGN/IGN1 = documento de Entrada de mercancía (ObjType 59). No usa ODLN ni BEAS_OINM.
-- =============================================================================

SELECT
    H."DocEntry"                    AS "DocEntry",
    H."DocNum"                      AS "Nº Documento",
    H."DocDate"                     AS "Fecha Entrada",
    H."ObjType"                     AS "TransType",
    H."Series"                      AS "Series",
    H."Indicator"                   AS "Tipo Doc",
    H."CardCode"                    AS "Cód. Proveedor/Cliente",
    H."CardName"                    AS "Proveedor/Cliente",
    H."Comments"                    AS "Comentarios",
    L."LineNum"                     AS "Nº Línea",
    L."ItemCode"                    AS "Código Artículo",
    T1."ItemName"                   AS "Descripción Artículo",
    T2."ItmsGrpNam"                 AS "Grupo de Artículos",
    L."WhsCode"                     AS "Bodega",
    L."Quantity"                    AS "Cantidad",
    L."OpenQty"                     AS "Cant. Pendiente",
    L."Price"                       AS "Precio",
    L."LineTotal"                   AS "Total Línea",
    CAST(OW."DocNum" AS NVARCHAR(20)) AS "No. Orden Trabajo",
    L."BaseRef"                     AS "Ref. Base",
    L."BaseType"                    AS "Tipo Base",
    L."BaseEntry"                   AS "Entry Base"
FROM EMPAQPLAST_PROD.OIGN H
INNER JOIN EMPAQPLAST_PROD.IGN1 L
    ON L."DocEntry" = H."DocEntry"
INNER JOIN EMPAQPLAST_PROD.OITM T1
    ON T1."ItemCode" = L."ItemCode"
LEFT JOIN EMPAQPLAST_PROD.OITG T2
    ON T2."ItmsTypCod" = T1."ItmsGrpCod"
LEFT JOIN EMPAQPLAST_PROD.OWOR OW
    ON OW."DocEntry" = L."BaseEntry" AND L."BaseType" = 202
WHERE H."CANCELED" = 'N'
  AND H."DocStatus" = 'C'
  AND CAST(H."ObjType" AS INTEGER) = 59
  AND CAST(L."ObjType" AS INTEGER) = 59
  AND L."WhsCode" IN ('UIO_PROD', 'GYE_PROD')
ORDER BY H."DocDate" DESC, H."DocNum" DESC, L."LineNum";
