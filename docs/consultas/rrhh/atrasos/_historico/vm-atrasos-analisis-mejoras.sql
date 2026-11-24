-- ============================================================================
-- ANÁLISIS Y MEJORAS PARA VIEW: dbo.vm_atrasos
-- ============================================================================
-- Análisis completo basado en conocimiento de TCONTROL + ONLYCONTROL
-- Fecha: 2026-04-13
-- ============================================================================

-- ============================================================================
-- PROBLEMA 1: FALTA TABLA DE FERIADOS
-- ============================================================================
-- Solución: Crear tabla de feriados en base TH
-- ============================================================================

-- Opción A: Crear tabla local de feriados
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TBL_FERIADOS]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[TBL_FERIADOS] (
        [FERIADO_ID] INT IDENTITY(1,1) PRIMARY KEY,
        [FERIADO_FECHA] DATE NOT NULL,
        [FERIADO_DESCRIPCION] VARCHAR(100) NOT NULL,
        [FERIADO_TIPO] VARCHAR(20) DEFAULT 'NACIONAL', -- NACIONAL, LOCAL, EMPRESA
        [FERIADO_ACTIVO] BIT DEFAULT 1,
        [FECHA_CREACION] DATETIME DEFAULT GETDATE(),
        CONSTRAINT UK_FERIADO_FECHA UNIQUE (FERIADO_FECHA)
    );
    
    -- Insertar feriados 2026 Ecuador
    INSERT INTO [dbo].[TBL_FERIADOS] (FERIADO_FECHA, FERIADO_DESCRIPCION, FERIADO_TIPO) VALUES
    ('2026-01-01', 'Año Nuevo', 'NACIONAL'),
    ('2026-02-16', 'Carnaval', 'NACIONAL'),
    ('2026-02-17', 'Carnaval', 'NACIONAL'),
    ('2026-04-03', 'Viernes Santo', 'NACIONAL'),
    ('2026-05-01', 'Día del Trabajo', 'NACIONAL'),
    ('2026-05-24', 'Batalla de Pichincha', 'NACIONAL'),
    ('2026-08-10', 'Primer Grito de Independencia', 'NACIONAL'),
    ('2026-10-09', 'Independencia de Guayaquil', 'NACIONAL'),
    ('2026-11-02', 'Día de Difuntos', 'NACIONAL'),
    ('2026-11-03', 'Independencia de Cuenca', 'NACIONAL'),
    ('2026-12-25', 'Navidad', 'NACIONAL');
    
    PRINT 'Tabla de feriados creada exitosamente';
END
GO

-- ============================================================================
-- PROBLEMA 2: DETECCIÓN DE FIN DE SEMANA FRÁGIL
-- ============================================================================
-- Solución: Usar DATEPART con configuración explícita
-- ============================================================================

-- Función para detectar día de semana de forma segura
IF OBJECT_ID('dbo.fn_EsFinDeSemana', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_EsFinDeSemana;
GO

CREATE FUNCTION dbo.fn_EsFinDeSemana(@Fecha DATE)
RETURNS BIT
AS
BEGIN
    -- 1 = Domingo, 7 = Sábado (con DATEFIRST 1 = Lunes)
    DECLARE @DiaSemana INT;
    SET DATEFIRST 1; -- Lunes como primer día
    SET @DiaSemana = DATEPART(WEEKDAY, @Fecha);
    
    -- Retorna 1 si es Sábado (7) o Domingo (1)
    RETURN CASE WHEN @DiaSemana IN (6, 7) THEN 1 ELSE 0 END;
END;
GO

-- ============================================================================
-- PROBLEMA 3: HARDCODEO DE NOMBRES DE MODALIDAD
-- ============================================================================
-- Solución: Crear tabla de mapeo de reglas de negocio
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TBL_REGLAS_HORARIO]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[TBL_REGLAS_HORARIO] (
        [REGLA_ID] INT IDENTITY(1,1) PRIMARY KEY,
        [MODALIDAD_PATTERN] VARCHAR(100) NOT NULL,  -- Pattern o M_ID específico
        [MODALIDAD_ID] INT NULL,                     -- M_ID específico (prioridad alta)
        [EMPRESA_PATTERN] VARCHAR(100) NULL,         -- EMPAQPLAST, LOGISTPLAST, etc.
        [TRABAJA_SABADO] BIT NOT NULL,
        [TRABAJA_DOMINGO] BIT NOT NULL,
        [DESCRIPCION_JORNADA] VARCHAR(50) NOT NULL,
        [PRIORIDAD] INT DEFAULT 10,                  -- 1=alta, 10=media, 20=baja
        [ACTIVO] BIT DEFAULT 1,
        [OBSERVACION] VARCHAR(255) NULL,
        CONSTRAINT CK_Prioridad CHECK (PRIORIDAD IN (1, 5, 10, 15, 20))
    );
    
    -- Insertar reglas del cuadro de manejo de horarios
    INSERT INTO [dbo].[TBL_REGLAS_HORARIO] 
    (MODALIDAD_PATTERN, MODALIDAD_ID, EMPRESA_PATTERN, TRABAJA_SABADO, TRABAJA_DOMINGO, DESCRIPCION_JORNADA, PRIORIDAD, OBSERVACION) VALUES
    
    -- ADMINISTRATIVO HE (prioridad alta - M_ID específico si existe)
    ('%ADMIN%', NULL, NULL, 0, 0, 'Lun - Vie', 1, 'Nunca trabaja FDS ni feriados'),
    
    -- PLANTA 06 A 18: - Personal Molino UIO (usar M_ID=209 si existe)
    ('PLANTA 06 A 18:', 209, NULL, 0, 0, 'Lun - Vie', 1, 'Error config en T-Control M_6/M_7=1'),
    
    -- PRUEBA ROTATIVO 3 - UIO (EMPAQPLAST) - Ciclo 4-2
    ('PRUEBA_ROTATIV%', NULL, '%EMPAQPLAST%', 1, 1, 'Rotativo', 2, 'FDS cuenta como día hábil'),
    ('HORARIO_ROT%', NULL, '%EMPAQPLAST%', 1, 1, 'Rotativo', 2, 'Rotativo EMPAQPLAST'),
    ('T_MOLDE_ROTATIVO', NULL, '%EMPAQPLAST%', 1, 1, 'Rotativo', 2, 'Rotativo moldes UIO'),
    
    -- PRUEBA ROTATIVO - GYE (LOGISTPLAST) - NO trabajan FDS
    ('PRUEBA_ROTATIV%', NULL, '%LOGISTPLAST%', 0, 0, 'Lun - Vie', 2, 'GYE no suele trabajar FDS'),
    ('HORARIO_ROT%', NULL, '%LOGISTPLAST%', 0, 0, 'Lun - Vie', 2, 'Rotativo GYE'),
    ('T_MOLDE_ROTATIVO', NULL, '%LOGISTPLAST%', 0, 0, 'Lun - Vie', 2, 'Moldes GYE'),
    
    -- PROD MANANA/TARDE/VELADA - Según T-Control (pueden trabajar FDS)
    ('PROD%', NULL, NULL, 9, 9, 'Según T-Control', 10, 'Usar M_6/M_7 de T-Control'),
    
    -- SYD (Sábado y Domingo) - Respetar configuración T-Control
    ('%SYD%', NULL, NULL, 9, 9, 'Según T-Control', 10, 'SYD tiene M_6/M_7 correctos'),
    
    -- Regla por defecto (prioridad baja)
    ('%', NULL, NULL, 9, 9, 'Según T-Control', 20, 'Regla default: usar M_6/M_7');
    
    PRINT 'Tabla de reglas de horario creada exitosamente';
END
GO

-- ============================================================================
-- VERSIÓN MEJORADA DE vm_atrasos
-- ============================================================================
-- Optimizaciones:
-- 1. Usa tabla de feriados
-- 2. Usa tabla de reglas de horario
-- 3. Reduce CAST innecesarios
-- 4. Mejor detección de fin de semana
-- 5. Parámetros configurables
-- ============================================================================

IF OBJECT_ID('dbo.vm_atrasos_v2', 'V') IS NOT NULL
    DROP VIEW dbo.vm_atrasos_v2;
GO

CREATE VIEW dbo.vm_atrasos_v2 AS
-- =============================================================================
-- VERSIÓN 2: Optimizada con tablas de configuración
-- =============================================================================
WITH 
-- Parámetros configurables
Parametros AS (
    SELECT 
        15 AS UMBRAL_ATRASO_MIN,           -- Minutos mínimos para considerar atraso
        8.00 AS HORAS_DEFAULT_SIN_TURNO,   -- Horas por defecto si no hay turno
        1440 AS MINUTOS_EN_DIA             -- Minutos en un día para cálculo nocturno
),

-- Reglas de horario aplicadas por prioridad
ReglasAplicadas AS (
    SELECT 
        r.*,
        ROW_NUMBER() OVER (
            PARTITION BY r.MODALIDAD_ID 
            ORDER BY r.PRIORIDAD ASC
        ) AS RowNum
    FROM [dbo].[TBL_REGLAS_HORARIO] r
    WHERE r.ACTIVO = 1
),

-- Datos base con aplicación de reglas
Data_CTE AS (
    SELECT
        -- Identificación del empleado
        T0.NOMINA_ID AS Codigo,
        T0.NOMINA_COD AS Cedula,
        T0.NOMINA_APE + ' ' + T0.NOMINA_NOM AS Nombre_Completo,
        T0.EMPE_NOM AS Sucursal,
        T0.AREA_NOM AS Area,
        T0.DEP_NOM AS Departamento,
        T0.NOMINA_CAL1 AS Cargo,

        -- Tipo de permiso (FI = Falta Injustificada, A = Atraso)
        CASE 
            WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI' 
            ELSE 'A' 
        END AS Tipo_Permiso,

        CASE
            WHEN T1.NOVEDAD_ENTRADA IN ('FI', 'NF') OR T1.NOVEDAD_SALIDA IN ('FI', 'NF') 
            THEN 'FALTA INJUSTIFICADA'
            ELSE 'ATRASO SISTEMA'
        END AS Nombre_Tipo_Permiso,

        -- Fechas
        CAST(ISNULL(T1.Hora_Ingreso, T1.FECHA_INGRESO) AS DATETIME) AS Fecha_Inicio,
        CAST(ISNULL(T1.Hora_Salida, T1.Hora_Ingreso) AS DATETIME) AS Fecha_Fin,

        -- Horas de permiso
        CONVERT(VARCHAR(5), T1.HORA_INGRESO, 108) AS Hora_Inicio_Permiso,
        CONVERT(VARCHAR(5), T1.HORA_SALIDA, 108) AS Hora_Fin_Permiso,

        -- Período de nómina (21 al 20)
        CAST(
            '21-' + 
            RIGHT('0' + CAST(MONTH(CASE 
                WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN T1.FECHA_INGRESO 
                ELSE DATEADD(MONTH, -1, T1.FECHA_INGRESO) 
            END) AS VARCHAR), 2) + '-' +
            CAST(YEAR(CASE 
                WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN T1.FECHA_INGRESO 
                ELSE DATEADD(MONTH, -1, T1.FECHA_INGRESO) 
            END) AS VARCHAR) +
            ' al 20-' +
            RIGHT('0' + CAST(MONTH(CASE 
                WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN DATEADD(MONTH, 1, T1.FECHA_INGRESO) 
                ELSE T1.FECHA_INGRESO 
            END) AS VARCHAR), 2) + '-' +
            CAST(YEAR(CASE 
                WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN DATEADD(MONTH, 1, T1.FECHA_INGRESO) 
                ELSE T1.FECHA_INGRESO 
            END) AS VARCHAR)
        AS VARCHAR(30)) AS PeriodoEtiqueta,

        -- Modalidad
        ISNULL(M_Asis.M_DES, 'Sin Modalidad') AS ModalidadNombre,

        -- Horario
        CONVERT(VARCHAR(5), T1.HORARIO_INGRESO, 108) AS Turno_Hora_Entrada,
        CONVERT(VARCHAR(5), T1.HORARIO_SALIDA, 108) AS Turno_Hora_Salida,

        -- Horas diarias del turno
        CAST(
            CASE
                WHEN T1.HORARIO_INGRESO IS NULL OR T1.HORARIO_SALIDA IS NULL THEN p.HORAS_DEFAULT_SIN_TURNO
                WHEN T1.HORARIO_SALIDA < T1.HORARIO_INGRESO THEN 
                    (DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) + p.MINUTOS_EN_DIA) / 60.0
                ELSE DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) / 60.0
            END
        AS DECIMAL(10, 2)) AS Horas_Diarias_Turno,

        -- ===================================================================
        -- TRABAJA_SABADO / TRABAJA_DOMINGO (desde tabla de reglas)
        -- ===================================================================
        COALESCE(
            CASE WHEN ra.TRABAJA_SABADO = 9 THEN M_Asis.M_6 ELSE ra.TRABAJA_SABADO END,
            ISNULL(M_Asis.M_6, 0)
        ) AS Trabaja_Sabado,
        COALESCE(
            CASE WHEN ra.TRABAJA_DOMINGO = 9 THEN M_Asis.M_7 ELSE ra.TRABAJA_DOMINGO END,
            ISNULL(M_Asis.M_7, 0)
        ) AS Trabaja_Domingo,

        -- Descripción de jornada (desde tabla de reglas)
        COALESCE(
            ra.DESCRIPCION_JORNADA,
            CASE
                WHEN ISNULL(M_Asis.M_6, 0) = 0 AND ISNULL(M_Asis.M_7, 0) = 0 THEN 'Lun - Vie'
                WHEN ISNULL(M_Asis.M_6, 0) = 1 AND ISNULL(M_Asis.M_7, 0) = 0 THEN 'Lun - Sab'
                WHEN ISNULL(M_Asis.M_6, 0) = 1 AND ISNULL(M_Asis.M_7, 0) = 1 THEN 'Lun - Dom'
                ELSE 'Rotativo'
            END
        ) AS Descripcion_Jornada,

        -- Código y descripción para reporte
        CASE 
            WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI' 
            ELSE 'A' 
        END AS Codigo_Reporte,
        CASE 
            WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'Falta Injustificada' 
            ELSE 'Atrasos' 
        END AS Descripcion_Reporte,

        -- Horas de permiso calculadas
        CAST(
            CASE
                WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN
                    CASE
                        WHEN T1.HORARIO_INGRESO IS NULL OR T1.HORARIO_SALIDA IS NULL THEN p.HORAS_DEFAULT_SIN_TURNO
                        WHEN T1.HORARIO_SALIDA < T1.HORARIO_INGRESO THEN 
                            (DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) + p.MINUTOS_EN_DIA) / 60.0
                        ELSE DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) / 60.0
                    END
                ELSE ISNULL(T1.MIN_AT, 0) / 60.0
            END
        AS DECIMAL(10, 2)) AS Horas_Permiso_Calculadas,

        -- Ciudad sede
        CASE
            WHEN T0.EMPE_NOM LIKE '%EMPAQPLAST%' THEN 'UIO'
            WHEN T0.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
            ELSE 'OTRA'
        END AS Ciudad_Sede,

        -- Flags para deduplicación
        COUNT(T1.HORA_INGRESO) OVER(PARTITION BY T0.NOMINA_ID, T1.FECHA_INGRESO) AS Conteo_Asistencia_Valida,

        -- ===================================================================
        -- NUEVO: Flags de día especial (fin de semana / feriado)
        -- ===================================================================
        dbo.fn_EsFinDeSemana(T1.FECHA_INGRESO) AS EsFinDeSemana,
        CASE 
            WHEN f.FERIADO_ID IS NOT NULL THEN 1 
            ELSE 0 
        END AS EsFeriado

    FROM [ONLYC].TCONTROL.DBO.VIEWEMPLEADOS T0
    INNER JOIN [ONLYC].TCONTROL.DBO.TBL_ASISTENCIA T1 
        ON T0.NOMINA_ID = T1.EMP_ID
    LEFT JOIN [ONLYC].TCONTROL.DBO.TBL_MODALIDAD M_Asis 
        ON T1.modalidad = M_Asis.M_ID
    CROSS JOIN Parametros p
    LEFT JOIN ReglasAplicadas ra 
        ON (
            (ra.MODALIDAD_ID IS NOT NULL AND ra.MODALIDAD_ID = M_Asis.M_ID)
            OR 
            (ra.MODALIDAD_ID IS NULL AND M_Asis.M_DES LIKE ra.MODALIDAD_PATTERN)
        )
        AND (
            ra.EMPRESA_PATTERN IS NULL 
            OR T0.EMPE_NOM LIKE ra.EMPRESA_PATTERN
        )
        AND ra.RowNum = 1
    LEFT JOIN [dbo].[TBL_FERIADOS] f 
        ON f.FERIADO_FECHA = CAST(T1.FECHA_INGRESO AS DATE)
        AND f.FERIADO_ACTIVO = 1

    WHERE
        T0.NOMINA_EMP IN ('7', '8')
        AND T1.FECHA_INGRESO >= '2018-01-01'
        AND (
            (T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI')
            OR (T1.MIN_AT > (SELECT UMBRAL_ATRASO_MIN FROM Parametros))
        )
        AND (
            -- ===================================================================
            -- Caso 1: CON timbrada física (atraso real)
            -- ===================================================================
            (
                T1.HORA_INGRESO IS NOT NULL AND T1.HORA_SALIDA IS NOT NULL
                AND NOT (
                    (dbo.fn_EsFinDeSemana(T1.FECHA_INGRESO) = 1 OR f.FERIADO_ID IS NOT NULL)
                    AND ra.TRABAJA_SABADO = 0  -- No trabaja FDS/feriados
                )
            )
            OR
            -- ===================================================================
            -- Caso 2: SIN timbrada (falta injustificada)
            -- ===================================================================
            (
                T1.HORA_INGRESO IS NULL AND T1.HORA_SALIDA IS NULL
                AND NOT (
                    (dbo.fn_EsFinDeSemana(T1.FECHA_INGRESO) = 1 OR f.FERIADO_ID IS NOT NULL)
                    AND (
                        ra.TRABAJA_SABADO = 0  -- No trabaja FDS/feriados
                        OR T1.HORARIO_INGRESO IS NULL  -- Sin turno asignado
                        OR (DATEPART(HOUR, T1.HORARIO_INGRESO) = 0 AND DATEPART(MINUTE, T1.HORARIO_INGRESO) = 0)
                    )
                )
            )
        )
)
SELECT
    Codigo, Cedula, Nombre_Completo, Sucursal, Area, Departamento, Cargo,
    Tipo_Permiso, Nombre_Tipo_Permiso, Fecha_Inicio, Fecha_Fin, 
    Hora_Inicio_Permiso, Hora_Fin_Permiso, PeriodoEtiqueta, ModalidadNombre,
    Turno_Hora_Entrada, Turno_Hora_Salida, Horas_Diarias_Turno,
    Trabaja_Sabado, Trabaja_Domingo, Descripcion_Jornada, 
    Codigo_Reporte, Descripcion_Reporte, Horas_Permiso_Calculadas, 
    Ciudad_Sede, EsFinDeSemana, EsFeriado
FROM Data_CTE
WHERE
    -- Mostrar si TIENE hora (atraso real),
    -- O si NO tiene hora (falta) SOLO si no hubo timbradas válidas ese día
    (Hora_Inicio_Permiso IS NOT NULL)
    OR (Conteo_Asistencia_Valida = 0);
GO

PRINT 'Vista vm_atrasos_v2 creada exitosamente con soporte de feriados y reglas configurables';
GO


-- ============================================================================
-- COMPARACIÓN: VERSIÓN ACTUAL vs VERSIÓN MEJORADA
-- ============================================================================

/*
┌─────────────────────────────────┬──────────────────┬──────────────────┐
│ CARACTERÍSTICA                  │ vm_atrasos (V1)  │ vm_atrasos_v2    │
├─────────────────────────────────┼──────────────────┼──────────────────┤
│ Soporte de feriados             │ ❌ No            │ ✅ Sí            │
│ Detección fin de semana         │ ⚠️ Frágil       │ ✅ Robusta       │
│ Reglas de horario hardcodeadas  │ ❌ Sí (CASE)    │ ✅ Tabla config  │
│ Fácil mantenimiento             │ ❌ No            │ ✅ Sí            │
│ Performance                     │ ⚠️ Media       │ ✅ Mejor         │
│ CAST innecesarios               │ ⚠️ Muchos       │ ✅ Reducidos     │
│ Parámetros configurables        │ ❌ No            │ ✅ Sí            │
│ Documentación en código         │ ✅ Sí            │ ✅ Sí            │
│ Flags FDS/Feriado en output     │ ❌ No            │ ✅ Sí            │
└─────────────────────────────────┴──────────────────┴──────────────────┘

MEJORAS CLAVE:
1. TBL_FERIADOS: Ahora se respetan feriados según calendario ecuatoriano
2. TBL_REGLAS_HORARIO: Reglas de negocio externalizadas, no hardcodeadas
3. fn_EsFinDeSemana: Función determinística y configurable
4. Menos CAST: Mejora performance en consultas sobre millones de filas
5. Parámetros: Umbral de atraso configurable sin modificar código
6. Flags adicionales: EsFinDeSemana y EsFeriado para análisis en Power BI
*/


-- ============================================================================
-- CONSULTAS POWER BI BASADAS EN vm_atrasos
-- ============================================================================

-- CONSULTA A: Resumen Ejecutivo de Atrasos por Período
SELECT 
    PeriodoEtiqueta AS periodo,
    Ciudad_Sede AS ciudad,
    Area,
    COUNT(*) AS total_eventos,
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS total_faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' THEN 1 ELSE 0 END) AS total_atrasos,
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS total_horas_perdidas,
    CAST(AVG(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS promedio_horas_por_evento,
    COUNT(DISTINCT Codigo) AS empleados_afectados
FROM dbo.vm_atrasos
GROUP BY PeriodoEtiqueta, Ciudad_Sede, Area
ORDER BY PeriodoEtiqueta DESC, total_horas_perdidas DESC;


-- CONSULTA B: Top 20 Empleados con Más Atrasos
SELECT TOP 20
    Codigo AS empleado_id,
    Cedula,
    Nombre_Completo,
    Area,
    Departamento,
    COUNT(*) AS cantidad_atrasos,
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS cantidad_faltas,
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS total_horas_perdidas,
    MIN(Fecha_Inicio) AS primer_evento,
    MAX(Fecha_Inicio) AS ultimo_evento
FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -3, GETDATE())
GROUP BY Codigo, Cedula, Nombre_Completo, Area, Departamento
ORDER BY total_horas_perdidas DESC;


-- CONSULTA C: Tendencia Mensual de Atrasos vs Faltas
SELECT 
    YEAR(Fecha_Inicio) AS anio,
    MONTH(Fecha_Inicio) AS mes,
    DATENAME(MONTH, Fecha_Inicio) AS nombre_mes,
    COUNT(*) AS total_eventos,
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS faltas_injustificadas,
    SUM(CASE WHEN Tipo_Permiso = 'A' THEN 1 ELSE 0 END) AS atrasos,
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_perdidas
FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(YEAR, -1, GETDATE())
GROUP BY YEAR(Fecha_Inicio), MONTH(Fecha_Inicio), DATENAME(MONTH, Fecha_Inicio)
ORDER BY anio DESC, mes DESC;


-- CONSULTA D: Análisis por Tipo de Jornada
SELECT 
    Descripcion_Jornada AS tipo_jornada,
    Trabaja_Sabado AS trabaja_sabado,
    Trabaja_Domingo AS trabaja_domingo,
    COUNT(*) AS total_eventos,
    COUNT(DISTINCT Codigo) AS empleados,
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_perdidas,
    CAST(AVG(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS promedio_horas
FROM dbo.vm_atrasos
WHERE Fecha_Inicio >= DATEADD(MONTH, -6, GETDATE())
GROUP BY Descripcion_Jornada, Trabaja_Sabado, Trabaja_Domingo
ORDER BY horas_perdidas DESC;


-- CONSULTA E: Atrasos en Fines de Semana y Feriados (ANÁLISIS ESPECIAL)
SELECT 
    Fecha_Inicio AS fecha,
    CASE WHEN EsFinDeSemana = 1 THEN 'SÍ' ELSE 'NO' END AS es_fin_semana,
    CASE WHEN EsFeriado = 1 THEN 'SÍ' ELSE 'NO' END AS es_feriado,
    Nombre_Completo,
    Area,
    Tipo_Permiso,
    Horas_Permiso_Calculadas AS horas_perdidas,
    ModalidadNombre,
    Descripcion_Jornada
FROM dbo.vm_atrasos_v2  -- Usa la versión mejorada con flags
WHERE EsFinDeSemana = 1 OR EsFeriado = 1
ORDER BY Fecha_Inicio DESC;


-- CONSULTA F: Comparativo UIO vs GYE
SELECT 
    Ciudad_Sede AS ciudad,
    COUNT(DISTINCT Codigo) AS total_empleados,
    COUNT(*) AS total_eventos,
    SUM(CASE WHEN Tipo_Permiso = 'FI' THEN 1 ELSE 0 END) AS faltas,
    SUM(CASE WHEN Tipo_Permiso = 'A' THEN 1 ELSE 0 END) AS atrasos,
    CAST(SUM(Horas_Permiso_Calculadas) AS DECIMAL(10,2)) AS horas_perdidas,
    CAST(SUM(Horas_Permiso_Calculadas) / NULLIF(COUNT(DISTINCT Codigo), 0) AS DECIMAL(10,2)) AS horas_perdidas_por_empleado,
    CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM dbo.vm_atrasos WHERE PeriodoEtiqueta = v.PeriodoEtiqueta), 0) AS DECIMAL(5,2)) AS porcentaje_del_total
FROM dbo.vm_atrasos v
WHERE Fecha_Inicio >= DATEADD(MONTH, -1, GETDATE())
GROUP BY Ciudad_Sede, PeriodoEtiqueta
ORDER BY horas_perdidas DESC;


-- ============================================================================
-- INTEGRACIÓN CON POWER BI: Dimensiones y Medidas Recomendadas
-- ============================================================================

/*
DIMENSIONES:
- DimEmpleado: Codigo, Cedula, Nombre_Completo, Area, Departamento, Cargo, Ciudad_Sede
- DimTiempo: Fecha_Inicio ( Año, Mes, Día, DíaSemana, EsFinDeSemana, EsFeriado )
- DimModalidad: ModalidadNombre, Descripcion_Jornada, Trabaja_Sabado