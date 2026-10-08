-- ============================================================================
-- VISTA: dbo.vm_atrasos
-- ============================================================================
-- Base de datos: TH (192.168.20.15 / SRV-APP\SQLEXPRESS)
-- Propósito: Reporte integral de atrasos, faltas y NO CUMPLIMIENTO de horario
-- Autor: Jefferson Vásconez
-- Fecha: 2026-04-13
--
-- COLUMNAS CLAVE:
-- - Estado_Cumplimiento: 'No Cumple Horario' | 'Cumple Horario'
-- - Horas_No_Cumple_Horario: Horas de salida anticipada
-- - Minutos_Tiempo_Faltante: Minutos totales faltantes
-- ============================================================================

USE TH;
CREATE OR ALTER VIEW dbo.vm_atrasos AS
-- =============================================================================
-- BLOQUE 2: ATRASOS Y FALTAS (OPTIMIZADO PARA LINKED SERVER)
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

        -- [TIPO PERMISO] — Sin cambios: FI o A
        CAST(CASE WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI' ELSE 'A' END AS VARCHAR(50)) AS Tipo_Permiso,

        -- [NOMBRE TIPO] — Sin cambios
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

        -- =======================================================================
        -- FIX 2026-03-18: Timbrado real del biométrico (T-Control)
        -- =======================================================================
        T1.Hora_Ingreso AS Timbrado_Inicio,
        T1.Hora_Salida AS Timbrado_Fin,

        -- =======================================================================
        -- FIX 2026-03-18: Tiempo faltante total (minutos)
        -- =======================================================================
        CAST(
            CASE
                WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN
                    CASE
                        WHEN T1.HORARIO_INGRESO IS NULL OR T1.HORARIO_SALIDA IS NULL THEN 480
                        WHEN T1.HORARIO_SALIDA < T1.HORARIO_INGRESO THEN DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) + 1440
                        ELSE DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA)
                    END
                ELSE ISNULL(T1.MIN_AT, 0) + ISNULL(T1.MIN_SA, 0)
            END
        AS INT) AS Minutos_Tiempo_Faltante,

        -- =======================================================================
        -- FIX 2026-03-18: Horas de salida anticipada ("No Cumple Horario")
        -- =======================================================================
        CAST(
            CASE
                WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN
                    CASE
                        WHEN T1.HORARIO_INGRESO IS NULL OR T1.HORARIO_SALIDA IS NULL THEN 8.00
                        WHEN T1.HORARIO_SALIDA < T1.HORARIO_INGRESO THEN (DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) + 1440) / 60.0
                        ELSE DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) / 60.0
                    END
                ELSE ISNULL(T1.MIN_SA, 0) / 60.0
            END
        AS DECIMAL(9, 2)) AS Horas_No_Cumple_Horario,

        -- =======================================================================
        -- FIX 2026-03-18: Estado de cumplimiento
        -- =======================================================================
        CAST(
            CASE
                WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'No Cumple Horario'
                WHEN ISNULL(T1.MIN_SA, 0) > 15 THEN 'No Cumple Horario'
                ELSE 'Cumple Horario'
            END
        AS VARCHAR(30)) AS Estado_Cumplimiento,

        -- =======================================================================
        -- NUEVO: Tipo de registro (código corto para clasificación)
        -- =======================================================================
        CAST(
            CASE
                WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI'
                WHEN ISNULL(T1.MIN_SA, 0) > 15 THEN 'SA'
                ELSE 'OK'
            END
        AS VARCHAR(10)) AS Tipo_Registro,

        -- =======================================================================
        -- NUEVO: Nombre del registro (descripción legible)
        -- =======================================================================
        CAST(
            CASE
                WHEN T1.NOVEDAD_ENTRADA = 'FI' AND T1.NOVEDAD_SALIDA = 'FI' THEN 'Falta Completa'
                WHEN T1.NOVEDAD_ENTRADA = 'FI' THEN 'Falta Entrada'
                WHEN T1.NOVEDAD_SALIDA = 'FI' THEN 'Falta Salida'
                WHEN ISNULL(T1.MIN_SA, 0) > 15 THEN 'Salida Anticipada'
                ELSE 'Cumple Horario'
            END
        AS VARCHAR(50)) AS Nombre_Registro,

        -- [PERIODO ETIQUETA]
        CAST('21-' AS VARCHAR) +
        RIGHT('0' + CAST(MONTH(CASE WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN T1.FECHA_INGRESO ELSE DATEADD(MONTH, -1, T1.FECHA_INGRESO) END) AS VARCHAR), 2) + '-' +
        CAST(YEAR(CASE WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN T1.FECHA_INGRESO ELSE DATEADD(MONTH, -1, T1.FECHA_INGRESO) END) AS VARCHAR) +
        ' al ' +
        CAST('20-' AS VARCHAR) +
        RIGHT('0' + CAST(MONTH(CASE WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN DATEADD(MONTH, 1, T1.FECHA_INGRESO) ELSE T1.FECHA_INGRESO END) AS VARCHAR), 2) + '-' +
        CAST(YEAR(CASE WHEN DAY(T1.FECHA_INGRESO) >= 21 THEN DATEADD(MONTH, 1, T1.FECHA_INGRESO) ELSE T1.FECHA_INGRESO END) AS VARCHAR)
        AS PeriodoEtiqueta,

        -- [MODALIDAD]
        CAST(ISNULL(M_Asis.M_DES, 'Sin Modalidad') AS VARCHAR(255)) AS ModalidadNombre,

        -- [HORARIOS]
        CONVERT(VARCHAR(5), T1.HORARIO_INGRESO, 108) AS Turno_Hora_Entrada,
        CONVERT(VARCHAR(5), T1.HORARIO_SALIDA, 108) AS Turno_Hora_Salida,

        -- [HORAS DIARIAS TURNO]
        CAST(
            CASE
                WHEN T1.HORARIO_INGRESO IS NULL OR T1.HORARIO_SALIDA IS NULL THEN 8.00
                WHEN T1.HORARIO_SALIDA < T1.HORARIO_INGRESO THEN (DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) + 1440) / 60.0
                ELSE DATEDIFF(MINUTE, T1.HORARIO_INGRESO, T1.HORARIO_SALIDA) / 60.0
            END
        AS DECIMAL(19, 2)) AS Horas_Diarias_Turno,

        -- =======================================================================
        -- FIX 2026-03-12: Override M_6/M_7 para ADMIN.
        -- =======================================================================
        CASE
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                      THEN 0
            WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'                                 THEN 0
            WHEN (M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
               OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
               OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO')
             AND T0.EMPE_NOM LIKE '%LOGISTPLAST%'                                  THEN 0
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                THEN 1
            ELSE ISNULL(M_Asis.M_6, 0)
        END AS Trabaja_Sabado,
        CASE
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                      THEN 0
            WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'                                 THEN 0
            WHEN (M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
               OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
               OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO')
             AND T0.EMPE_NOM LIKE '%LOGISTPLAST%'                                  THEN 0
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                THEN 1
            ELSE ISNULL(M_Asis.M_7, 0)
        END AS Trabaja_Domingo,

        -- -----------------------------------------------------------------------
        -- DESCRIPCION_JORNADA
        -- -----------------------------------------------------------------------
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

        -- [CODIGO / DESCRIPCION REPORTE] — Sin cambios
        CAST(CASE WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI' ELSE 'A' END AS VARCHAR(50)) AS Codigo_Reporte,
        CAST(CASE WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'Falta Injustificada' ELSE 'Atrasos' END AS VARCHAR(255)) AS Descripcion_Reporte,

        -- [HORAS PERMISO CALCULADAS] — Sin cambios
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

        -- [CIUDAD SEDE]
        CAST(CASE
            WHEN T0.EMPE_NOM LIKE '%EMPAQPLAST%' THEN 'UIO'
            WHEN T0.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
            ELSE 'OTRA'
        END AS VARCHAR(20)) AS Ciudad_Sede,

        -- [CONTEO PARA DEDUPLICAR]
        COUNT(T1.HORA_INGRESO) OVER(PARTITION BY T0.NOMINA_ID, T1.FECHA_INGRESO) AS Conteo_Asistencia_Valida

    FROM [ONLYC].TCONTROL.DBO.VIEWEMPLEADOS T0
    INNER JOIN [ONLYC].TCONTROL.DBO.TBL_ASISTENCIA T1 ON T0.NOMINA_ID = T1.EMP_ID
    LEFT JOIN [ONLYC].TCONTROL.DBO.TBL_MODALIDAD M_Asis ON T1.modalidad = M_Asis.M_ID

    WHERE
        T0.NOMINA_EMP IN ('7', '8')
        AND T1.FECHA_INGRESO >= '2018-01-01'
        AND (
            (T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI')
            OR (T1.MIN_AT > 15)
        )
        AND (
            (
                T1.HORA_INGRESO IS NOT NULL AND T1.HORA_SALIDA IS NOT NULL
                AND NOT (
                    DATEDIFF(day, '19000101', T1.FECHA_INGRESO) % 7 IN (5, 6)
                    AND M_Asis.M_DES LIKE '%ADMIN%'
                )
            )
            OR
            (
                T1.HORA_INGRESO IS NULL AND T1.HORA_SALIDA IS NULL
                AND NOT (
                    DATEDIFF(day, '19000101', T1.FECHA_INGRESO) % 7 IN (5, 6)
                    AND (
                        M_Asis.M_DES LIKE '%ADMIN%'
                        OR T1.HORARIO_INGRESO IS NULL
                        OR (DATEPART(HOUR, T1.HORARIO_INGRESO) = 0 AND DATEPART(MINUTE, T1.HORARIO_INGRESO) = 0)
                    )
                )
            )
        )
)
SELECT
    Codigo, Cedula, Nombre_Completo, Sucursal, Area, Departamento, Cargo,
    Tipo_Permiso, Nombre_Tipo_Permiso, Fecha_Inicio, Fecha_Fin, Hora_Inicio_Permiso, Hora_Fin_Permiso,
    Timbrado_Inicio, Timbrado_Fin, Minutos_Tiempo_Faltante, Horas_No_Cumple_Horario, Estado_Cumplimiento,
    Tipo_Registro, Nombre_Registro,
    PeriodoEtiqueta, ModalidadNombre, Turno_Hora_Entrada, Turno_Hora_Salida, Horas_Diarias_Turno,
    Trabaja_Sabado, Trabaja_Domingo, Descripcion_Jornada, Codigo_Reporte, Descripcion_Reporte,
    Horas_Permiso_Calculadas, Ciudad_Sede
FROM Data_CTE
WHERE
    (Hora_Inicio_Permiso IS NOT NULL)
    OR (Conteo_Asistencia_Valida = 0);
