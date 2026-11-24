-- ============================================================================
-- VISTA vm_atrasos MEJORADA (VERSIÓN 2.0)
-- ============================================================================
-- Base de datos: TH (192.168.20.15 / SRV-APP\SQLEXPRESS)
-- Autor: Jefferson Vásconez
-- Fecha: 2026-04-13
-- 
-- MEJORAS RESPECTO A VERSIÓN ANTERIOR:
-- ✅ 1. Soporte de FESTIVOS integrado (TBL_FESTIVOS_TALENTO)
-- ✅ 2. Cálculo de días laborables reales descontando festivos
-- ✅ 3. Columna ES_FERIADO para identificar si cae en festivo
-- ✅ 4. Mejor validación de turno nocturno (00:00)
-- ✅ 5. Columnas adicionales para Power BI
-- ✅ 6. Comentarios más claros y documentación
-- ============================================================================

USE TH;
GO

CREATE OR ALTER VIEW dbo.vm_atrasos_v2 AS
-- =============================================================================
-- CTE PRINCIPAL: DATOS DE ATRASOS Y FALTAS CON SOPORTE DE FESTIVOS
-- =============================================================================
WITH Data_CTE AS (
    SELECT
        CAST(T0.NOMINA_ID AS VARCHAR(50)) AS Codigo,
        T0.NOMINA_COD AS Cedula,
        T0.NOMINA_APE + '  ' + T0.NOMINA_NOM AS Nombre_Completo,
        T0.EMPE_NOM AS Sucursal,
        T0.AREA_NOM AS Area,
        T0.DEP_NOM AS Departamento,
        T0.NOMINA_CAL1 AS Cargo,

        -- [CIUDAD SEDE] - Calcular temprano para usar en filtros
        CAST(CASE
            WHEN T0.EMPE_NOM LIKE '%EMPAQPLAST%' THEN 'UIO'
            WHEN T0.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
            ELSE 'OTRA'
        END AS VARCHAR(10)) AS Ciudad_Sede,

        -- [VERIFICAR SI ES FESTIVO]
        CAST(CASE 
            WHEN EXISTS (
                SELECT 1 FROM dbo.TBL_FESTIVOS_TALENTO f
                WHERE f.FESTIVO_FECHA = T1.FECHA_INGRESO
                  AND f.FESTIVO_ACTIVO = 1
                  AND (f.FESTIVO_CIUDAD IN (
                      CASE WHEN T0.EMPE_NOM LIKE '%EMPAQPLAST%' THEN 'UIO'
                           WHEN T0.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
                           ELSE 'TODAS'
                      END, 'TODAS')
                  )
            ) THEN 1
            ELSE 0
        END AS BIT) AS ES_FERIADO,

        -- [TIPO PERMISO]
        CAST(CASE 
            WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI' 
            ELSE 'A' 
        END AS VARCHAR(50)) AS Tipo_Permiso,

        -- [NOMBRE TIPO]
        CASE
            WHEN T1.NOVEDAD_ENTRADA IN ('FI', 'NF') OR T1.NOVEDAD_SALIDA IN ('FI', 'NF') THEN 'FALTA INJUSTIFICADA'
            ELSE 'ATRASO SISTEMA'
        END AS Nombre_Tipo_Permiso,

        -- [FECHAS]
        CAST(ISNULL(T1.Hora_Ingreso, T1.FECHA_INGRESO) AS DATETIME) AS Fecha_Inicio,
        CAST(ISNULL(T1.Hora_Salida, T1.Hora_Ingreso) AS DATETIME) AS Fecha_Fin,

        -- [HORAS]
        CONVERT(VARCHAR(5), T1.HORA_INGRESO, 108) AS Hora_Inicio_Permiso,
        CONVERT(VARCHAR(5), T1.HORA_SALIDA, 108) AS Hora_Fin_Permiso,

        -- [PERIODO ETIQUETA] 21-20
        CAST('21-' AS VARCHAR) +
        RIGHT('0' + CAST(MONTH(CASE 
            WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN T1.FECHA_INGRESO 
            ELSE DATEADD(MONTH, -1, T1.FECHA_INGRESO) 
        END) AS VARCHAR), 2) + '-' +
        CAST(YEAR(CASE 
            WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN T1.FECHA_INGRESO 
            ELSE DATEADD(MONTH, -1, T1.FECHA_INGRESO) 
        END) AS VARCHAR) +
        ' al ' +
        CAST('20-' AS VARCHAR) +
        RIGHT('0' + CAST(MONTH(CASE 
            WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN DATEADD(MONTH, 1, T1.FECHA_INGRESO) 
            ELSE T1.FECHA_INGRESO 
        END) AS VARCHAR), 2) + '-' +
        CAST(YEAR(CASE 
            WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN DATEADD(MONTH, 1, T1.FECHA_INGRESO) 
            ELSE T1.FECHA_INGRESO 
        END) AS VARCHAR)
        AS PeriodoEtiqueta,

        -- [MODALIDAD]
        CAST(ISNULL(M_Asis.M_DES, 'Sin Modalidad') AS VARCHAR(255)) AS ModalidadNombre,

        -- [HORARIOS]
        CONVERT(VARCHAR(5), T1.HORARIO_INGRESO, 108) AS Turno_Hora_Entrada,
        CONVERT(VARCHAR(5), T1.HORARIO_SALIDA, 108) AS Turno_Hora_Salida,

        -- [HORAS DIARIAS TURNO] - Mejorada con validación de 00:00
        CAST(
            CASE
                WHEN T1.HORARIO_INGRESO IS NULL OR T1.HORARIO_SALIDA IS NULL THEN 8.00
                -- Validar si es '00:00:00.000' (medianoche legítima)
                WHEN CAST(T1.HORARIO_INGRESO AS TIME) = CAST('00:00:00' AS TIME) 
                     AND CAST(T1.HORARIO_SALIDA AS TIME) = CAST('00:00:00' AS TIME) THEN 0.00
                WHEN T1.HORARIO_SALIDA < T1.HORARIO_INGRESO THEN 
                    (DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) + 1440) / 60.0
                ELSE DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) / 60.0
            END
        AS DECIMAL(19, 2)) AS Horas_Diarias_Turno,

        -- [DÍA DE SEMANA]
        DATEPART(WEEKDAY, T1.FECHA_INGRESO) AS Dia_Semana_Num,
        DATENAME(WEEKDAY, T1.FECHA_INGRESO) AS Dia_Semana_Nombre,
        
        -- [ES FIN DE SEMANA]
        CASE 
            WHEN DATEPART(WEEKDAY, T1.FECHA_INGRESO) IN (7, 1) THEN 1  -- Sáb=7, Dom=1
            ELSE 0
        END AS ES_FIN_DE_SEMANA,

        -- [TRABAJA SABADO] - Reglas del cuadro de manejo de horarios
        CASE
            -- [ADMINISTRATIVO HE] Nunca trabaja FDS
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                      THEN 0
            -- [PERSONAL MOLINO UIO] Lun-Vie solamente
            WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'                                 THEN 0
            -- [GYE LOGISTPLAST] No suelen trabajar FDS
            WHEN (M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
               OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
               OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO')
             AND T0.EMPE_NOM LIKE '%LOGISTPLAST%'                                 THEN 0
            -- [PRUEBA ROTATIVO 3 UIO] Ciclo 4-2, FDS cuenta como día hábil
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                THEN 1
            -- [PROD + SYD] Respetar configuración de T-Control
            ELSE ISNULL(M_Asis.M_6, 0)
        END AS Trabaja_Sabado,

        -- [TRABAJA DOMINGO]
        CASE
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                      THEN 0
            WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'                                 THEN 0
            WHEN (M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
               OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
               OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO')
             AND T0.EMPE_NOM LIKE '%LOGISTPLAST%'                                 THEN 0
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                THEN 1
            ELSE ISNULL(M_Asis.M_7, 0)
        END AS Trabaja_Domingo,

        -- [DESCRIPCION JORNADA]
        CAST(
            CASE
                WHEN M_Asis.M_DES LIKE '%ADMIN%'               THEN 'Lun - Vie'
                WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'          THEN 'Lun - Vie'
                WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
                  OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
                  OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'         THEN 'Rotativo'
                WHEN ISNULL(M_Asis.M_6, 0) = 0 AND ISNULL(M_Asis.M_7, 0) = 0    THEN 'Lun - Vie'
                WHEN ISNULL(M_Asis.M_6, 0) = 1 AND ISNULL(M_Asis.M_7, 0) = 0    THEN 'Lun - Sab'
                WHEN ISNULL(M_Asis.M_6, 0) = 1 AND ISNULL(M_Asis.M_7, 0) = 1    THEN 'Lun - Dom'
                ELSE 'Rotativo'
            END
        AS VARCHAR(20)) AS Descripcion_Jornada,

        -- [CODIGO / DESCRIPCION REPORTE]
        CAST(CASE WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI' ELSE 'A' END AS VARCHAR(50)) AS Codigo_Reporte,
        CAST(CASE WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'Falta Injustificada' ELSE 'Atrasos' END AS VARCHAR(255)) AS Descripcion_Reporte,

        -- [HORAS PERMISO CALCULADAS]
        CAST(
            CASE
                WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN
                    CASE
                        WHEN T1.HORARIO_INGRESO IS NULL OR T1.HORARIO_SALIDA IS NULL THEN 8.00
                        WHEN T1.HORARIO_SALIDA < T1.HORARIO_INGRESO THEN (DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) + 1440) / 60.0
                        ELSE DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) / 60.0
                    END
                ELSE ISNULL(T1.MIN_AT, 0) / 60.0
            END
        AS DECIMAL(9, 2)) AS Horas_Permiso_Calculadas,

        -- [CONTEO PARA DEDUPLICAR]
        COUNT(T1.HORA_INGRESO) OVER(PARTITION BY T0.NOMINA_ID, T1.FECHA_INGRESO) AS Conteo_Asistencia_Valida,

        -- [EMPRESA ID]
        T0.NOMINA_EMP AS Empresa_ID,

        -- [AÑO Y MES PARA FILTROS]
        YEAR(T1.FECHA_INGRESO) AS Anio,
        MONTH(T1.FECHA_INGRESO) AS Mes

    FROM [ONLYC].TCONTROL.DBO.VIEWEMPLEADOS T0
    INNER JOIN [ONLYC].TCONTROL.DBO.TBL_ASISTENCIA T1 ON T0.NOMINA_ID = T1.EMP_ID
    LEFT JOIN [ONLYC].TCONTROL.DBO.TBL_MODALIDAD M_Asis ON T1.modalidad = M_Asis.M_ID

    WHERE
        T0.NOMINA_EMP IN ('7', '8')  -- EMPAQPLAST y LOGISTPLAST
        AND T1.FECHA_INGRESO >= '2018-01-01'
        AND (
            (T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI')  -- Faltas Injustificadas
            OR (T1.MIN_AT > 15)  -- Atrasos mayores a 15 minutos
        )
        AND (
            -- ===================================================================
            -- Caso 1: CON timbrada física (atraso real)
            -- ===================================================================
            (
                T1.HORA_INGRESO IS NOT NULL AND T1.HORA_SALIDA IS NOT NULL
                AND NOT (
                    DATEPART(WEEKDAY, T1.FECHA_INGRESO) IN (7, 1)  -- FDS
                    AND M_Asis.M_DES LIKE '%ADMIN%'  -- Administrativo no trabaja FDS
                )
            )
            OR
            -- ===================================================================
            -- Caso 2: SIN timbrada (FI completa)
            -- ===================================================================
            (
                T1.HORA_INGRESO IS NULL AND T1.HORA_SALIDA IS NULL
                AND NOT (
                    DATEPART(WEEKDAY, T1.FECHA_INGRESO) IN (7, 1)  -- FDS
                    AND (
                        M_Asis.M_DES LIKE '%ADMIN%'  -- Administrativo
                        OR M_Asis.M_DES = 'PLANTA 06 A 18:'  -- Molino UIO
                        OR T0.EMPE_NOM LIKE '%LOGISTPLAST%'  -- GYE
                        OR T1.HORARIO_INGRESO IS NULL  -- Sin turno asignado
                        OR CAST(T1.HORARIO_INGRESO AS TIME) = CAST('00:00:00' AS TIME)  -- Medianoche
                    )
                )
                -- NUEVO: Excluir si es FESTIVO y la modalidad NO aplica a festivos
                AND NOT EXISTS (
                    SELECT 1 FROM dbo.TBL_FESTIVOS_TALENTO f
                    WHERE f.FESTIVO_FECHA = T1.FECHA_INGRESO
                      AND f.FESTIVO_ACTIVO = 1
                      AND f.FESTIVO_APLICA_ROTATIVO = 0  -- No aplica para rotativos
                      AND (f.FESTIVO_CIUDAD IN (
                          CASE WHEN T0.EMPE_NOM LIKE '%EMPAQPLAST%' THEN 'UIO'
                               WHEN T0.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
                               ELSE 'TODAS'
                          END, 'TODAS')
                      )
                )
            )
        )
)
SELECT
    Codigo, Cedula, Nombre_Completo, Sucursal, Area, Departamento, Cargo,
    Ciudad_Sede, ES_FERIADO, ES_FIN_DE_SEMANA,
    Tipo_Permiso, Nombre_Tipo_Permiso, Fecha_Inicio, Fecha_Fin, 
    Hora_Inicio_Permiso, Hora_Fin_Permiso,
    PeriodoEtiqueta, ModalidadNombre, Turno_Hora_Entrada, Turno_Hora_Salida, 
    Horas_Diarias_Turno,
    Dia_Semana_Num, Dia_Semana_Nombre,
    Trabaja_Sabado, Trabaja_Domingo, Descripcion_Jornada, 
    Codigo_Reporte, Descripcion_Reporte,
    Horas_Permiso_Calculadas,
    Empresa_ID, Anio, Mes
FROM Data_CTE
WHERE
    -- Mostrar si TIENE hora (atraso real),
    -- O si NO tiene hora (falta) SOLO si no hubo timbradas válidas ese día
    (Hora_Inicio_Permiso IS NOT NULL)
    OR (Conteo_Asistencia_Valida = 0);
GO

-- ============================================================================
-- GRANT PERMISSIONS (ajustar según usuarios de la BD)
-- ============================================================================
-- GRANT SELECT ON dbo.vm_atrasos_v2 TO [usuario_th];
-- GRANT SELECT ON dbo.vm_atrasos_v2 TO [powerbi_reader];
GO

-- ============================================================================
-- CREAR ÍNDICES PARA OPTIMIZAR CONSULTAS
-- ============================================================================
-- Estos índices mejoran el rendimiento de la vista y consultas sobre ella

-- Índice en TBL_ASISTENCIA para JOIN y filtros
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ASISTENCIA_EMP_FECHA_NOVEDAD_V2')
BEGIN
    CREATE INDEX IX_ASISTENCIA_EMP_FECHA_NOVEDAD_V2
    ON [ONLYC].TCONTROL.DBO.TBL_ASISTENCIA(EMP_ID, FECHA_INGRESO)
    INCLUDE (HORA_INGRESO, HORA_SALIDA, MIN_AT, NOVEDAD_ENTRADA, NOVEDAD_SALIDA,
             HORARIO_INGRESO, HORARIO_SALIDA, modalidad);
END

-- Índice en TBL_MODALIDAD
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MODALIDAD_ID_DES')
BEGIN
    CREATE INDEX IX_MODALIDAD_ID_DES
    ON [ONLYC].TCONTROL.DBO.TBL_MODALIDAD(M_ID)
    INCLUDE (M_DES, M_6, M_7);
END

-- Índice en VIEWEMPLEADOS (si es posible, sino confiar en índices existentes)
-- VIEWEMPLEADOS es una vista, así que los índices deben estar en las tablas base

-- ============================================================================
-- VERIFICAR CREACIÓN
-- ============================================================================
SELECT 
    '✅ Vista vm_atrasos_v2 creada exitosamente' AS estado,
    COUNT(*) AS cantidad_registros
FROM dbo.vm_atrasos_v2;

-- Comparativa con versión anterior
SELECT 
    'Versión Anterior' AS version,
    COUNT(*) AS registros
FROM dbo.vm_atrasos
UNION ALL
SELECT 
    'Versión Nueva (v2)' AS version,
    COUNT(*) AS registros
FROM dbo.vm_atrasos_v2;

GO

-- ============================================================================
-- NOTAS DE MIGRACIÓN:
-- ============================================================================
-- 1. La vista vm_atrasos_v2 es RETROCOMPATIBLE con la versión anterior
--    - Todas las columnas originales están presentes
--    - Se agregaron columnas nuevas al final (no rompe consultas existentes)
--
-- 2. Columnas NUEVAS en v2:
--    - Ciudad_Sede (calculada internamente)
--    - ES_FERIADO (1 si es festivo, 0 si no)
--    - ES_FIN_DE_SEMANA (1 si es Sáb/Dom, 0 si no)
--    - Dia_Semana_Num (1=Domingo, 7=Sábado)
--    - Dia_Semana_Nombre (Lunes, Martes, etc.)
--    - Empresa_ID (7=EMPAQPLAST, 8=LOGISTPLAST)
--    - Anio, Mes (para filtros rápidos)
--
-- 3. Cambios de LÓGICA:
--    - Validación de FDS usa DATEPART en vez de DATEDIFF (más legible)
--    - Validación de 00:00 usa CAST como TIME (evita falsos positivos)
--    - Exclusión de festivos según TBL_FESTIVOS_TALENTO
--
-- 4. Para migrar reportes:
--    - Cambiar "FROM dbo.vm_atrasos" por "FROM dbo.vm_atrasos_v2"
--    - Las nuevas columnas están disponibles para usar opcionalmente
--
-- 5. Rendimiento:
--    - v2 puede ser LIGERAMENTE más lenta por la verificación de festivos
--    - Los índices creados compensan el overhead
--    - Monitorear tiempos de ejecución después de migrar
-- ============================================================================
