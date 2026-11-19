-- =============================================================
-- Base de datos : TCONTROL
-- Descripcion   : Consulta completa de asistencia por empleado
-- Servidor      : SRV-BIOM-001\SQLEXPRESS2008R2
-- Autor         : Jefferson Vasconez
-- Fecha         : 2026-03-08
-- =============================================================

SELECT
    -- -------------------------------------------------------
    -- IDENTIFICACION DEL EMPLEADO
    -- -------------------------------------------------------
    E.NOMINA_ID             AS Codigo_Empleado,
    E.NOMINA_COD            AS Cedula,
    E.NOMINA_APE + ' ' + E.NOMINA_NOM  AS Nombre_Completo,
    E.AREA_NOM              AS Area,
    E.DEP_NOM               AS Departamento,
    E.EMPE_NOM              AS Empresa,
    E.NOMINA_FING           AS Fecha_Ingreso_Empresa,

    -- -------------------------------------------------------
    -- PERIODO Y TURNO
    -- -------------------------------------------------------
    A.Anio,
    A.Periodo,
    A.Turno,
    A.modalidad,
    A.horario,

    -- -------------------------------------------------------
    -- FECHAS Y HORARIOS PROGRAMADOS
    -- -------------------------------------------------------
    A.Fecha_Ingreso,
    A.Fecha_Salida,
    A.Salida_Dia_Sgte,
    A.Horario_Ingreso,
    A.Horario_Salida,
    A.Horario_Ingreso_Gracia,
    A.Horario_salida_gracia,

    -- -------------------------------------------------------
    -- MARCACIONES REALES
    -- -------------------------------------------------------
    A.A_MARCACION_INGRESO   AS Marcacion_Ingreso,
    A.A_MARCACION_SALIDA    AS Marcacion_Salida,
    A.Hora_Ingreso,
    A.Hora_Salida,

    -- -------------------------------------------------------
    -- ALMUERZO
    -- -------------------------------------------------------
    A.Lunch_Salida,
    A.Lunch_Ingreso,
    A.Lunch_Total           AS Min_Almuerzo,

    -- -------------------------------------------------------
    -- HORAS LABORADAS Y ESTADO
    -- -------------------------------------------------------
    A.Horas_Laboradas,
    A.No_Laborado,
    A.Novedad_Entrada,
    A.Novedad_Salida,
    A.Estado,

    -- -------------------------------------------------------
    -- ATRASOS
    -- -------------------------------------------------------
    A.Atrasos,
    A.Atraso_con_gracia,
    A.min_AT                AS Min_Atraso,

    -- -------------------------------------------------------
    -- SALIDA ANTICIPADA
    -- -------------------------------------------------------
    A.Tiempo_Anticipado,
    A.SA_con_gracia,
    A.min_SA                AS Min_Salida_Anticipada,

    -- -------------------------------------------------------
    -- HORAS EXTRAS (minutos por recargo)
    -- -------------------------------------------------------
    A.min_25,
    A.min_50,
    A.min_75,
    A.min_100,
    A.min_125,
    A.min_150,
    A.min_175,
    A.min_200,
    A.A_MIN_150_RECARGO,
    A.A_MIN_200_RECARGO,
    A.Hora_Extra_Tiempo,
    A.Hora_Ex_Aprobado,
    A.Hora_Ex_User_Aprueba,
    A.Hora_Ex_Fecha_Aprueba,

    -- -------------------------------------------------------
    -- HORAS NOCTURNAS Y MINUTOS PAGADOS/NO PAGADOS
    -- -------------------------------------------------------
    A.A_min_nocturnos,
    A.A_MIN_PAGADOS,
    A.A_MIN_NOPAGADOS,

    -- -------------------------------------------------------
    -- JUSTIFICACIONES DE ENTRADA
    -- -------------------------------------------------------
    A.Justifica,
    A.Motivo                AS Motivo_Entrada,
    A.Just_Ingreso_Mot,
    A.Hora_ingreso_jus,
    A.Usuario_Justifica,
    A.Usuario_Justifica_RH,
    A.Fecha_Justif,

    -- -------------------------------------------------------
    -- JUSTIFICACIONES DE SALIDA
    -- -------------------------------------------------------
    A.justifica_sal,
    A.motivo_sal            AS Motivo_Salida,
    A.Just_Salida_Mot,
    A.Hora_salida_jus,
    A.Usuario_Justifica_Sal,
    A.Usuario_Justifica_RH_Sal,
    A.Fecha_Just_Sal,

    -- -------------------------------------------------------
    -- VERIFICACION
    -- -------------------------------------------------------
    A.Verificado,
    A.UserVerifica,

    -- -------------------------------------------------------
    -- CENTRO DE COSTO Y LINEA DE PRODUCCION
    -- -------------------------------------------------------
    A.CC                    AS Centro_Costo,
    A.LP                    AS Linea_Produccion

FROM dbo.ViewEmpleados E
INNER JOIN dbo.TBL_ASISTENCIA A ON E.NOMINA_ID = A.EMP_ID

-- -------------------------------------------------------
-- FILTROS (ajustar segun necesidad)
-- -------------------------------------------------------
WHERE A.Anio = YEAR(GETDATE())
-- AND E.NOMINA_COD = '0912345678'     -- filtrar por cedula
-- AND E.NOMINA_ID  = '000002'         -- filtrar por codigo
-- AND E.DEP_NOM    = 'PRODUCCION'     -- filtrar por departamento
-- AND A.Periodo    = 3                -- filtrar por periodo
-- AND A.Fecha_Ingreso BETWEEN '2026-01-01' AND '2026-03-08'

ORDER BY E.NOMINA_COD, A.Fecha_Ingreso DESC;
