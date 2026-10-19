/* =========================================================================
   SB1_VIEW_NC_DETALLE
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
   Propósito: una fila por línea de Nota de Crédito (RIN1) para el BI
              de Gerencia. Incluye las líneas que SB1_VIEW_VENTA_DETALLE_TDW
              descarta.

   Corte de la vista de ventas (verificado 2026-10-16):
     En_Vista_Ventas = 'Y' solo si la cuenta empieza por 41.
     'N' = 42010102 Otros Ingresos, 42010101 Venta de Activos Fijos
           y 19010101 Cuenta de Orden Deudora.
     La vista de ventas además guarda cantidad, precio y total EN NEGATIVO.
     Aquí los montos van POSITIVOS, como en el documento.

   Costo_Inventario solo en devoluciones (cuenta 41030101): ahí StockSum
   es el costo del producto que regresa a bodega. En rebates y descuentos
   SAP copia el valor de la línea al stock; no es costo de producción
   y por eso Costo_Inventario queda en 0.

   Proceso_Linea es la dimensión 3 de la línea (OcrCode3: SOP-PET,
   SOPPETGY, etc.). Es el campo que la vista de ventas llama
   U_ProcesoProductivo. Proceso_Articulo es el dato maestro del ítem.

   Origen de la línea:
     13         factura (OINV) enlazada en SAP
     234000031  solicitud de devolución (ORRR)
     -1         sin documento base (típico en rebates y descuentos;
                la factura fiscal igual está en la cabecera,
                campo FacturaDocNum)

   Relación Power BI: DocEntry -> SB1_VIEW_NC_CABECERA.DocEntry.
   Llave de la línea: DocEntry + LineNum.
   No sumar DocTotal en esta tabla.

   Despliegue: ejecutar este script en EMPAQPLAST_PROD.
   ========================================================================= */

CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_NC_DETALLE AS
SELECT
    H."DocEntry"                                             AS "DocEntry",
    L."LineNum"                                              AS "LineNum",
    H."DocNum"                                               AS "DocNum",
    CAST(H."DocDate" AS DATE)                                AS "DocDate",
    S."SeriesName"                                           AS "SeriesName",
    RIGHT(S."SeriesName", 3)                                 AS "Sucursal",
    H."CardCode"                                             AS "CardCode",
    H."CardName"                                             AS "CardName",
    CASE
        WHEN H."SlpCode" = -1 OR V."SlpName" IS NULL THEN 'Sin vendedor'
        ELSE V."SlpName"
    END                                                      AS "Vendedor",
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
    L."ItemCode"                                             AS "ItemCode",
    CAST(REPLACE(REPLACE(REPLACE(IFNULL(L."Dscription", ''),
        CHAR(13), ' '), CHAR(10), ' '), '~', ' ')
        AS NVARCHAR(200))                                    AS "Dscription",
    IFNULL(B."ItmsGrpNam", '')                               AS "GrupoArticulo",
    IFNULL(I."U_ProcesoProductivo", '')                      AS "ProcesoArticuloCodigo",
    CASE I."U_ProcesoProductivo"
        WHEN '01' THEN 'Extrusion'
        WHEN '02' THEN 'Sellado'
        WHEN '03' THEN 'Soplado convencional'
        WHEN '04' THEN 'Inyeccion convencional'
        WHEN '05' THEN 'Inyeccion PET'
        WHEN '06' THEN 'Soplado PET'
        WHEN '07' THEN 'Inyecto soplado'
        WHEN '08' THEN 'Material segunda'
        WHEN '09' THEN 'Servicio cyrel'
        WHEN '10' THEN 'Descuento ventas'
        WHEN '11' THEN 'Servicio fajillado'
        WHEN '12' THEN 'Servicio fabricacion moldes'
        WHEN '13' THEN 'Servicio arriendo'
        WHEN '14' THEN 'Otros servicios'
        ELSE IFNULL(I."U_ProcesoProductivo", '')
    END                                                      AS "ProcesoArticulo",
    IFNULL(L."OcrCode3", '')                                 AS "ProcesoLinea",
    IFNULL(D3."OcrName", '')                                 AS "ProcesoLineaNombre",
    IFNULL(L."OcrCode", '')                                  AS "OcrCode",
    IFNULL(D1."OcrName", '')                                 AS "OcrName",
    IFNULL(L."OcrCode2", '')                                 AS "OcrCode2",
    IFNULL(L."WhsCode", '')                                  AS "WhsCode",
    IFNULL(L."unitMsr", '')                                  AS "Unidad",
    CAST(L."Quantity" AS DECIMAL(19, 4))                     AS "Quantity",
    CAST(L."PriceBefDi" AS DECIMAL(19, 6))                   AS "PrecioAntesDescuento",
    CAST(L."DiscPrcnt" AS DECIMAL(19, 2))                    AS "DiscPrcnt",
    CAST(L."Price" AS DECIMAL(19, 6))                        AS "Price",
    CAST(L."LineTotal" AS DECIMAL(19, 2))                    AS "LineTotal",
    IFNULL(L."TaxCode", '')                                  AS "TaxCode",
    CAST(L."VatPrcnt" AS DECIMAL(19, 2))                     AS "VatPrcnt",
    CAST(L."VatSum" AS DECIMAL(19, 2))                       AS "VatSum",
    CAST(L."LineTotal" + L."VatSum" AS DECIMAL(19, 2))       AS "TotalLinea",
    L."AcctCode"                                             AS "AcctCode",
    IFNULL(A."AcctName", '')                                 AS "AcctName",
    CASE
        WHEN L."AcctCode" = '41030101' THEN 'Devolucion en ventas'
        WHEN L."AcctCode" = '41020102' THEN 'Rebate'
        WHEN L."AcctCode" = '41020101' THEN 'Descuento en ventas'
        WHEN L."AcctCode" IN ('42010102', '42010101') THEN 'Otros ingresos'
        WHEN L."AcctCode" = '19010101' THEN 'Cuenta de orden'
        WHEN L."AcctCode" LIKE '41%' THEN 'Otra cuenta de ventas'
        ELSE 'Otra cuenta'
    END                                                      AS "Clase",
    CASE
        WHEN L."AcctCode" LIKE '41%' THEN 'Y'
        ELSE 'N'
    END                                                      AS "EnVistaVentas",
    CAST(L."StockPrice" AS DECIMAL(19, 6))                   AS "CostoUnitario",
    CAST(CASE
        WHEN L."AcctCode" = '41030101' THEN L."StockSum"
        ELSE 0
    END AS DECIMAL(19, 2))                                   AS "CostoInventario",
    CAST(IFNULL(I."SWeight1", 0) AS DECIMAL(19, 4))          AS "PesoGramos",
    CAST(L."Quantity" * IFNULL(I."SWeight1", 0) / 1000
        AS DECIMAL(19, 4))                                   AS "PesoKg",
    CASE
        WHEN L."BaseType" = 13 THEN 'Factura'
        WHEN L."BaseType" = 234000031 THEN 'Solicitud de devolucion'
        WHEN L."BaseType" = -1 THEN 'Sin documento base'
        ELSE 'Otro'
    END                                                      AS "Origen",
    CASE
        WHEN L."BaseType" = 13 THEN FB."DocNum"
        WHEN L."BaseType" = 234000031 THEN R."DocNum"
        ELSE NULL
    END                                                      AS "DocBaseNum",
    CAST(CASE
        WHEN L."BaseType" = 13 THEN FB."DocDate"
        WHEN L."BaseType" = 234000031 THEN R."DocDate"
        ELSE NULL
    END AS DATE)                                             AS "DocBaseFecha",
    CASE L."LineStatus"
        WHEN 'O' THEN 'Abierto'
        WHEN 'C' THEN 'Cerrado'
        ELSE L."LineStatus"
    END                                                      AS "EstadoLinea"
FROM ORIN H
INNER JOIN RIN1 L
    ON L."DocEntry" = H."DocEntry"
INNER JOIN NNM1 S
    ON S."Series" = H."Series"
LEFT JOIN OSLP V
    ON V."SlpCode" = H."SlpCode"
LEFT JOIN OITM I
    ON I."ItemCode" = L."ItemCode"
LEFT JOIN OITB B
    ON B."ItmsGrpCod" = I."ItmsGrpCod"
LEFT JOIN OACT A
    ON A."AcctCode" = L."AcctCode"
LEFT JOIN OOCR D1
    ON D1."OcrCode" = L."OcrCode"
LEFT JOIN OOCR D3
    ON D3."OcrCode" = L."OcrCode3"
LEFT JOIN OINV FB
    ON L."BaseType" = 13
   AND FB."DocEntry" = L."BaseEntry"
LEFT JOIN ORRR R
    ON L."BaseType" = 234000031
   AND R."DocEntry" = L."BaseEntry"
WHERE H."CANCELED" = 'N';
