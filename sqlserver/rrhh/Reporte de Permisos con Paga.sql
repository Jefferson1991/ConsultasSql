/* ============================================================
   20 - Consulta completa de permisos con período (21 al 20)
   Replica los datos de la pantalla "Asignación de Permisos"
   + período al que pertenece + estado de exportación
   ============================================================ */

-- Filtros opcionales (NULL = todos)
DECLARE @emp_id               VARCHAR(10) = NULL;   -- ej: '006259'
DECLARE @anio                 INT         = 2026;
DECLARE @periodo              INT         = 6;   -- ej: 6
DECLARE @fecha_inicio_periodo DATE        = NULL;   -- ej: '2026-06-21'
DECLARE @fecha_fin_periodo    DATE        = NULL;   -- ej: '2026-07-20'

SELECT
    /* ---- EMPLEADO (pantalla: Código, Apellido, Nombre) ---- */
    p.E_EMPID                              AS codigo_empleado,
    ve.NOMINA_COD                          AS cedula,
    ve.NOMINA_APE                          AS apellido,
    ve.NOMINA_NOM                          AS nombre,
    ve.NOMINA_APE + ' ' + ve.NOMINA_NOM    AS nombre_completo,

    /* ---- PERIODO (corte 21 al 20) ---- */
    per.anio,
    per.periodo,
    per.fecha_inicial                      AS periodo_desde,
    per.fecha_final                        AS periodo_hasta,

    /* ---- RANGO DE PERMISO (pantalla: Salida / Ingreso) ---- */
    p.E_FINICIO                            AS salida,
    p.E_FFINAL                             AS ingreso,

    /* ---- DESCRIPCION DEL PERMISO ---- */
    cd.CD_NOM                              AS tipo_permiso,          -- PERMISO SIN PAGA
    p.E_TIPOP                              AS codigo_tipo,           -- SP
    cm.C_NOM                               AS categoria,             -- PERMISOS ESPECIALES
    CASE p.E_FPAG
        WHEN 1 THEN 'CON PAGA'
        ELSE 'SIN PAGA (Permiso No Pagado)'
    END                                    AS estado_paga,
    p.E_FPAG                               AS E_FPAG,                -- 0=exportable, 1=no exporta
    CASE p.E_FDIA
        WHEN 1 THEN 'SI'
        ELSE 'NO'
    END                                    AS todo_el_dia,
    CONVERT(VARCHAR(5), p.E_HoraI, 108)    AS hora_desde,            -- 00:00
    CONVERT(VARCHAR(5), p.E_HoraF, 108)    AS hora_hasta,            -- 00:00
    p.E_Turno                              AS turno,                 -- 1=1er Turno
    CASE p.E_Turno
        WHEN 1 THEN '1er Turno'
        WHEN 2 THEN '2do Turno'
        WHEN 3 THEN '3er Turno'
        ELSE CAST(p.E_Turno AS VARCHAR(10))
    END                                    AS turno_descripcion,
    p.E_HORAS                              AS horas_permiso,

    /* ---- AUDITORIA ---- */
    p.PA_FH_REGISTRADO                     AS fecha_registro,
    p.U_ID                                 AS usuario_registro,

    /* ---- CONSOLIDACION Y EXPORTACION ---- */
    h.AH_MIN_NOPAGADOS,
    h.AH_MIN_PAGADOS,
    e.CANTIDAD_CALCULO                     AS horas_a_exportar,
    e.codigo_concepto2,
    CASE
        WHEN e.CODIGO IS NOT NULL
            THEN 'SI PASA A EXPORTACION'
        WHEN h.emp_id IS NULL
            THEN 'NO PASA - periodo no consolidado'
        WHEN ISNULL(h.AH_MIN_NOPAGADOS, 0) = 0
            THEN 'NO PASA - AH_MIN_NOPAGADOS = 0'
        ELSE 'NO PASA - otro motivo'
    END                                    AS estado_exportacion

FROM dbo.TBL_PERM_AUS p
INNER JOIN dbo.TBL_CAT_DETALLE cd
    ON cd.CD_ID = p.E_TIPOP AND cd.CD_CAT = p.E_TIPOM
INNER JOIN dbo.TBL_CAT_MAESTRO cm
    ON cm.C_ID = cd.CD_CAT
INNER JOIN dbo.ViewEmpleados ve
    ON ve.NOMINA_ID = p.E_EMPID
INNER JOIN dbo.TBL_PERIODO per
    ON p.E_FINICIO BETWEEN per.fecha_inicial AND per.fecha_final
LEFT JOIN dbo.TBL_ASISTENCIA_HIS h
    ON h.emp_id  = p.E_EMPID
   AND h.anio    = per.anio
   AND h.periodo = per.periodo
LEFT JOIN dbo.ViewExportEmpaqplast e
    ON e.CODIGO  = p.E_EMPID
   AND e.anio    = per.anio
   AND e.periodo = per.periodo
   AND e.codigo_concepto = 2018

WHERE (@emp_id IS NULL OR p.E_EMPID = @emp_id)
  AND (@anio IS NULL OR per.anio = @anio)
  AND (@periodo IS NULL OR per.periodo = @periodo)
  AND (
        @fecha_inicio_periodo IS NULL
        OR per.fecha_inicial >= @fecha_inicio_periodo
      )
  AND (
        @fecha_fin_periodo IS NULL
        OR per.fecha_final <= @fecha_fin_periodo
      )
  AND  p.E_TIPOP IN ('SP') --AND p.E_FPAG IN (1)

ORDER BY
    per.anio,
    per.periodo,
    p.E_EMPID,
    p.E_FINICIO;




SELECT cd.CD_PAGADO, p.E_FPAG,
       CASE WHEN cd.CD_PAGADO = p.E_FPAG THEN 'OK' ELSE 'ERROR' END AS validacion
FROM dbo.TBL_PERM_AUS p
INNER JOIN dbo.TBL_CAT_DETALLE cd ON cd.CD_ID = p.E_TIPOP AND cd.CD_CAT = p.E_TIPOM
WHERE p.E_EMPID = '006407' AND CAST(p.E_FINICIO AS DATE) = '2026-07-06';












