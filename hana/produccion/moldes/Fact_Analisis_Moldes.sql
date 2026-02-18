-- EMPAQPLAST_PROD.SB1_VIEW_ANALISIS_MOLDES source
-- Si se agrega T1."OT" al SELECT/GROUP BY: "No. Ordenes" debe ser COUNT(DISTINCT T1."OT")
-- para que no muestre el nº de filas del JOIN (ej. 114 registros de T3) en vez del nº de órdenes.

--CREATE VIEW EMPAQPLAST_PROD.SB1_VIEW_ANALISIS_MOLDES AS
SELECT
	T1."OT",
    YEAR(T1."FECHA_INICIO") AS "Anio",
    MONTH(T1."FECHA_INICIO") AS "Mes",
    T0."Cod_Articulo",
    T1."MOLDE_CODIGO",
    T1."AREA",
    T0."U_EMPA_COD_FRACTTAL",
    T0."U_EMPA_COD_BEAS",
    T0."U_EMPA_COD_RECURSO",
    T0."Descripcion",
    T0."Vida_Util_Meses",
    T0."Resto_Vida_Util_Meses_Corridos",
    T0."Resto_Vida_Util_Dias",
    T0."Numero_de_Amortizaciones_P",
    T0."Procedencia",
    T0."Marca",
    T0."Modelo",
    T0."Serie",
    MAX(T1."NO_CAVIDADE_ESTANDAR") AS "Cavidades Estandar",
    MAX(COALESCE(T1."CAVIDADES_HABILES_1", 0)) AS "Maximo Cavidades Habiles",
    MIN(COALESCE(T1."CAVIDADES_HABILES_1", 0)) AS "Minimo Cavidades Habiles",
    MAX(COALESCE(T3."Cavidades_Habiles", 0)) AS "Maximo Cavidades Reales",
    MIN(COALESCE(T3."Cavidades_Habiles", 0)) AS "Min Cavidades Reales",
    MAX(T1."CICLO_MOLDE") AS "Ciclo Estandar",  -- Agregado por seguridad
    AVG(COALESCE(T3."Tiempo_Ciclo_Real", 0)) AS "Ciclo Real",
    COUNT(T2."GRUNDID") AS "No Fallas Moldes",
    COUNT(DISTINCT T1."OT") AS "No. Ordenes"
FROM
    SB1_VIEW_ACTIVOS_FIJOS T0
LEFT JOIN SB1_VIEW_BEAS_RESUMEN_OF T1 
    ON T0."U_EMPA_COD_FRACTTAL" = T1."MOLDE_CODIGO"
LEFT JOIN BEAS_PARADAS T2 
    ON T1."OT" = T2."OT" AND T2."GRUNDID" = 'Moldes'
LEFT JOIN BEAS_TIEMPOS_PRODUCCION T3 
    ON T1."OT" = T3."OT"
WHERE 
  T1."MOLDE_CODIGO" IN (
'MOLINY0867',
'MOLINY1086',
'MOLINY1102',
'MOLINY1233',
'MOLINY1245',
'MOLINY1426')
--AND T1."OT" = 114
 
GROUP BY
    T0."Cod_Articulo",
    T1."MOLDE_CODIGO",
    T0."U_EMPA_COD_FRACTTAL",
    T0."U_EMPA_COD_BEAS",
    T0."U_EMPA_COD_RECURSO",
    T0."Descripcion",
    T0."Vida_Util_Meses",
    T0."Resto_Vida_Util_Meses_Corridos",
    T0."Resto_Vida_Util_Dias",
    T0."Numero_de_Amortizaciones_P",
    T0."Procedencia",
    T0."Marca",
    T0."Modelo",
    T0."Serie",
    T1."AREA",
    T1."OT",
	 YEAR(T1."FECHA_INICIO"),
    MONTH(T1."FECHA_INICIO") ORDER BY "Anio","Mes" DESC;


-- =============================================================================
-- DIAGNÓSTICO: por qué "Ciclo Real" = 0 (no hay registro de ciclo real)
-- =============================================================================
-- Ciclo Real sale de BEAS_TIEMPOS_PRODUCCION (T3). Si una OT no tiene ninguna
-- fila en esa tabla, el LEFT JOIN no trae datos y AVG(COALESCE(...,0)) = 0.
-- Esta consulta lista las OTs que SÍ están en órdenes (T1) pero NO tienen
-- ningún registro en BEAS_TIEMPOS_PRODUCCION → por eso Ciclo Real = 0.
-- =============================================================================
SELECT
    T1."OT",
    T1."MOLDE_CODIGO",
    T1."FECHA_INICIO",
    T1."ESTADO_ORDEN",
    YEAR(T1."FECHA_INICIO") AS "Anio",
    MONTH(T1."FECHA_INICIO") AS "Mes",
    'Sin registros en BEAS_TIEMPOS_PRODUCCION' AS "Motivo_Ciclo_Real_0"
FROM EMPAQPLAST_PROD.SB1_VIEW_BEAS_RESUMEN_OF T1
WHERE NOT EXISTS (
    SELECT 1 FROM EMPAQPLAST_PROD.BEAS_TIEMPOS_PRODUCCION T3
    WHERE T3."OT" = T1."OT"
)

ORDER BY T1."OT";