-- =============================================================================
-- ALTER VIEW: dbo.vm_atrasos
-- Base de datos : TH (192.168.20.15 / SRV-APP\SQLEXPRESS)
-- Autor         : Jefferson Vasconez
-- Fecha         : 2026-03-16
--
-- ┌─────────────────────────────────────────────────────────────────────────────────────────┐
-- │                         CUADRO MANEJO DE HORARIOS                                       │
-- ├───────────────────────┬──────────────────────────────┬──────────────────────────────────┤
-- │ NOMBRE DEL HORARIO    │ HORARIO QUE SE TRABAJA        │ CONDICIONES                      │
-- ├───────────────────────┼──────────────────────────────┼──────────────────────────────────┤
-- │ PRUEBA ROTATIVO 3     │ Modalidad 4-2 rotativo:       │ Tomar en cuenta que si a los     │
-- │ (UIO - EMPAQPLAST)    │ 4 dias 06h00-18h00,           │ colaboradores les cae su 1ro,    │
-- │ Modalidades:          │ 2 libres,                     │ 2do, 3ro o 4to dia en FDS o      │
-- │ PRUEBA_ROTATIVO_3     │ 4 dias 18h00-06h00,           │ feriado es como su lunes a       │
-- │ PRUEBA_ROTATIVO       │ 2 libres                      │ viernes independientemente de    │
-- │ PRUEBA_ROTATIVA2      │                               │ que dia les caiga. Asimismo los  │
-- │ HORARIO_ROT_GRUP_1/2/3│                               │ descansos pueden ser lun-mar,    │
-- │ T_MOLDE_ROTATIVO      │                               │ mar-mie, mie-jue, jue-vie, vie,  │
-- │                       │                               │ sab, sab-dom, dom-lun.           │
-- │                       │                               │ → Trabaja_Sab=1, Dom=1 (UIO)     │
-- │                       │                               │ → FI valida si HORARIO asignado  │
-- ├───────────────────────┼──────────────────────────────┼──────────────────────────────────┤
-- │ ADMINISTRATIVO HE     │ 8 horas, solamente de 8 a 17 │ LOS FINES DE SEMANA NI FERIADOS  │
-- │ Modalidades:          │                               │ NO SE TRABAJA.                   │
-- │ %ADMIN%               │                               │ → Trabaja_Sab=0, Dom=0           │
-- │                       │                               │ → FI y atraso en FDS excluidos   │
-- ├───────────────────────┼──────────────────────────────┼──────────────────────────────────┤
-- │ PROD - MANANA         │ 8 horas de 06 a 14            │ TODOS ESTOS HORARIOS             │
-- │ PROD - TARDE          │ 8 horas de 14 a 22            │ CORRESPONDEN A LOGISTICA,        │
-- │ PROD - VELADA         │ 8 horas de 22 a 06            │ TALLER DE MOLDES,                │
-- │ Modalidades:          │                               │ MANTENIMIENTO.                   │
-- │ PROD. MANANA          │                               │ A VECES LOS PROGRAMAN EN         │
-- │ PROD. TARDE           │                               │ FINES DE SEMANA.                 │
-- │ PROD. VELADA          │                               │ → Trabaja_Sab/Dom = M_6/M_7      │
-- │ + variantes SYD       │                               │   de T-Control (sin override)    │
-- │                       │                               │ → FI valida si HORARIO asignado  │
-- ├───────────────────────┼──────────────────────────────┼──────────────────────────────────┤
-- │ GYE                   │ Modalidad 4-2 rotativo igual  │ En Guayaquil, dependiendo de la  │
-- │ (LOGISTPLAST)         │ que PRUEBA ROT 3.             │ programacion, NO SUELEN TRABAJAR │
-- │ Modalidades:          │ A veces trabajan turno        │ FINES DE SEMANA NI FERIADOS.     │
-- │ PRUEBA_ROTATIVO_3     │ integra de 12 horas           │ → Trabaja_Sab=0, Dom=0           │
-- │ y otras rotativas     │                               │ → FI en FDS excluida siempre     │
-- ├───────────────────────┼──────────────────────────────┼──────────────────────────────────┤
-- │ PERSONAL DE MOLINO    │ Modalidad 12 horas de         │ DE VEZ EN CUANDO TRABAJAN        │
-- │ UIO (EMPAQPLAST)      │ Lunes a Viernes               │ FINES DE SEMANA.                 │
-- │ Modalidad:            │                               │ M_6=1, M_7=1 en T-Control es    │
-- │ PLANTA 06 A 18:       │                               │ error de configuracion.          │
-- │ (M_ID=209)            │                               │ → Trabaja_Sab=0, Dom=0           │
-- │                       │                               │ → FI en FDS excluida; si         │
-- │                       │                               │   trabajan FDS timbran y el      │
-- │                       │                               │   atraso aparece por Caso 1      │
-- └───────────────────────┴──────────────────────────────┴──────────────────────────────────┘
--
-- NOTA MODALIDADES SYD: PROD. 06-18 SYD, PROD.18-06 SYD, PROD 06-14 SYD,
--   PROD 14-22 SYD, PROD 22-06 SYD, PROD MOD 07-18 SYD.
--   SYD = Sabado Y Domingo. M_6=1, M_7=1 CORRECTO en T-Control. No se modifican.
--
-- PENDIENTE - Feriados:
--   No existe tabla de feriados en la BD. La regla del cuadro sobre feriados
--   (especialmente PRUEBA ROTATIVO 3: "si cae feriado cuenta como dia habil")
--   no se puede implementar hasta crear/cargar dicha tabla.
-- =============================================================================

USE TH;
GO

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

        -- -----------------------------------------------------------------------
        -- TRABAJA_SABADO / TRABAJA_DOMINGO  (fuente: cuadro de manejo de horarios)
        -- -----------------------------------------------------------------------
        CASE
            -- [CUADRO: ADMINISTRATIVO HE] "Los fines de semana ni feriados no se trabaja"
            -- M_6/M_7 configurados como 1 en T-Control → error; se corrige a 0
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                      THEN 0

            -- [CUADRO: PERSONAL MOLINO UIO] "Modalidad 12 horas de Lunes a Viernes"
            -- PLANTA 06 A 18: (M_ID=209) tiene M_6=1, M_7=1 → error en T-Control; se corrige a 0
            -- Las modalidades SYD (PROD. 06-18 SYD, etc.) tienen M_6/M_7 correctos → no se tocan
            WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'                                 THEN 0

            -- [CUADRO: GYE] "En Guayaquil no suelen trabajar fines de semana ni feriados"
            -- Aplica a rotativos de LOGISTPLAST (PRUEBA_ROTATIVO_3, etc.)
            WHEN (M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
               OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
               OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO')
             AND T0.EMPE_NOM LIKE '%LOGISTPLAST%'                                  THEN 0

            -- [CUADRO: PRUEBA ROTATIVO 3 - UIO] "Si el 1ro-4to dia del ciclo cae en
            -- FDS o feriado, es como su lunes a viernes independientemente del dia"
            -- M_6=0, M_7=0 en T-Control → error; se fuerza 1 para UIO (EMPAQPLAST)
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                THEN 1

            -- [CUADRO: PROD-MANANA/TARDE/VELADA + SYD] "A veces los programan en FDS"
            -- Se respeta M_6/M_7 de T-Control tal cual (SYD tienen M_6=1/M_7=1 correctos)
            ELSE ISNULL(M_Asis.M_6, 0)
        END AS Trabaja_Sabado,
        CASE
            -- [CUADRO: ADMINISTRATIVO HE] "Los fines de semana ni feriados no se trabaja"
            WHEN M_Asis.M_DES LIKE '%ADMIN%'                                      THEN 0
            -- [CUADRO: PERSONAL MOLINO UIO] "Modalidad 12 horas de Lunes a Viernes"
            WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'                                 THEN 0
            -- [CUADRO: GYE] "En Guayaquil no suelen trabajar fines de semana ni feriados"
            WHEN (M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
               OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
               OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO')
             AND T0.EMPE_NOM LIKE '%LOGISTPLAST%'                                  THEN 0
            -- [CUADRO: PRUEBA ROTATIVO 3 - UIO] Ciclo 4-2, FDS cuenta como dia habil
            WHEN M_Asis.M_DES LIKE 'PRUEBA_ROTATIV%'
              OR M_Asis.M_DES LIKE 'HORARIO_ROT%'
              OR M_Asis.M_DES = 'T_MOLDE_ROTATIVO'                                THEN 1
            -- [CUADRO: PROD-MANANA/TARDE/VELADA + SYD] Respetar M_6/M_7 de T-Control
            ELSE ISNULL(M_Asis.M_7, 0)
        END AS Trabaja_Domingo,

        -- -----------------------------------------------------------------------
        -- DESCRIPCION_JORNADA  (fuente: cuadro de manejo de horarios)
        -- -----------------------------------------------------------------------
        CAST(
            CASE
                -- [CUADRO: ADMINISTRATIVO HE] Lun-Vie, 8h
                WHEN M_Asis.M_DES LIKE '%ADMIN%'               THEN 'Lun - Vie'
                -- [CUADRO: PERSONAL MOLINO UIO] Lun-Vie, 12h
                WHEN M_Asis.M_DES = 'PLANTA 06 A 18:'          THEN 'Lun - Vie'
                -- [CUADRO: PRUEBA ROTATIVO 3 / GYE] Rotativo ciclo 4-2
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
            -- ===================================================================
            -- Caso 1: CON timbrada fisica (atraso real, la persona si llego)
            -- -------------------------------------------------------------------
            -- [CUADRO: ADMINISTRATIVO HE] "Los fines de semana ni feriados no
            --   se trabaja" → excluir atraso en FDS para ADMIN
            -- [CUADRO: PROD-MANANA/TARDE/VELADA] "A veces los programan en FDS"
            --   → si timbro en FDS el atraso es real, se incluye
            -- [CUADRO: PRUEBA ROTATIVO 3 - UIO] "Si el dia del ciclo cae en FDS
            --   cuenta como dia habil" → si timbro, atraso real, se incluye
            -- [CUADRO: GYE / PERSONAL MOLINO UIO] Si excepcionalmente fueron
            --   programados en FDS y timbro, el atraso es real, se incluye
            -- ===================================================================
            (
                T1.HORA_INGRESO IS NOT NULL AND T1.HORA_SALIDA IS NOT NULL
                AND NOT (
                    DATEDIFF(day, '19000101', T1.FECHA_INGRESO) % 7 IN (5, 6)
                    -- [CUADRO: ADMINISTRATIVO HE] Nunca trabaja FDS
                    AND M_Asis.M_DES LIKE '%ADMIN%'
                )
            )
            OR
            -- ===================================================================
            -- Caso 2: SIN timbrada (FI completa, la persona no se presento)
            -- -------------------------------------------------------------------
            -- Excluir FI en FDS segun cuadro:
            --
            -- [CUADRO: ADMINISTRATIVO HE] "Los fines de semana ni feriados no
            --   se trabaja" → FI en FDS siempre excluida
            --
            -- [CUADRO: PERSONAL MOLINO UIO] "Modalidad 12 horas Lunes a Viernes"
            --   PLANTA 06 A 18: (M_ID=209): M_6/M_7=1 es error en T-Control.
            --   Si de vez en cuando trabajan FDS tendran timbrada (Caso 1).
            --   FI en FDS se excluye.
            --
            -- [CUADRO: GYE] "En Guayaquil no suelen trabajar fines de semana
            --   ni feriados" → FI en FDS excluida para toda LOGISTPLAST
            --
            -- [CUADRO: PRUEBA ROTATIVO 3 - UIO] "Si el 1ro-4to dia del ciclo
            --   cae en FDS cuenta como dia habil" → FI valida si
            --   HORARIO_INGRESO tiene hora real (T-Control asigno turno ese dia)
            --
            -- [CUADRO: PROD-MANANA/TARDE/VELADA] "A veces los programan en FDS"
            --   → FI valida si HORARIO_INGRESO tiene hora real asignada
            -- ===================================================================
            (
                T1.HORA_INGRESO IS NULL AND T1.HORA_SALIDA IS NULL
                AND NOT (
                    DATEDIFF(day, '19000101', T1.FECHA_INGRESO) % 7 IN (5, 6)
                    AND (
                        -- [CUADRO: ADMINISTRATIVO HE]
                        M_Asis.M_DES LIKE '%ADMIN%'
                        -- [CUADRO: PERSONAL MOLINO UIO - PLANTA 06 A 18:]
                        OR M_Asis.M_DES = 'PLANTA 06 A 18:'
                        -- [CUADRO: GYE] Toda LOGISTPLAST excluida en FDS
                        OR T0.EMPE_NOM LIKE '%LOGISTPLAST%'
                        -- Sin turno asignado ese dia: T-Control no genero jornada
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
