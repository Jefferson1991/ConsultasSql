-- =============================================================================
-- Facturas de venta -> plantilla de pricing (RevenueOS)
-- Origen: SAP B1 sobre HANA, esquema EMPAQPLAST_PROD (produccion).
--
-- Grano: una fila = una linea de factura (OINV + INV1).
--
-- Supuestos verificados contra produccion el 2026-08-14:
--   * CANCELED='N' descarta canceladas ('Y') y documentos de cancelacion ('C').
--   * El descuento de cabecera OINV."DiscPrcnt" NO esta aplicado en INV1."LineTotal".
--     Se comprobo que  SUM(LineTotal * (1 - DiscPrcnt/100)) + VatSum = DocTotal.
--     Por eso el precio neto unitario es  Price * (1 - DiscPrcnt/100).
--   * 26% de las lineas pertenecen a facturas con descuento de cabecera; ignorarlo
--     sobreestima el precio facturado.
--   * Moneda unica en el periodo: USD.
--   * No existe campo de inversion comercial en B1 (U_FLETE_INTERNA, U_Estibaje y
--     U_SEGURO_INTERNA estan en cero en todas las facturas del periodo).
--
-- Columnas de la plantilla que NO salen de aqui:
--   precio_facturado  -> formula en Excel  =precio_lista - descuento
--   tipo_cliente      -> clasificacion ABC por facturacion, se calcula en el script
--   inversion_comercial -> sin origen en B1, queda vacia
-- =============================================================================

SELECT
    T0."DocNum"                                              numero_factura,
    TO_VARCHAR(T0."DocDate", 'YYYY-MM-DD')                   fecha,
    T0."CardCode"                                            codigo_cliente,
    T0."CardName"                                            nombre_cliente,
    IFNULL(T2."GroupName", 'N/A')                            canal,
    T1."ItemCode"                                            codigo_sku,
    T1."Dscription"                                          descripcion_sku,
    T1."Quantity"                                            cantidad,
    T1."PriceBefDi"                                          precio_lista,
    T1."PriceBefDi" - T1."Price" * (1 - T0."DiscPrcnt" / 100) descuento,
    T1."StockPrice"                                          costo_unitario,
    T1."Currency"                                            moneda,
    T1."LineTotal" * (1 - T0."DiscPrcnt" / 100)              venta_neta
FROM OINV T0
INNER JOIN INV1 T1 ON T1."DocEntry"  = T0."DocEntry"
LEFT  JOIN OCRD T3 ON T3."CardCode"  = T0."CardCode"
LEFT  JOIN OCRG T2 ON T2."GroupCode" = T3."GroupCode"
WHERE T0."CANCELED" = 'N'
  AND T0."DocDate" >= '2025-01-01'
  AND T0."DocDate" <  '2027-01-01'
ORDER BY T0."DocDate", T0."DocNum", T1."LineNum"
