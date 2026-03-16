-- =============================================================================
-- ALTER VIEW: dbo.vm_atrasos
-- Base de datos : TH (192.168.20.15 / SRV-APP\SQLEXPRESS)
-- Autor         : Jefferson Vasconez
-- Fecha         : 2026-03-16
--
-- CAMBIOS APLICADOS segun cuadro de manejo de horarios:
--
--   FIX 1 - Trabaja_Sabado / Trabaja_Domingo:
--     PRUEBA_ROTATIVO_3, PRUEBA_ROTATIVO, PRUEBA_ROTATIVA2,
--     HORARIO_ROT_GRUP_1/2/3, T_MOLDE_ROTATIVO tienen M_6=0, M_7=0 en
--     T-Control, pero el cuadro indica que cualquier dia de su ciclo de 4
--     (incluyendo sabado/domingo) cuenta como dia habil normal. Se fuerza 1.
--
--   FIX 2 - Descripcion_Jornada:
--     Las modalidades rotativas UIO mencionadas antes mostraban 'Lun - Vie'
--     por el M_6/M_7=0/0. Ahora muestran 'Rotativo'.
--
--   SIN CAMBIO - Logica de filtrado de atrasos/FI:
--     Ya es correcta para todos los tipos:
--     - ADMIN excluye sabado/domingo en Caso 1 y Caso 2  (OK)
--     - ROTATIVO con HORARIO_INGRESO asignado cuenta FI en fin de semana (OK)
--     - ROTATIVO sin HORARIO_INGRESO en fin de semana: FI excluida (OK)
--     - GYE (M_6=0, M_7=0): no trabaja fines de semana (OK)
--
--   PENDIENTE - Feriados:
--     No existe tabla de feriados en la BD. Esta regla no se puede
--     implementar hasta crear/cargar dicha tabla.
-- =============================================================================
ALTER VIEW dbo.vm_atrasos AS
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

        -- [TIPO PERMISO]
        CAST(CASE WHEN T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI' THEN 'FI' ELSE 'A' END AS VARCHAR(50)) AS Tipo_Permiso,

        -- [NOMBRE TIPO]
        CASE
            WHEN T1.NOVEDAD_ENTRADA IN ('FI', 'NF') OR T1.NOVEDAD_SALIDA IN ('FI', 'NF') THEN 'FALTA INJUSTIFICADA'
            ELSE 'ATRASO SISTEMA'
        END AS Nombre_Tipo_Permiso,

        -- [FECHAS]
        -- Si no marco entrada (NULL), toma la fecha teorica del registro (FECHA_INGRESO)
        CAST(ISNULL(T1.Hora_Ingreso, T1.FECHA_INGRESO) AS DATETIME) AS Fecha_Inicio,
        CAST(ISNULL(T1.Hora_Salida, T1.Hora_Ingreso) AS DATETIME) AS Fecha_Fin,

        -- [HORAS]
        CONVERT(VARCHAR(5), T1.HORA_INGRESO, 108) AS Hora_Inicio_Permiso,
        CONVERT(VARCHAR(5), T1.HORA_SALIDA, 108) AS Hora_Fin_Permiso,

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
        --   ADMINISTRATIVA HE (193) y ADMINISTRATIVO HE (188) tienen M_6=1, M_7=1
        --   mal configurados en T-Control. Regla de negocio real: Lun-Vie.
        --   PROD/ROTATIVO mantienen su valor real de M_6/M_7.
        --
        -- FIX 2026-03-16: Override para ROTATIVO UIO.
        --   PRUEBA_ROTATIVO_3 (302), PRUEBA_ROTATIVO (300), PRUEBA_ROTATIVA2 (301),
        --   HORARIO_ROT_GRUP_1 (297), HORARIO_ROT_GRUP_2 (299), HORARIO_ROT_GRUP_3 (298),
        --   T_MOLDE_ROTATIVO (307) tienen M_6=0, M_7=0 en T-Control.
        --   Cuadro de horarios: si el 1ero-4to dia de la rotacion cae en fin de
        --   semana, cuenta como dia habil normal. Se fuerza Trabaja_Sabado=1 y
        --   Trabaja_Domingo=1 para reflejar correctamente la jornada.
        --   GYE ROTATIVO (305, 306, 308, 311) NO se toca: M_6=0, M_7=0 correcto.
        -- =======================================================================
        CASE
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                                                               THEN 0
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                                                         THEN 1
            ELSE ISNULL(M_Asis.M_6, 0)
        END AS Trabaja_Sabado,
        CASE
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                                                               THEN 0
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                                                         THEN 1
            ELSE ISNULL(M_Asis.M_7, 0)
        END AS Trabaja_Domingo,

        CAST(
            CASE
                WHEN M_Asis.M_DES LIKE '%ADMIN%'                                                                           THEN 'Lun - Vie'
                -- FIX 2026-03-16: Rotativo UIO puede trabajar cualquier dia de la semana
                WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
                  OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
                  OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                                                     THEN 'Rotativo'
                WHEN ISNULL(M_Asis.M_6, 0) = 0 AND ISNULL(M_Asis.M_7, 0) = 0                                             THEN 'Lun - Vie'
                WHEN ISNULL(M_Asis.M_6, 0) = 1 AND ISNULL(M_Asis.M_7, 0) = 0                                             THEN 'Lun - Sab'
                WHEN ISNULL(M_Asis.M_6, 0) = 1 AND ISNULL(M_Asis.M_7, 0) = 1                                             THEN 'Lun - Dom'
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

        -- [CIUDAD SEDE]
        CAST(CASE
            WHEN T0.EMPE_NOM LIKE '%EMPAQPLAST%' THEN 'UIO'
            WHEN T0.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
            ELSE 'OTRA'
        END AS VARCHAR(20)) AS Ciudad_Sede,

        -- [CONTEO PARA DEDUPLICAR]
        -- Cuenta si existe alguna timbrada valida para este dia
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
            -- =======================================================================
            -- Caso 1: CON timbrada fisica (atraso real, la persona si llego)
            --   ADMIN         → excluir si cae en sabado o domingo
            --   PROD/ROTATIVO → incluir siempre (si timbro, estaba en su turno)
            -- =======================================================================
            (
                T1.HORA_INGRESO IS NOT NULL AND T1.HORA_SALIDA IS NOT NULL
                AND NOT (
                    DATEDIFF(day, '19000101', T1.FECHA_INGRESO) % 7 IN (5, 6)
                    AND M_Asis.M_DES LIKE '%ADMIN%'
                )
            )
            OR
            -- =======================================================================
            -- Caso 2: SIN timbrada (FI completa, la persona no se presento)
            --   Excluir si es fin de semana Y (ADMIN  O  sin turno asignado).
            --
            --   "Sin turno asignado" = HORARIO_INGRESO NULL o 00:00 → T-Control
            --   no genero un registro de jornada para ese dia.
            --
            --   Si HORARIO_INGRESO tiene hora real (06:00, 14:00, 18:00, 22:00...)
            --   significa que el colaborador SI tenia turno ese sabado/domingo
            --   (PROD-MANANA/TARDE/VELADA, ROTATIVO 3) → FI valida.
            -- =======================================================================
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
    PeriodoEtiqueta, ModalidadNombre, Turno_Hora_Entrada, Turno_Hora_Salida, Horas_Diarias_Turno,
    Trabaja_Sabado, Trabaja_Domingo, Descripcion_Jornada, Codigo_Reporte, Descripcion_Reporte,
    Horas_Permiso_Calculadas, Ciudad_Sede
FROM Data_CTE
WHERE
    -- Mostrar si TIENE hora (atraso real),
    -- O si NO tiene hora (falta) SOLO si no hubo timbradas validas ese mismo dia
    (Hora_Inicio_Permiso IS NOT NULL)
    OR (Conteo_Asistencia_Valida = 0);
GO
