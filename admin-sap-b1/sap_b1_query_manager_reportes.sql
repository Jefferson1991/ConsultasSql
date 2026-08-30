-- =============================================================================
-- SAP B1 sobre HANA - Reportes del Query Manager con categoría y área
-- Área inferida SOLO por tablas/vistas que aparecen en el SQL (QString).
-- Patrones amplios para cubrir: "OINV", OINV, T0.OINV, "ESQUEMA"."OINV", etc.
-- Esquema: EMPAQPLAST_PROD
-- =============================================================================
ALTER VIEW Fact_Reporte_Query_Manager AS 
SELECT
    T0."IntrnalKey"     AS "IdConsulta",
    T0."QName"          AS "NombreReporte",
    T1."CatName"        AS "NombreCategoria",
    CASE
        -- BEAS Manufacturing (primero: tablas BEAS, vistas BEAS, campos U_beas_/U_PLG_, vistas PT/recursos)
        WHEN T0."QString" LIKE '%BEAS_%'
          OR T0."QString" LIKE '%SB1_VIEW_BEAS%' OR T0."QString" LIKE '%SB1_VIEW_%BEAS%'
          OR T0."QString" LIKE '%RECURSOS_BEAS%' OR T0."QString" LIKE '%BEAS_PARADAS%'
          OR T0."QString" LIKE '%BEAS_TIEMPOS_PRODUCCION%' OR T0."QString" LIKE '%BEAS_FTAPL%'
          OR T0."QString" LIKE '%BEAS_FTPOS%' OR T0."QString" LIKE '%BEAS_RESUMEN%'
          OR T0."QString" LIKE '%BEAS_CONSOLIDADO%'
          OR T0."QString" LIKE '%U_beas_%' OR T0."QString" LIKE '%U_PLG_%'
          OR T0."QString" LIKE '%SB1_VIEW_PT_RESUMEN%' OR T0."QString" LIKE '%RECICLADO_MIPRO%'
             THEN 'Produccion Beas Manufacturing'
        -- Ventas: facturas, entregas, pedidos, cotizaciones, vendedores, vistas ventas/cliente
        WHEN T0."QString" LIKE '%OINV%' OR T0."QString" LIKE '%INV1%'
          OR T0."QString" LIKE '%ODLN%' OR T0."QString" LIKE '%DLN1%'
          OR T0."QString" LIKE '%ORDR%' OR T0."QString" LIKE '%RDR1%'
          OR T0."QString" LIKE '%OQUT%' OR T0."QString" LIKE '%QUT1%'
          OR T0."QString" LIKE '%OSLP%'
          OR T0."QString" LIKE '%SB1_VIEW_REPORTECLIENTEVENDEDOR%' OR T0."QString" LIKE '%SB1_VIEW_VENTAS%'
             THEN 'Ventas'
        -- Compras: órdenes compra, solicitudes, cotizaciones compra, entradas, facturas proveedor
        WHEN T0."QString" LIKE '%OPOR%' OR T0."QString" LIKE '%POR1%'
          OR T0."QString" LIKE '%OPRQ%' OR T0."QString" LIKE '%PRQ1%'
          OR T0."QString" LIKE '%OPQT%' OR T0."QString" LIKE '%PQT1%'
          OR T0."QString" LIKE '%OPDN%' OR T0."QString" LIKE '%PDN1%'
          OR T0."QString" LIKE '%OPCH%' OR T0."QString" LIKE '%PCH1%'
             THEN 'Compras'
        -- Inventario: ítems, bodegas, traslados, entradas/salidas (OIGN/IGN1), lotes, vistas stock
        WHEN T0."QString" LIKE '%OITM%' OR T0."QString" LIKE '%OITW%'
          OR T0."QString" LIKE '%OWHS%' OR T0."QString" LIKE '%OWTR%' OR T0."QString" LIKE '%WTR1%'
          OR T0."QString" LIKE '%OIGE%' OR T0."QString" LIKE '%IGE1%'
          OR T0."QString" LIKE '%OGRE%' OR T0."QString" LIKE '%GRE1%'
          OR T0."QString" LIKE '%OIGN%' OR T0."QString" LIKE '%IGN1%'
          OR T0."QString" LIKE '%OBTQ%' OR T0."QString" LIKE '%OBTW%'
          OR T0."QString" LIKE '%OWTQ%' OR T0."QString" LIKE '%WTQ1%'
          OR T0."QString" LIKE '%SB1_VIEW_ANALISIS_STOCK%' OR T0."QString" LIKE '%SB1_VIEW_REVISION_STOCK%'
          OR T0."QString" LIKE '%SB1_VIEW_PERMANECIA%'
             THEN 'Inventario'
        -- Tesorería / Bancos: cuentas bancarias, cheques, conciliaciones bancarias
        WHEN T0."QString" LIKE '%OBNK%' OR T0."QString" LIKE '%BNK1%'
          OR T0."QString" LIKE '%OCHO%' OR T0."QString" LIKE '%OCQN%'
          OR T0."QString" LIKE '%OBOE%' OR T0."QString" LIKE '%BOE1%'
          OR T0."QString" LIKE '%OBTB%' OR T0."QString" LIKE '%BTB1%'
          OR T0."QString" LIKE '%SB1_VIEW_%BANCO%' OR T0."QString" LIKE '%SB1_VIEW_%CHEQUE%'
             THEN 'Tesorería / Bancos'
        -- Pagos y Cobros: pagos emitidos, pagos recibidos, anticipos
        WHEN T0."QString" LIKE '%OVPM%' OR T0."QString" LIKE '%VPM1%'
          OR T0."QString" LIKE '%ORCT%' OR T0."QString" LIKE '%RCT1%'
          OR T0."QString" LIKE '%ODPI%' OR T0."QString" LIKE '%DPI1%'
          OR T0."QString" LIKE '%ODPO%' OR T0."QString" LIKE '%DPO1%'
             THEN 'Pagos y Cobros'
        -- Contabilidad: plan de cuentas, asientos, periodos, reconciliaciones internas
        WHEN T0."QString" LIKE '%OACT%'
          OR T0."QString" LIKE '%OJDT%' OR T0."QString" LIKE '%JDT1%'
          OR T0."QString" LIKE '%OACP%' OR T0."QString" LIKE '%OFPR%'
          OR T0."QString" LIKE '%OBTD%'
          OR T0."QString" LIKE '%OITR%' OR T0."QString" LIKE '%ITR1%'
             THEN 'Contabilidad'
        -- Notas de crédito/débito (ventas y compras)
        WHEN T0."QString" LIKE '%ORIN%' OR T0."QString" LIKE '%RIN1%'
          OR T0."QString" LIKE '%ORPC%' OR T0."QString" LIKE '%RPC1%'
             THEN 'Notas Crédito/Débito'
        -- Cartera / Cuentas por cobrar y pagar (vistas personalizadas)
        WHEN T0."QString" LIKE '%SB1_VIEW_%CARTERA%'
          OR T0."QString" LIKE '%SB1_VIEW_%FLUJO%'
          OR T0."QString" LIKE '%SB1_VIEW_%MOROSIDAD%'
          OR T0."QString" LIKE '%CASHFLOW%'
             THEN 'Cartera / CxC / CxP'
        -- Proyectos: proyectos, etapas, centros de costo, vistas de proyectos
        WHEN T0."QString" LIKE '%OPRJ%' OR T0."QString" LIKE '%PRJ1%'
          OR T0."QString" LIKE '%OPMG%' OR T0."QString" LIKE '%PMG1%'
          OR T0."QString" LIKE '%OPRC%' OR T0."QString" LIKE '%PRC1%'
          OR T0."QString" LIKE '%SB1_VIEW_%PROYECTO%' OR T0."QString" LIKE '%SB1_VIEW_%PLANIFICACION%'
          OR T0."QString" LIKE '%SB1_VIEW_%INVERSION%'
             THEN 'Proyectos'
        -- Producción estándar B1 (órdenes de trabajo)
        WHEN T0."QString" LIKE '%OWOR%' OR T0."QString" LIKE '%WOR1%'
             THEN 'Producción SBO'
        -- RRHH
        WHEN T0."QString" LIKE '%OHEM%'
             THEN 'RRHH'
        -- Socios de negocio (OCRD/CRD1/OCRG/OCTG cuando no hay documento de venta/compra)
        WHEN T0."QString" LIKE '%OCRD%' OR T0."QString" LIKE '%CRD1%'
          OR T0."QString" LIKE '%OCRG%' OR T0."QString" LIKE '%OCTG%'
             THEN 'Socios de negocio'
        ELSE 'Otros'
    END                 AS "Area",
    T0."CreateDate"     AS "FechaCreacion",
    T0."UpdateDate"     AS "FechaActualizacion"
FROM EMPAQPLAST_PROD."OUQR" T0
LEFT JOIN EMPAQPLAST_PROD."OQCN" T1 ON T0."QCategory" = T1."CategoryId"
WHERE T0."CreateDate" >= '20230301'
  AND T1."CatName" IN ('IT_Consultas','PLG - Reportes BEAS','Reportes Beas TI','Alertas')
ORDER BY T0."CreateDate", T0."QName";
