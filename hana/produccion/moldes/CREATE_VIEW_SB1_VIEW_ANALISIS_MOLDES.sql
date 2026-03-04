ALTER VIEW SB1_VIEW_ANALISIS_MOLDES AS
SELECT
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
    COUNT(T1."OT") AS "No. Ordenes"
FROM
    SB1_VIEW_ACTIVOS_FIJOS T0
LEFT JOIN SB1_VIEW_BEAS_RESUMEN_OF T1 
    ON T0."U_EMPA_COD_FRACTTAL" = T1."MOLDE_CODIGO"
LEFT JOIN BEAS_PARADAS T2 
    ON T1."OT" = T2."OT" AND T2."GRUNDID" = 'Moldes'
LEFT JOIN BEAS_TIEMPOS_PRODUCCION T3 
    ON T1."OT" = T3."OT"
WHERE T3."Tiempo_Ciclo_Real" > 0
  --T1."MOLDE_CODIGO" = 'MOLINY1414'  -- opcional, descomenta si lo necesitas
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
	 YEAR(T1."FECHA_INICIO"),
    MONTH(T1."FECHA_INICIO") ORDER BY "Anio","Mes" DESC;