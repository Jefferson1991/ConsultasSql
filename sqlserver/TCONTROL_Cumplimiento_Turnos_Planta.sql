-- =============================================================
-- Descripcion : Cumplimiento de turnos planificados vs asistencia real
-- Fuente 1    : dispensarioMedico.dbo.cargaTurnosSLPC (planificacion)
-- Fuente 2    : ONLYC.TCONTROL.dbo.TBL_ASISTENCIA    (asistencia real)
-- Servidor    : 192.168.20.15 (SRV-APP\SQLEXPRESS)
-- Linked Srv  : ONLYC -> SRV-BIOM-001\SQLEXPRESS2008R2
-- Autor       : Jefferson Vasconez
-- Fecha       : 2026-03-08
--
-- FILTRO DE FECHA: cambiar los valores de @FechaInicio y @FechaFin
-- =============================================================

DECLARE @FechaInicio DATE = '2026-02-01'
DECLARE @FechaFin    DATE = '2026-02-28'

-- -------------------------------------------------------
-- DETALLE: un registro por empleado por dia trabajado
-- -------------------------------------------------------
SELECT
    -- Identificacion
    S.nombresSLPC                       AS Nombre_Empleado,
    E.NOMINA_ID                         AS Codigo_Empleado,
    E.NOMINA_COD                        AS Cedula,
    E.DEP_NOM                           AS Departamento,
    S.coordinadorSLPC                   AS Coordinador,

    -- Planificacion del turno
    S.fechaRegistroSLPC                 AS Semana_Planificada,
    REPLACE(S.horarioSLPC, ' ', '')     AS Turno_Planificado,
    S.maquinaSLPC                       AS Maquina_Planificada,
    S.actividadSLPC                     AS Actividad_Planificada,

    -- Fecha del dia trabajado
    CAST(A.Fecha_Ingreso AS DATE)       AS Fecha,

    -- Marcaciones reales del biomentrico
    A.Hora_Ingreso                      AS Marcacion_Inicio_Jornada,
    A.Hora_Salida                       AS Marcacion_Fin_Jornada,

    -- Horas trabajadas
    DATEPART(hour,   A.Horas_Laboradas)                                 AS Horas_Trabajadas,
    DATEPART(minute, A.Horas_Laboradas)                                 AS Minutos_Trabajados,
    CAST(
        DATEPART(hour,   A.Horas_Laboradas) +
        DATEPART(minute, A.Horas_Laboradas) / 60.0
    AS DECIMAL(5,2))                    AS Horas_Trabajadas_Decimal,

    -- Horas planificadas segun turno (12h turno diurno/nocturno estandar)
    CASE
        WHEN REPLACE(S.horarioSLPC,' ','') IN ('06:00/18:00','18:00/06:00') THEN 12.00
        WHEN REPLACE(S.horarioSLPC,' ','') = '06:00/14:00'                  THEN  8.00
        WHEN REPLACE(S.horarioSLPC,' ','') = '14:00/00:00'                  THEN  8.00
        WHEN REPLACE(S.horarioSLPC,' ','') = '22:00/06:00'                  THEN  8.00
        ELSE NULL
    END                                 AS Horas_Planificadas,

    -- Diferencia horas trabajadas vs planificadas
    CAST(
        DATEPART(hour,   A.Horas_Laboradas) +
        DATEPART(minute, A.Horas_Laboradas) / 60.0
    AS DECIMAL(5,2)) -
    CASE
        WHEN REPLACE(S.horarioSLPC,' ','') IN ('06:00/18:00','18:00/06:00') THEN 12.00
        WHEN REPLACE(S.horarioSLPC,' ','') IN ('06:00/14:00','14:00/00:00','22:00/06:00') THEN 8.00
        ELSE NULL
    END                                 AS Diferencia_Horas,

    -- Atrasos
    A.min_AT                            AS Min_Atraso,
    A.Atraso_con_gracia,
    A.min_SA                            AS Min_Salida_Anticipada,

    -- Novedades y estado
    A.Novedad_Entrada,
    A.Novedad_Salida,
    A.Estado,

    -- Justificaciones
    A.Justifica                         AS Justif_Entrada,
    A.Motivo                            AS Motivo_Entrada,
    A.justifica_sal                     AS Justif_Salida,
    A.motivo_sal                        AS Motivo_Salida,

    -- Cumplimiento del dia
    CASE
        WHEN A.EMP_ID IS NULL THEN 'AUSENTE'
        WHEN A.min_AT > 0     THEN 'ATRASO'
        ELSE                       'A TIEMPO'
    END                                 AS Cumplimiento,

    CASE WHEN A.EMP_ID IS NULL THEN 0 ELSE 1 END AS Asistio

FROM dispensarioMedico.dbo.cargaTurnosSLPC S

INNER JOIN ONLYC.TCONTROL.dbo.ViewEmpleados E
    ON E.NOMINA_APE + ' ' + E.NOMINA_NOM = S.nombresSLPC

LEFT JOIN ONLYC.TCONTROL.dbo.TBL_ASISTENCIA A
    ON  A.EMP_ID = E.NOMINA_ID
    -- La fecha de asistencia debe caer dentro del rango semanal planificado
    AND CAST(A.Fecha_Ingreso AS DATE) BETWEEN
            CONVERT(DATE, LEFT(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) - 1), 103)
        AND CONVERT(DATE, SUBSTRING(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) + 3, 10), 103)
    -- Y dentro del rango de fechas solicitado
    AND CAST(A.Fecha_Ingreso AS DATE) BETWEEN @FechaInicio AND @FechaFin

-- Solo traer planificaciones que estén dentro del rango de fechas
WHERE
    CONVERT(DATE, LEFT(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) - 1), 103) <= @FechaFin
    AND
    CONVERT(DATE, SUBSTRING(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) + 3, 10), 103) >= @FechaInicio

ORDER BY S.nombresSLPC, CAST(A.Fecha_Ingreso AS DATE);


-- =============================================================
-- RESUMEN: por empleado, dias asistidos, horas y cumplimiento
-- =============================================================

DECLARE @FechaInicio DATE = '2026-02-01'
DECLARE @FechaFin    DATE = '2026-02-28'

SELECT
    S.nombresSLPC                           AS Nombre_Empleado,
    E.NOMINA_COD                            AS Cedula,
    S.coordinadorSLPC                       AS Coordinador,
    COUNT(DISTINCT CAST(A.Fecha_Ingreso AS DATE))               AS Dias_Asistidos,
    SUM(CASE WHEN A.EMP_ID IS NULL THEN 1 ELSE 0 END)          AS Dias_Ausente,
    SUM(CASE WHEN A.min_AT > 0     THEN 1 ELSE 0 END)          AS Dias_Con_Atraso,
    SUM(ISNULL(A.min_AT, 0))                                    AS Total_Min_Atraso,
    SUM(CAST(
        DATEPART(hour,   A.Horas_Laboradas) +
        DATEPART(minute, A.Horas_Laboradas) / 60.0
    AS DECIMAL(5,2)))                                           AS Total_Horas_Trabajadas

FROM dispensarioMedico.dbo.cargaTurnosSLPC S
INNER JOIN ONLYC.TCONTROL.dbo.ViewEmpleados E
    ON E.NOMINA_APE + ' ' + E.NOMINA_NOM = S.nombresSLPC
LEFT JOIN ONLYC.TCONTROL.dbo.TBL_ASISTENCIA A
    ON  A.EMP_ID = E.NOMINA_ID
    AND CAST(A.Fecha_Ingreso AS DATE) BETWEEN
            CONVERT(DATE, LEFT(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) - 1), 103)
        AND CONVERT(DATE, SUBSTRING(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) + 3, 10), 103)
    AND CAST(A.Fecha_Ingreso AS DATE) BETWEEN @FechaInicio AND @FechaFin
WHERE
    CONVERT(DATE, LEFT(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) - 1), 103) <= @FechaFin
    AND
    CONVERT(DATE, SUBSTRING(S.fechaRegistroSLPC, CHARINDEX(' - ', S.fechaRegistroSLPC) + 3, 10), 103) >= @FechaInicio
GROUP BY S.nombresSLPC, E.NOMINA_COD, S.coordinadorSLPC
ORDER BY S.nombresSLPC;

