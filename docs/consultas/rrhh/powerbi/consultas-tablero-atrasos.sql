-- ============================================================================
-- CONSULTAS POWER BI PARA vm_atrasos (TALENTO HUMANO)
-- ============================================================================
-- Base de datos: TH (sqlserver-etl-local-th)
-- Propósito: Consultas integrales para Dashboard de Atrasos, Faltas y No Cumplimiento
-- IMPORTANTE: Nombres de columnas FIJOS según definición de vista dbo.vm_atrasos
-- Creado: 2026-04-13
-- ============================================================================
-- COLUMNAS DE LA VISTA (NO MODIFICAR):
-- Codigo, Cedula, Nombre_Completo, Sucursal, Area, Departamento, Cargo,
-- Tipo_Permiso, Nombre_Tipo_Permiso, Fecha_Inicio, Fecha_Fin,
-- Hora_Inicio_Permiso, Hora_Fin_Permiso,
-- Timbrado_Inicio, Timbrado_Fin,
-- Minutos_Tiempo_Faltante, Horas_No_Cumple_Horario, Estado_Cumplimiento,
-- PeriodoEtiqueta, ModalidadNombre, Turno_Hora_Entrada, Turno_Hora_Salida,
-- Horas_Diarias_Turno, Trabaja_Sabado, Trabaja_Domingo, Descripcion_Jornada,
-- Codigo_Reporte, Descripcion_Reporte, Horas_Permiso_Calculadas, Ciudad_Sede
-- ============================================================================

-- ============================================================================
-- CONSULTA 1: RESUMEN EJECUTIVO DE ATRASOS, FALTAS Y NO CUMPLIMIENTO
-- Propósito: KPIs principales incluyendo "No cumple horario"
-- ============================================================================
SELECT
    -- Período actual (último 21-20)
    PeriodoEtiqueta AS periodo,
    Ciudad_Sede AS ciudad,

    -- Conteos principales
    COUNT(*) AS total_casos,
    COUNT(DISTINCT Codigo) AS empleados_afectados,

    -- Desglose por tipo de incidencia
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS total_faltas_injustificadas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS total_atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS total_no_cumple_horario,

    -- Horas perdidas
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS total_horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS total_horas_salida_anticipada,
    CAST(AVG(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS promedio_horas_por_caso,

    -- Minutos faltantes totales
    SUM(Minutos_Tiempo_Faltante) AS total_minutos_faltantes,

    -- Empleados críticos (más de 3 casos en el período)
    COUNT(DISTINCT CASE WHEN Codigo IN (
        SELECT Codigo
        FROM dbo.vm_atrasos v2
        WHERE v2.PeriodoEtiqueta = vm_atrasos.PeriodoEtiqueta
        GROUP BY Codigo
        HAVING COUNT(*) > 3
    ) THEN Codigo END) AS empleados_reincidentes

FROM dbo.vm_atrasos
WHERE PeriodoEtiqueta = (SELECT TOP 1 PeriodoEtiqueta FROM dbo.vm_atrasos ORDER BY Fecha_Inicio DESC)
GROUP BY PeriodoEtiqueta, Ciudad_Sede
ORDER BY ciudad;


-- ============================================================================
-- CONSULTA 2: TENDENCIA MENSUAL CON NO CUMPLIMIENTO
-- Propósito: Ver evolución mensual incluyendo salidas anticipadas
-- ============================================================================
SELECT
    YEAR(Fecha_Inicio) AS anio,
    MONTH(Fecha_Inicio) AS mes,
    DATENAME(MONTH, Fecha_Inicio) AS nombre_mes,
    Ciudad_Sede AS ciudad,

    COUNT(*) AS total_casos,
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS no_cumple_horario,
    
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS horas_salida_anticipada,
    SUM(Minutos_Tiempo_Faltante) AS minutos_faltantes,
    
    COUNT(DISTINCT Codigo) AS empleados_afectados,

    -- Tasa de ausentismo (faltas por empleado)
    CAST(SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(DISTINCT Codigo), 0) AS tasa_ausentismo,

    -- Tasa de no cumplimiento (salidas anticipadas por empleado)
    CAST(SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(DISTINCT Codigo), 0) AS tasa_no_cumplimiento

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(YEAR, -1, GETDATE())
GROUP BY YEAR(Fecha_Inicio), MONTH(Fecha_Inicio), DATENAME(MONTH, Fecha_Inicio), Ciudad_Sede
ORDER BY anio DESC, mes DESC, ciudad;


-- ============================================================================
-- CONSULTA 3: TOP EMPLEADOS CON INCUMPLIMIENTOS
-- Propósito: Identificar empleados reincidentes incluyendo salidas anticipadas
-- ============================================================================
SELECT TOP 30
    Codigo AS empleado_id,
    Cedula,
    Nombre_Completo AS nombre,
    Sucursal AS empresa,
    Area AS area,
    Departamento AS departamento,
    Cargo AS cargo,
    Ciudad_Sede AS ciudad,

    COUNT(*) AS total_casos,
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS total_faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS total_atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS total_no_cumple,

    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS total_horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS total_horas_no_cumple,
    SUM(Minutos_Tiempo_Faltante) AS total_minutos_faltantes,

    MIN(Fecha_Inicio) AS primer_caso,
    MAX(Fecha_Inicio) AS ultimo_caso,
    DATEDIFF(DAY, MIN(Fecha_Inicio), MAX(Fecha_Inicio)) AS dias_span,

    -- Clasificación de reincidencia (incluye no cumplimiento)
    CASE
        WHEN COUNT(*) >= 10 THEN 'CRÍTICO'
        WHEN COUNT(*) >= 5 THEN 'ALTO'
        WHEN COUNT(*) >= 3 THEN 'MODERADO'
        ELSE 'BAJO'
    END AS nivel_reincidencia

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -3, GETDATE())
GROUP BY
    Codigo, Cedula, Nombre_Completo, Sucursal, Area, Departamento, Cargo, Ciudad_Sede
ORDER BY total_faltas DESC, total_no_cumple DESC, total_casos DESC;


-- ============================================================================
-- CONSULTA 4: ANÁLISIS POR ÁREA CON NO CUMPLIMIENTO
-- Propósito: Identificar áreas con mayores problemas incluyendo salidas anticipadas
-- ============================================================================
SELECT
    Sucursal AS empresa,
    Area AS area,
    Departamento AS departamento,
    Descripcion_Jornada AS tipo_jornada,

    COUNT(DISTINCT Codigo) AS total_empleados_area,
    COUNT(*) AS total_casos,

    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS total_faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS total_atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS total_no_cumple_horario,

    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS total_horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS total_horas_salida_anticipada,
    SUM(Minutos_Tiempo_Faltante) AS total_minutos_faltantes,

    -- Tasa de incidentes por empleado
    CAST(COUNT(*) AS FLOAT) / NULLIF(COUNT(DISTINCT Codigo), 0) AS tasa_por_empleado,

    -- % de cada tipo de incidencia
    CAST(SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(*), 0) * 100 AS porcentaje_faltas,
    CAST(SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(*), 0) * 100 AS porcentaje_atrasos,
    CAST(SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(*), 0) * 100 AS porcentaje_no_cumple

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE())
GROUP BY Sucursal, Area, Departamento, Descripcion_Jornada
ORDER BY total_no_cumple_horario DESC, total_horas_perdidas DESC;


-- ============================================================================
-- CONSULTA 5: DISTRIBUCIÓN POR DÍA DE LA SEMANA CON NO CUMPLIMIENTO
-- Propósito: Identificar patrones diarios incluyendo salidas anticipadas
-- ============================================================================
SELECT
    DATEPART(WEEKDAY, Fecha_Inicio) AS numero_dia,
    DATENAME(WEEKDAY, Fecha_Inicio) AS nombre_dia,
    Ciudad_Sede AS ciudad,

    -- Conteo por tipo de incidencia
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS no_cumple_horario,

    COUNT(*) AS total_casos,
    COUNT(DISTINCT Codigo) AS empleados_afectados,
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS horas_salida_anticipada,

    -- % sobre total del día
    CAST(COUNT(*) AS FLOAT) / NULLIF(SUM(COUNT(*)) OVER(PARTITION BY DATEPART(WEEKDAY, Fecha_Inicio)), 0) * 100 AS porcentaje_dia

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -6, GETDATE())
GROUP BY DATEPART(WEEKDAY, Fecha_Inicio), DATENAME(WEEKDAY, Fecha_Inicio), Ciudad_Sede
ORDER BY numero_dia, ciudad;


-- ============================================================================
-- CONSULTA 6: ANÁLISIS POR TIPO DE JORNADA CON NO CUMPLIMIENTO
-- Propósito: Comparar rendimiento entre horarios incluyendo salidas anticipadas
-- ============================================================================
SELECT
    Descripcion_Jornada AS tipo_jornada,
    ModalidadNombre AS modalidad,
    Trabaja_Sabado AS trabaja_sabado,
    Trabaja_Domingo AS trabaja_domingo,

    COUNT(DISTINCT Codigo) AS empleados,
    COUNT(*) AS total_casos,

    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS no_cumple_horario,

    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS horas_salida_anticipada,
    SUM(Minutos_Tiempo_Faltante) AS minutos_faltantes,

    -- Promedio de casos por empleado
    CAST(COUNT(*) AS FLOAT) / NULLIF(COUNT(DISTINCT Codigo), 0) AS promedio_casos_por_empleado

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -3, GETDATE())
GROUP BY Descripcion_Jornada, ModalidadNombre, Trabaja_Sabado, Trabaja_Domingo
ORDER BY no_cumple_horario DESC, horas_perdidas DESC;


-- ============================================================================
-- CONSULTA 7: DISTRIBUCIÓN DE HORAS PERDIDAS Y NO CUMPLIMIENTO
-- Propósito: Entender impacto en productividad incluyendo salidas anticipadas
-- ============================================================================
SELECT
    Ciudad_Sede AS ciudad,
    Area AS area,

    -- Rangos de horas perdidas
    SUM(CASE WHEN Horas_Permiso_Calculadas < 2 THEN 1 ELSE 0 END) AS casos_menos_2h,
    SUM(CASE WHEN Horas_Permiso_Calculadas BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS casos_2_4h,
    SUM(CASE WHEN Horas_Permiso_Calculadas BETWEEN 4 AND 8 THEN 1 ELSE 0 END) AS casos_4_8h,
    SUM(CASE WHEN Horas_Permiso_Calculadas > 8 THEN 1 ELSE 0 END) AS casos_mas_8h,

    -- Rangos de horas no cumplidas (salida anticipada)
    SUM(CASE WHEN Horas_No_Cumple_Horario > 0 AND Horas_No_Cumple_Horario < 1 THEN 1 ELSE 0 END) AS no_cumple_menos_1h,
    SUM(CASE WHEN Horas_No_Cumple_Horario BETWEEN 1 AND 2 THEN 1 ELSE 0 END) AS no_cumple_1_2h,
    SUM(CASE WHEN Horas_No_Cumple_Horario BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS no_cumple_2_4h,
    SUM(CASE WHEN Horas_No_Cumple_Horario > 4 THEN 1 ELSE 0 END) AS no_cumple_mas_4h,

    COUNT(*) AS total_casos,
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS total_horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS total_horas_no_cumple,

    -- Costo estimado (asumiendo costo promedio $5/hora - AJUSTAR)
    CAST((SUM(Horas_Permiso_Calculadas) + SUM(Horas_No_Cumple_Horario)) * 5.00 AS DECIMAL(10,2)) AS costo_estimado

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE())
GROUP BY Ciudad_Sede, Area
ORDER BY total_horas_no_cumple DESC, total_horas_perdidas DESC;


-- ============================================================================
-- CONSULTA 8: REPORTE DETALLADO DIARIO CON NO CUMPLIMIENTO
-- Propósito: Vista diaria para RRHH incluyendo salidas anticipadas
-- ============================================================================
SELECT
    Fecha_Inicio AS fecha,
    DATENAME(WEEKDAY, Fecha_Inicio) AS dia_semana,
    Codigo AS empleado_id,
    Cedula,
    Nombre_Completo AS nombre,
    Area AS area,
    Departamento AS departamento,
    Cargo AS cargo,

    Tipo_Permiso AS tipo,
    Estado_Cumplimiento AS estado,
    
    CASE
        WHEN Tipo_Permiso = 'FI' THEN 'Falta Injustificada'
        WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 'No Cumple Horario'
        ELSE 'Atraso'
    END AS tipo_descripcion,

    Hora_Inicio_Permiso AS hora_entrada_real,
    Hora_Fin_Permiso AS hora_salida_real,
    Timbrado_Inicio AS timbrado_entrada,
    Timbrado_Fin AS timbrado_salida,
    Turno_Hora_Entrada AS hora_programada_entrada,
    Turno_Hora_Salida AS hora_programada_salida,

    CAST(Horas_Permiso_Calculadas AS DECIMAL(10,2)) AS horas_perdidas,
    CAST(Horas_No_Cumple_Horario AS DECIMAL(10,2)) AS horas_no_cumple,
    Minutos_Tiempo_Faltante AS minutos_faltantes,
    
    ModalidadNombre AS modalidad,
    Descripcion_Jornada AS tipo_jornada,
    Ciudad_Sede AS ciudad

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(DAY, -7, GETDATE())
ORDER BY Fecha_Inicio DESC, CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 2 END, Nombre_Completo;


-- ============================================================================
-- CONSULTA 9: COMPARATIVO UIO vs GYE CON NO CUMPLIMIENTO
-- Propósito: Benchmark entre sedes incluyendo salidas anticipadas
-- ============================================================================
SELECT
    Ciudad_Sede AS ciudad,
    YEAR(Fecha_Inicio) AS anio,
    MONTH(Fecha_Inicio) AS mes,
    DATENAME(MONTH, Fecha_Inicio) AS nombre_mes,

    COUNT(DISTINCT Codigo) AS empleados_con_incidentes,
    COUNT(*) AS total_incidentes,

    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS no_cumple_horario,

    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_perdidas,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS horas_salida_anticipada,
    SUM(Minutos_Tiempo_Faltante) AS minutos_faltantes,

    -- Tasas por empleado
    CAST(SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(DISTINCT Codigo), 0) AS tasa_ausentismo,
    CAST(SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(DISTINCT Codigo), 0) AS tasa_no_cumplimiento,

    -- % sobre total
    CAST(COUNT(*) AS FLOAT) / NULLIF(SUM(COUNT(*)) OVER(PARTITION BY YEAR(Fecha_Inicio), MONTH(Fecha_Inicio)), 0) * 100 AS porcentaje_sobre_total

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(YEAR, -1, GETDATE())
GROUP BY Ciudad_Sede, YEAR(Fecha_Inicio), MONTH(Fecha_Inicio), DATENAME(MONTH, Fecha_Inicio)
ORDER BY anio DESC, mes DESC, ciudad;


-- ============================================================================
-- CONSULTA 10: EMPLEADOS CON MEJORA O EMPEORAMIENTO (CON NO CUMPLIMIENTO)
-- Propósito: Identificar tendencias incluyendo salidas anticipadas
-- ============================================================================
WITH Comparativa_Periodos AS (
    SELECT
        Codigo,
        Cedula,
        Nombre_Completo,
        Area,
        Departamento,
        Ciudad_Sede,

        -- Período anterior
        SUM(CASE WHEN Fecha_Inicio >= DATEADD(MONTH, -2, GETDATE())
                 AND Fecha_Inicio < DATEADD(MONTH, -1, GETDATE())
                 THEN 1 ELSE 0 END) AS casos_mes_anterior,

        -- Período actual
        SUM(CASE WHEN Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE())
                 THEN 1 ELSE 0 END) AS casos_mes_actual,

        SUM(CASE WHEN Fecha_Inicio >= DATEADD(MONTH, -2, GETDATE())
                 AND Fecha_Inicio < DATEADD(MONTH, -1, GETDATE())
                 THEN Horas_Permiso_Calculadas ELSE 0 END) AS horas_mes_anterior,

        SUM(CASE WHEN Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE())
                 THEN Horas_Permiso_Calculadas ELSE 0 END) AS horas_mes_actual,

        -- No cumplimiento mes anterior
        SUM(CASE WHEN Fecha_Inicio >= DATEADD(MONTH, -2, GETDATE())
                 AND Fecha_Inicio < DATEADD(MONTH, -1, GETDATE())
                 AND Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS no_cumple_mes_anterior,

        -- No cumplimiento mes actual
        SUM(CASE WHEN Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE())
                 AND Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS no_cumple_mes_actual

    FROM dbo.vm_atrasos
    WHERE Fecha_Inicio >= DATEADD(MONTH, -2, GETDATE())
    GROUP BY Codigo, Cedula, Nombre_Completo, Area, Departamento, Ciudad_Sede
)
SELECT
    Codigo AS empleado_id,
    Cedula,
    Nombre_Completo AS nombre,
    Area AS area,
    Departamento AS departamento,
    Ciudad_Sede AS ciudad,
    casos_mes_anterior,
    casos_mes_actual,
    CAST(horas_mes_anterior AS DECIMAL(10,2)) AS horas_mes_anterior,
    CAST(horas_mes_actual AS DECIMAL(10,2)) AS horas_mes_actual,
    no_cumple_mes_anterior,
    no_cumple_mes_actual,

    casos_mes_actual - casos_mes_anterior AS diferencia_casos,
    CAST(horas_mes_actual - horas_mes_anterior AS DECIMAL(10,2)) AS diferencia_horas,
    no_cumple_mes_actual - no_cumple_mes_anterior AS diferencia_no_cumple,

    -- Clasificación de tendencia
    CASE
        WHEN casos_mes_actual = 0 AND casos_mes_anterior > 0 THEN 'MEJORÓ (Cero casos)'
        WHEN casos_mes_actual < casos_mes_anterior THEN 'MEJORÓ'
        WHEN casos_mes_actual > casos_mes_anterior THEN 'EMPEORÓ'
        ELSE 'SIN CAMBIOS'
    END AS tendencia

FROM Comparativa_Periodos
WHERE casos_mes_anterior > 0 OR casos_mes_actual > 0
ORDER BY
    CASE
        WHEN casos_mes_actual > casos_mes_anterior THEN 1
        WHEN casos_mes_actual < casos_mes_anterior THEN 3
        ELSE 2
    END,
    diferencia_casos DESC;


-- ============================================================================
-- CONSULTA 11: ANÁLISIS DE FALTAS INJUSTIFICADAS (FI)
-- Propósito: Profundizar en faltas para plan de acción
-- ============================================================================
SELECT
    Codigo AS empleado_id,
    Cedula,
    Nombre_Completo AS nombre,
    Area AS area,
    Departamento AS departamento,
    Cargo AS cargo,
    Ciudad_Sede AS ciudad,

    COUNT(*) AS total_faltas,
    MIN(Fecha_Inicio) AS primera_falta,
    MAX(Fecha_Inicio) AS ultima_falta,
    DATEDIFF(DAY, MIN(Fecha_Inicio), MAX(Fecha_Inicio)) AS dias_span,

    -- Faltas agrupadas por día de semana
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 2 THEN 1 ELSE 0 END) AS faltas_lunes,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 3 THEN 1 ELSE 0 END) AS faltas_martes,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 4 THEN 1 ELSE 0 END) AS faltas_miercoles,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 5 THEN 1 ELSE 0 END) AS faltas_jueves,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 6 THEN 1 ELSE 0 END) AS faltas_viernes,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) IN (7, 1) THEN 1 ELSE 0 END) AS faltas_fds,

    -- Horas totales perdidas por faltas
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_totales_perdidas,

    -- Nivel de criticidad
    CASE
        WHEN COUNT(*) >= 5 THEN 'CRÍTICO - Accion inmediata'
        WHEN COUNT(*) >= 3 THEN 'ALTO - Llamar atención'
        WHEN COUNT(*) >= 2 THEN 'MODERADO - Seguimiento'
        ELSE 'BAJO - Observar'
    END AS nivel_critico

FROM dbo.vm_atrasos
WHERE Tipo_Permiso = 'FI'
  AND Fecha_Inicio >= DATEADD(MONTH, -3, GETDATE())
GROUP BY Codigo, Cedula, Nombre_Completo, Area, Departamento, Cargo, Ciudad_Sede
HAVING COUNT(*) >= 2
ORDER BY total_faltas DESC;


-- ============================================================================
-- CONSULTA 12: TOP EMPLEADOS CON SALIDA ANTICIPADA (NO CUMPLE HORARIO)
-- Propósito: Identificar empleados que salen antes de la hora
-- ============================================================================
SELECT TOP 30
    Codigo AS empleado_id,
    Cedula,
    Nombre_Completo AS nombre,
    Area AS area,
    Departamento AS departamento,
    Cargo AS cargo,
    Ciudad_Sede AS ciudad,
    Descripcion_Jornada AS tipo_jornada,

    COUNT(*) AS total_no_cumple,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS total_horas_no_cumple,
    CAST(AVG(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS promedio_horas_no_cumple,
    SUM(Minutos_Tiempo_Faltante) AS total_minutos_faltantes,

    MIN(Fecha_Inicio) AS primera_vez,
    MAX(Fecha_Inicio) AS ultima_vez,
    DATEDIFF(DAY, MIN(Fecha_Inicio), MAX(Fecha_Inicio)) AS dias_span,

    -- Distribución por día
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 2 THEN 1 ELSE 0 END) AS no_cumple_lunes,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 3 THEN 1 ELSE 0 END) AS no_cumple_martes,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 4 THEN 1 ELSE 0 END) AS no_cumple_miercoles,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 5 THEN 1 ELSE 0 END) AS no_cumple_jueves,
    SUM(CASE WHEN DATEPART(WEEKDAY, Fecha_Inicio) = 6 THEN 1 ELSE 0 END) AS no_cumple_viernes,

    -- Frecuencia
    CASE
        WHEN COUNT(*) >= 10 THEN 'CRÍTICO - Reincidente'
        WHEN COUNT(*) >= 5 THEN 'ALTO - Accion requerida'
        WHEN COUNT(*) >= 3 THEN 'MODERADO - Seguimiento'
        ELSE 'BAJO - Observar'
    END AS nivel_frecuencia

FROM dbo.vm_atrasos
WHERE Estado_Cumplimiento = 'No Cumple Horario'
  AND Fecha_Inicio >= DATEADD(MONTH, -3, GETDATE())
GROUP BY Codigo, Cedula, Nombre_Completo, Area, Departamento, Cargo, Ciudad_Sede, Descripcion_Jornada
HAVING COUNT(*) >= 2
ORDER BY total_horas_no_cumple DESC, total_no_cumple DESC;


-- ============================================================================
-- CONSULTA 13: REPORTE PARA NÓMINA (Período 21-20) CON NO CUMPLIMIENTO
-- Propósito: Datos listos para descuento en nómina incluyendo salidas anticipadas
-- ============================================================================
SELECT
    Codigo AS empleado_id,
    Cedula,
    Nombre_Completo AS nombre,
    Area AS area,
    Cargo AS cargo,
    Ciudad_Sede AS ciudad,

    -- Período actual
    (SELECT TOP 1 PeriodoEtiqueta
     FROM dbo.vm_atrasos v2
     WHERE v2.PeriodoEtiqueta LIKE '%/' + CAST(YEAR(GETDATE()) AS VARCHAR)
     ORDER BY Fecha_Inicio DESC) AS periodo_nomina,

    -- Resumen de incidencias
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS total_faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS total_atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS total_no_cumple,
    COUNT(*) AS total_incidencias,

    -- Horas para descuento
    CAST(SUM(CASE WHEN Tipo_Permiso = 'FI' THEN Horas_Permiso_Calculadas ELSE 0 END) AS DECIMAL(10,2)) AS horas_faltas,
    CAST(SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN Horas_Permiso_Calculadas ELSE 0 END) AS DECIMAL(10,2)) AS horas_atrasos,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS horas_no_cumple,
    CAST(SUM(Horas_Permiso_Calculadas) + SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS horas_totales,

    -- Días de descuento (faltas completas = 8h cada una)
    CAST(SUM(CASE WHEN Tipo_Permiso = 'FI' THEN Horas_Permiso_Calculadas / 8.0 ELSE 0 END) AS DECIMAL(10,2)) AS dias_faltas,
    CAST(SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN Horas_No_Cumple_Horario / 8.0 ELSE 0 END) AS DECIMAL(10,2)) AS dias_no_cumple,

    -- Observaciones
    STRING_AGG(
        CONVERT(VARCHAR(10), Fecha_Inicio, 103) + ' (' +
        CASE
            WHEN Tipo_Permiso = 'FI' THEN 'FI'
            WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 'NC'
            ELSE 'A'
        END + ')',
        ', '
    ) WITHIN GROUP (ORDER BY Fecha_Inicio) AS detalle_fechas

FROM dbo.vm_atrasos
WHERE PeriodoEtiqueta = (
    SELECT TOP 1 PeriodoEtiqueta
    FROM dbo.vm_atrasos
    ORDER BY Fecha_Inicio DESC
)
GROUP BY Codigo, Cedula, Nombre_Completo, Area, Cargo, Ciudad_Sede
ORDER BY horas_totales DESC;


-- ============================================================================
-- CONSULTA 14: HEATMAP DE ATRASOS Y SALIDAS ANTICIPADAS POR HORA Y DÍA
-- Propósito: Identificar patrones horarios de atrasos y salidas anticipadas
-- ============================================================================
SELECT
    DATEPART(WEEKDAY, Fecha_Inicio) AS dia_semana_num,
    DATENAME(WEEKDAY, Fecha_Inicio) AS dia_semana,
    
    -- Hora de entrada para atrasos
    CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario'
         THEN DATEPART(HOUR, CAST(Hora_Inicio_Permiso AS TIME))
         ELSE NULL
    END AS hora_entrada_atraso,
    
    -- Horas de salida anticipada
    CAST(Horas_No_Cumple_Horario AS DECIMAL(10,2)) AS horas_salida_anticipada,

    COUNT(*) AS cantidad_casos,
    COUNT(DISTINCT Codigo) AS empleados,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS casos_no_cumple,
    CAST(AVG(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS promedio_horas

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -3, GETDATE())
ORDER BY dia_semana_num, horas_salida_anticipada DESC;


-- ============================================================================
-- CONSULTA 15: RESUMEN EJECUTIVO GERENCIAL CON NO CUMPLIMIENTO
-- Propósito: Una sola fila con todos los KPIs para gerencia
-- ============================================================================
SELECT
    GETDATE() AS fecha_reporte,

    -- Período
    (SELECT TOP 1 PeriodoEtiqueta FROM dbo.vm_atrasos ORDER BY Fecha_Inicio DESC) AS periodo_actual,

    -- Empleados
    COUNT(DISTINCT Codigo) AS empleados_con_incidencias,
    (SELECT COUNT(*) FROM ONLYCONTROL.dbo.NOMINA WHERE NOMINA_FSAL IS NULL) AS empleados_activos,

    -- Tasas
    CAST(COUNT(DISTINCT Codigo) AS FLOAT) /
        NULLIF((SELECT COUNT(*) FROM ONLYCONTROL.dbo.NOMINA WHERE NOMINA_FSAL IS NULL), 0) * 100
        AS porcentaje_empleados_con_incidencias,

    -- Incidencias desglosadas
    COUNT(*) AS total_incidencias,
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN 1 ELSE 0 END) AS atrasos,
    SUM(CASE WHEN Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS no_cumple_horario,

    -- Horas
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_totales,
    CAST(SUM(CASE WHEN Tipo_Permiso = 'FI' THEN Horas_Permiso_Calculadas ELSE 0 END) AS DECIMAL(10,2)) AS horas_faltas,
    CAST(SUM(CASE WHEN Tipo_Permiso = 'A' AND Estado_Cumplimiento = 'Cumple Horario' THEN Horas_Permiso_Calculadas ELSE 0 END) AS DECIMAL(10,2)) AS horas_atrasos,
    CAST(SUM(Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS horas_salida_anticipada,

    -- Minutos faltantes
    SUM(Minutos_Tiempo_Faltante) AS total_minutos_faltantes,

    -- Promedios
    CAST(AVG(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS promedio_horas_caso,

    -- Reincidentes
    COUNT(DISTINCT CASE WHEN Codigo IN (
        SELECT Codigo FROM dbo.vm_atrasos
        WHERE Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE())
        GROUP BY Codigo HAVING COUNT(*) >= 3
    ) THEN Codigo END) AS empleados_reincidentes,

    -- Comparativa mes anterior
    (SELECT COUNT(*) FROM dbo.vm_atrasos
     WHERE Fecha_Inicio >= DATEADD(MONTH, -2, GETDATE()) AND Fecha_Inicio < DATEADD(MONTH, -1, GETDATE())
    ) AS casos_mes_anterior,
    COUNT(*) AS casos_mes_actual

FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE());


-- ============================================================================
-- NOTAS PARA IMPLEMENTACIÓN EN POWER BI:
-- ============================================================================
-- 1. La vista vm_atrasos TIENE estas columnas clave:
--    - Tipo_Permiso: 'FI' (Falta Injustificada) o 'A' (Atraso)
--    - Estado_Cumplimiento: 'No Cumple Horario' o 'Cumple Horario'
--    - Horas_No_Cumple_Horario: Horas de salida anticipada
--    - Minutos_Tiempo_Faltante: Minutos faltantes totales
--    - Timbrado_Inicio/Timbrado_Fin: Marcado real del biométrico
--
-- 2. Páginas recomendadas:
--    - Dashboard Ejecutivo (Consulta 1, 15)
--    - Tendencia Mensual (Consulta 2)
--    - Top Empleados Críticos (Consulta 3, 12)
--    - Análisis por Área (Consulta 4)
--    - Patrones por Día/Hora (Consulta 5, 14)
--    - Comparativo UIO vs GYE (Consulta 9)
--    - Reporte para Nómina (Consulta 13)
--
-- 3. Crear medidas DAX:
--    - Tasa Ausentismo = Faltas / Empleados Activos * 100
--    - Tasa No Cumplimiento = No Cumple / Empleados Activos * 100
--    - Costo Horas = (Horas Totales + Horas Salida Anticipada) * Costo/Hora
--    - % Reincidencia = Empleados Reincidentes / Total Empleados * 100
--
-- 4. Slicers recomendados:
--    - Período (21-20)
--    - Ciudad (UIO/GYE)
--    - Área/Departamento
--    - Tipo de Jornada
--    - Tipo Permiso (FI/A)
--    - Estado Cumplimiento (Cumple/No Cumple)
-- ============================================================================
