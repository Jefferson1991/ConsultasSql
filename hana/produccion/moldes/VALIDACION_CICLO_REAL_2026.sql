-- =============================================================================
-- VALIDACIÓN CICLO REAL 2026 - Ejecutar en DBeaver (misma conexión que usas)
-- Si aquí ves Ciclo Real > 0 pero en tu consulta ves 0, quita el filtro "Ciclo Real IN (0.000)".
-- =============================================================================

-- 1) CONSULTA A LA VISTA SIN NINGÚN FILTRO EN Ciclo Real
--    (No apliques filtro en la columna "Ciclo Real" en la rejilla)
SELECT "OT","Anio", "Mes", "MOLDE_CODIGO", "Cod_Articulo", "Ciclo Real", "No. Ordenes"
FROM EMPAQPLAST_PROD."SB1_VIEW_ANALISIS_MOLDES"
WHERE "Anio" = 2026 AND  "Ciclo Real" IN (0)
ORDER BY "Mes", "MOLDE_CODIGO", "Cod_Articulo";


-- 2) DIAGNÓSTICO: moldes 2026 y si tienen registros en BEAS_TIEMPOS_PRODUCCION
--    RegsT3 > 0 = hay ciclo; la vista debería mostrar Ciclo Real > 0 para ese mes
SELECT
	T1."OT",
    T1."MOLDE_CODIGO",
    YEAR(T1."FECHA_INICIO") AS Anio,
    MONTH(T1."FECHA_INICIO") AS Mes,
    COUNT(DISTINCT T1."OT") AS OTs,
    SUM(CASE WHEN T3."OT" IS NOT NULL THEN 1 ELSE 0 END) AS RegsT3,
    AVG(T3."Tiempo_Ciclo_Real") AS CicloRealDirecto
FROM EMPAQPLAST_PROD."SB1_VIEW_ACTIVOS_FIJOS" T0
JOIN EMPAQPLAST_PROD."SB1_VIEW_BEAS_RESUMEN_OF" T1
    ON T0."U_EMPA_COD_BEAS" = T1."MOLDE_CODIGO"
LEFT JOIN EMPAQPLAST_PROD."BEAS_TIEMPOS_PRODUCCION" T3
    ON T1."OT" = T3."OT"
WHERE YEAR(T1."FECHA_INICIO") = 2026
GROUP BY T1."OT",T1."MOLDE_CODIGO", YEAR(T1."FECHA_INICIO"), MONTH(T1."FECHA_INICIO")
ORDER BY Mes, T1."MOLDE_CODIGO";


-- 3) SOLO FILAS CON Ciclo Real > 0 (para ver que sí existen)
SELECT "Anio", "Mes", "MOLDE_CODIGO", "Ciclo Real", "No. Ordenes"
FROM EMPAQPLAST_PROD."SB1_VIEW_ANALISIS_MOLDES"
WHERE "Anio" = 2026 AND "Ciclo Real" > 0
ORDER BY "Mes", "MOLDE_CODIGO";
