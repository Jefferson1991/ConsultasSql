-- ============================================================================
-- CONSULTAS DASHBOARD POWER BI - TCONTROL + ONLYCONTROL
-- ============================================================================
-- Base de datos: sqlserver-timecontrol (TCONTROL) + sqlserver-onlycontrol (ONLYCONTROL)
-- Propósito: Consultas integrales para Dashboard de RRHH y Asistencia
-- Creado: 2026-04-13
-- ============================================================================

-- ============================================================================
-- CONSULTA 1: DATOS MAESTROS DE EMPLEADOS (ONLYCONTROL)
-- Propósito: Tabla dimensional base de empleados para todos los dashboards
-- ============================================================================
SELECT 
    n.NOMINA_ID AS empleado_id,
    n.NOMINA_NOM AS nombres,
    n.NOMINA_APE AS apellidos,
    n.NOMINA_COD AS codigo_identificacion,
    n.NOMINA_TIPO AS tipo_usuario,
    a.AREA_NOM AS area_nombre,
    a.AREA_DES AS area_descripcion,
    d.DEP_NOM AS departamento_nombre,
    d.DEP_DESC AS departamento_descripcion,
    c.CALI_NOM AS cargo_nombre,
    c.CALI_DES AS cargo_nivel,
    e.EMPE_NOM AS empresa_nombre,
    e.EMPE_RUC AS empresa_ruc,
    n.NOMINA_FING AS fecha_ingreso,
    n.NOMINA_FSAL AS fecha_salida,
    n.NOMINA_TIPOID AS tipo_identificacion,
    n.NOMINA_CARD AS tarjeta_rfid,
    CASE 
        WHEN n.NOMINA_FSAL IS NOT NULL THEN 'Inactivo'
        ELSE 'Activo'
    END AS estado_empleado,
    nd.NOMINA_DIRECCION AS direccion,
    nd.NOMINA_TELEFONO AS telefono,
    nd.NOMINA_CELULAR AS celular,
    nd.NOMINA_DISCAPACIDAD AS flag_discapacidad,
    nd.NOMINA_ALERGIAS AS alergias,
    tp.TIPO_NOM AS tipo_autenticacion
FROM NOMINA n
LEFT JOIN AREA a ON n.NOMINA_AREA = a.AREA_ID
LEFT JOIN DPTO d ON n.NOMINA_DEP = d.DEP_ID
LEFT JOIN CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
LEFT JOIN EXTERNOE e ON n.NOMINA_EMP = e.EMPE_ID
LEFT JOIN NOMINA_DATOS_ADICIONAL nd ON n.NOMINA_ID = nd.NOMINA_ID
LEFT JOIN TIPO_PERMISO tp ON n.NOMINA_AUT = tp.TIPO_ID
ORDER BY n.NOMINA_ID;


-- ============================================================================
-- CONSULTA 2: RESUMEN DIARIO DE ASISTENCIA (CON NO CUMPLIMIENTO)
-- Propósito: Tabla de hechos principal para dashboard de asistencia diaria
-- Incluye: Estado de cumplimiento, horas no cumplidas, minutos faltantes
-- ============================================================================
SELECT
    a.EMP_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    a.Fecha_Ingreso AS fecha_asistencia,
    DATENAME(WEEKDAY, a.Fecha_Ingreso) AS dia_semana,
    DATEPART(WEEK, a.Fecha_Ingreso) AS numero_semana,
    MONTH(a.Fecha_Ingreso) AS mes,
    YEAR(a.Fecha_Ingreso) AS anio,
    a.Hora_Ingreso AS hora_entrada,
    a.Hora_Salida AS hora_salida,
    a.Hora_Reinicio_Almuerzo AS hora_reinicio_almuerzo,
    a.Hora_Almuerzo AS hora_almuerzo,
    a.Horas_Laboradas AS horas_laboradas,
    a.Atrasos AS minutos_atraso,
    a.Recargo_Nocturno AS minutos_recargo_nocturno,
    a.min_25 AS horas_extra_25_min,
    a.min_50 AS horas_extra_50_min,
    a.min_75 AS horas_extra_75_min,
    a.min_100 AS horas_extra_100_min,
    a.min_125 AS horas_extra_125_min,
    a.min_150 AS horas_extra_150_min,
    a.min_175 AS horas_extra_175_min,
    a.min_200 AS horas_extra_200_min,
    (ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) + 
     ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
     ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) AS total_horas_extra_minutos,
    a.CC AS centro_costo,
    a.LP AS linea_produccion,
    h.H_NOM AS nombre_horario,
    h.H_HRA_ING AS hora_entrada_programada,
    h.H_HRA_SAL AS hora_salida_programada,
    m.M_NOM AS nombre_modalidad,
    m.M_ID AS modalidad_id,
    a.Observacion AS observaciones,
    a.AGENCIA AS agencia,
    
    -- Estado de asistencia original
    CASE 
        WHEN a.Ausente = 1 THEN 'Ausente'
        WHEN a.Atraso = 1 THEN 'Atraso'
        WHEN a.Hora_Cerrada = 1 THEN 'Hora Cerrada'
        ELSE 'Normal'
    END AS estado_asistencia,
    
    -- NUEVO: Estado de cumplimiento (de vm_atrasos)
    vm.Estado_Cumplimiento AS estado_cumplimiento,
    
    -- NUEVO: Horas de salida anticipada (No Cumple)
    CAST(ISNULL(vm.Horas_No_Cumple_Horario, 0) AS DECIMAL(10,2)) AS horas_no_cumple,
    
    -- NUEVO: Minutos totales faltantes
    ISNULL(vm.Minutos_Tiempo_Faltante, 0) AS minutos_faltantes,
    
    -- NUEVO: Descripción combinida
    CASE
        WHEN vm.Estado_Cumplimiento = 'No Cumple Horario' THEN 'No Cumple - Salida Anticipada'
        WHEN a.Ausente = 1 THEN 'Ausente'
        WHEN a.Atraso = 1 THEN 'Atraso'
        WHEN a.Hora_Cerrada = 1 THEN 'Hora Cerrada'
        ELSE 'Cumple Horario'
    END AS descripcion_cumplimiento
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN TBL_T_HORARIOS th ON a.EMP_ID = th.H_EMPID AND a.Fecha_Ingreso = th.H_FECHA
LEFT JOIN TBL_MODALIDAD m ON th.H_IDMOD = m.M_ID
LEFT JOIN TBL_HORARIO h ON m.M_1 = h.H_ID
LEFT JOIN dbo.vm_atrasos vm ON a.EMP_ID = vm.Codigo AND a.Fecha_Ingreso = vm.Fecha_Inicio
ORDER BY a.Fecha_Ingreso DESC, a.EMP_ID;


-- ============================================================================
-- CONSULTA 3: RESUMEN HISTÓRICO SEMANAL DE ASISTENCIA
-- Propósito: Tendencias semanales e indicadores KPI
-- ============================================================================
SELECT 
    h.EMP_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    a.AREA_NOM AS area_nombre,
    h.fecha_desde AS periodo_inicio,
    h.fecha_hasta AS periodo_fin,
    h.ingreso AS total_entradas,
    h.salida AS total_salidas,
    h.ingreso_correcto AS entradas_correctas,
    h.salida_correcta AS salidas_correctas,
    h.AI AS atrasos_injustificados,
    h.AJ AS atrasos_justificados,
    h.NFE AS no_marco_entrada,
    h.NFS AS no_marco_salida,
    h.PES AS salida_temprana,
    h.AI_M AS minutos_atraso_injustificado,
    h.AJ_M AS minutos_atraso_justificado,
    h.HS_M AS minutos_salida_temprana,
    h.H_25 AS horas_extra_25_min,
    h.H_50 AS horas_extra_50_min,
    h.H_75 AS horas_extra_75_min,
    h.H_100 AS horas_extra_100_min,
    h.H_125 AS horas_extra_125_min,
    h.H_150 AS horas_extra_150_min,
    h.H_175 AS horas_extra_175_min,
    h.H_200 AS horas_extra_200_min,
    (ISNULL(h.H_25, 0) + ISNULL(h.H_50, 0) + ISNULL(h.H_75, 0) + 
     ISNULL(h.H_100, 0) + ISNULL(h.H_125, 0) + ISNULL(h.H_150, 0) + 
     ISNULL(h.H_175, 0) + ISNULL(h.H_200, 0)) AS total_horas_extra_minutos,
    h.domingo_25 AS horas_extra_domingo_25_min,
    h.domingo_50 AS horas_extra_domingo_50_min,
    h.domingo_100 AS horas_extra_domingo_100_min,
    h.festivo_25 AS horas_extra_festivo_25_min,
    h.festivo_50 AS horas_extra_festivo_50_min,
    h.festivo_100 AS horas_extra_festivo_100_min,
    h.vacacion AS dias_vacacion,
    h.pago_vaca AS vacacion_pagada,
    h.no_pago_vaca AS vacacion_no_pagada,
    h.otro_permiso AS otros_permisos,
    h.licencia AS dias_licencia,
    h.calendario AS dias_laborales_esperados,
    h.laborable AS dias_laborables_reales,
    h.CC AS centro_costo,
    h.LP AS linea_produccion
FROM TBL_ASISTENCIA_HIS h
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON h.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA a ON n.NOMINA_AREA = a.AREA_ID
ORDER BY h.fecha_desde DESC, h.EMP_ID;


-- ============================================================================
-- CONSULTA 4: ANÁLISIS DE HORAS EXTRAS
-- Propósito: Dashboard de horas extras por empleado, departamento y porcentaje
-- ============================================================================
SELECT 
    ap.EMP_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    c.CALI_NOM AS cargo_nombre,
    ap.fecha AS fecha_hora_extra,
    ap.rporcentaje AS porcentaje_hora_extra,
    ap.time AS hora_extra_time,
    ap.minutos AS minutos_hora_extra,
    ap.usuario AS usuario_aprobador,
    ap.fecha_aprobacion AS fecha_aprobacion,
    ap.estado AS estado_aprobacion,
    ap.observacion AS observacion,
    ap.estado_envio AS estado_envio,
    th.TIPO_NOM AS tipo_hora_extra,
    CASE ap.rporcentaje
        WHEN 0 THEN 'Horas Normales'
        WHEN 25 THEN 'Recargo 25%'
        WHEN 50 THEN 'Recargo 50%'
        WHEN 75 THEN 'Recargo 75%'
        WHEN 100 THEN 'Recargo 100% (Doble)'
        WHEN 125 THEN 'Recargo 125%'
        WHEN 150 THEN 'Recargo 150%'
        WHEN 175 THEN 'Recargo 175%'
        WHEN 200 THEN 'Recargo 200% (Triple)'
    END AS descripcion_hora_extra,
    -- Factor de costo de hora extra
    CASE ap.rporcentaje
        WHEN 0 THEN 1.0
        WHEN 25 THEN 1.25
        WHEN 50 THEN 1.50
        WHEN 75 THEN 1.75
        WHEN 100 THEN 2.0
        WHEN 125 THEN 2.25
        WHEN 150 THEN 2.50
        WHEN 175 THEN 2.75
        WHEN 200 THEN 3.0
    END AS multiplicador_costo
FROM TBL_ASISTENCIA_APROBACION ap
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON ap.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
LEFT JOIN TBL_TIPO_HORA th ON ap.rporcentaje = th.TIPO_PORC
WHERE ap.minutos > 0
ORDER BY ap.fecha DESC, ap.rporcentaje DESC, ap.EMP_ID;


-- ============================================================================
-- CONSULTA 5: GESTIÓN DE AUSENCIAS Y PERMISOS
-- Propósito: Dashboard de ausencias, vacaciones, licencias por enfermedad
-- ============================================================================
SELECT 
    pa.E_EMPID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    d.DEP_NOM AS departamento_nombre,
    c.CALI_NOM AS cargo_nombre,
    pa.E_NOM AS tipo_permiso_codigo,
    CASE pa.E_NOM
        WHEN 'VC' THEN 'Vacaciones'
        WHEN 'SP' THEN 'Enfermedad'
        WHEN 'LE' THEN 'Permiso Personal'
        WHEN 'DM' THEN 'Cita Médica'
        WHEN 'DL' THEN 'Licencia Maternidad'
        WHEN 'CL' THEN 'Licencia por Duelo'
        WHEN 'PL' THEN 'Licencia Paternal'
        ELSE pa.E_NOM
    END AS descripcion_tipo_permiso,
    pa.E_FECHA_I AS fecha_inicio,
    pa.E_FECHA_F AS fecha_fin,
    DATEDIFF(DAY, pa.E_FECHA_I, pa.E_FECHA_F) + 1 AS dias_permiso,
    pa.E_HORA_I AS hora_inicio,
    pa.E_HORA_F AS hora_fin,
    pa.D_PAG AS es_pagado,
    CASE pa.D_PAG
        WHEN 1 THEN 'Pagado'
        WHEN 0 THEN 'No Pagado'
    END AS estado_pago,
    pa.TURN AS turno,
    pa.E_OBS AS observacion,
    pa.ingreso AS hora_ingreso,
    pa.salida AS hora_salida,
    pa.CC AS centro_costo,
    pa.LP AS linea_produccion
FROM TBL_PERM_AUS pa
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON pa.E_EMPID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.DPTO d ON n.NOMINA_DEP = d.DEP_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
ORDER BY pa.E_FECHA_I DESC, pa.E_EMPID;


-- ============================================================================
-- CONSULTA 6: ANÁLISIS DE JUSTIFICACIONES
-- Propósito: Seguimiento y análisis de justificaciones de asistencia
-- ============================================================================
SELECT 
    j.ID AS justificacion_id,
    j.EMP_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    j.FECHA AS fecha_justificacion,
    j.TIPO AS tipo_justificacion,
    CASE j.TIPO
        WHEN 'NFE' THEN 'No Marcó Entrada'
        WHEN 'NFS' THEN 'No Marcó Salida'
        WHEN 'AI' THEN 'Atraso Injustificado'
        WHEN 'PES' THEN 'Salida Temprana'
        WHEN 'O' THEN 'Otro'
        ELSE j.TIPO
    END AS descripcion_tipo_justificacion,
    j.CODIGO AS motivo_codigo,
    cd.DET_NOM AS motivo_nombre,
    cd.DET_DES AS motivo_descripcion,
    j.OBSERVACION AS observacion,
    j.HORA AS hora_justificacion,
    j.ENVIO AS estado_envio,
    j.USUARIO AS usuario_proceso,
    cm.CAT_NOM AS categoria_nombre
FROM TBL_JUSTIFICACIONES j
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON j.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN TBL_CAT_DETALLE cd ON j.CODIGO = cd.DET_COD AND cd.DET_ESTADO = 1
LEFT JOIN TBL_CAT_MAESTRO cm ON cd.DET_MAESTRO = cm.CAT_ID
ORDER BY j.FECHA DESC, j.EMP_ID;


-- ============================================================================
-- CONSULTA 7: ANÁLISIS DE TIEMPO NO LABORADO
-- Propósito: Analizar horas no trabajadas por empleados
-- ============================================================================
SELECT 
    nl.EMP_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    nl.FECHA AS fecha,
    nl.HORA_DIF AS horas_diferencia,
    nl.H_DIF AS diferencia_tiempo,
    nl.CC AS centro_costo,
    nl.LP AS linea_produccion
FROM TBL_NO_LABORA nl
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON nl.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
ORDER BY nl.FECHA DESC, nl.EMP_ID;


-- ============================================================================
-- CONSULTA 8: REGISTROS BIOMÉTRICOS CRUDOS (MONITOREO TIEMPO REAL)
-- Propósito: Dashboard de monitoreo de asistencia en tiempo real
-- ============================================================================
SELECT 
    t.HA_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    t.HA_Fecha AS fecha_registro,
    t.HA_Registro AS fecha_hora_marcado,
    DATEPART(HOUR, t.HA_Registro) AS hora,
    DATEPART(MINUTE, t.HA_Registro) AS minuto,
    t.HA_Tipo AS tipo_evento,
    CASE t.HA_Tipo
        WHEN 1 THEN 'Entrada'
        WHEN 2 THEN 'Salida'
        ELSE 'Desconocido'
    END AS descripcion_tipo_evento,
    t.HA_MAQ AS dispositivo_id,
    t.HA_IP AS dispositivo_ip,
    t.HA_USER AS dispositivo_usuario,
    t.HA_MANUAL AS es_manual,
    CASE t.HA_MANUAL
        WHEN 1 THEN 'Registro Manual'
        WHEN 0 THEN 'Escaneo Biométrico'
    END AS metodo_registro,
    eq.EQ_NOM AS dispositivo_nombre,
    eq.EQ_IP AS dispositivo_ip_maestro,
    eq.EQ_ESTADO AS dispositivo_estado
FROM TBL_ASISTENCIA_TRACE t
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON t.HA_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN TBL_ASISTENCIA_EQUIPOS eq ON t.HA_IP = eq.EQ_IP
ORDER BY t.HA_Registro DESC;


-- ============================================================================
-- CONSULTA 9: ASIGNACIONES DE HORARIO DE EMPLEADOS
-- Propósito: Ver qué empleados están asignados a qué horarios
-- ============================================================================
SELECT 
    th.H_EMPID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    th.H_FECHA AS fecha_programada,
    DATENAME(WEEKDAY, th.H_FECHA) AS dia_semana,
    th.H_IDMOD AS modalidad_id,
    m.M_NOM AS modalidad_nombre,
    m.M_CANT_SEMANA AS dias_ciclo_semanal,
    -- Horario para cada día de la semana
    h1.H_NOM AS horario_lunes,
    h2.H_NOM AS horario_martes,
    h3.H_NOM AS horario_miercoles,
    h4.H_NOM AS horario_jueves,
    h5.H_NOM AS horario_viernes,
    h6.H_NOM AS horario_sabado,
    h7.H_NOM AS horario_domingo,
    -- Flags de aprobación de horas extras
    m.M_APROBACION_0 AS aprobacion_0_por_ciento,
    m.M_APROBACION_25 AS aprobacion_25_por_ciento,
    m.M_APROBACION_50 AS aprobacion_50_por_ciento,
    m.M_APROBACION_75 AS aprobacion_75_por_ciento,
    m.M_APROBACION_100 AS aprobacion_100_por_ciento
FROM TBL_T_HORARIOS th
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON th.H_EMPID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN TBL_MODALIDAD m ON th.H_IDMOD = m.M_ID
LEFT JOIN TBL_HORARIO h1 ON m.M_1 = h1.H_ID
LEFT JOIN TBL_HORARIO h2 ON m.M_2 = h2.H_ID
LEFT JOIN TBL_HORARIO h3 ON m.M_3 = h3.H_ID
LEFT JOIN TBL_HORARIO h4 ON m.M_4 = h4.H_ID
LEFT JOIN TBL_HORARIO h5 ON m.M_5 = h5.H_ID
LEFT JOIN TBL_HORARIO h6 ON m.M_6 = h6.H_ID
LEFT JOIN TBL_HORARIO h7 ON m.M_7 = h7.H_ID
ORDER BY th.H_FECHA DESC, th.H_EMPID;


-- ============================================================================
-- CONSULTA 10: CATÁLOGO DE DEFINICIONES DE HORARIO
-- Propósito: Definiciones maestras de horarios para referencia
-- ============================================================================
SELECT 
    h.H_ID AS horario_id,
    h.H_NOM AS horario_nombre,
    h.H_HRA_ING AS hora_entrada,
    h.H_HRA_SAL AS hora_salida,
    h.H_HRA_LUNCH AS hora_almuerzo,
    h.H_GRACIA AS minutos_gracia,
    h.H_DESDE1 AS hora_inicio_trabajo,
    h.H_HASTA1 AS hora_fin_trabajo,
    h.H_TIP_HORA_1 AS tipo_hora_extra_1,
    h.H_DES_DES_1 AS descripcion_hora_extra_1,
    h.H_DESDE2 AS hora_inicio_trabajo_2,
    h.H_HASTA2 AS hora_fin_trabajo_2,
    h.H_TIP_HORA_2 AS tipo_hora_extra_2,
    h.H_DES_DES_2 AS descripcion_hora_extra_2,
    h.H_ALMUERZO_MIN AS minutos_almuerzo,
    h.H_REFRIGIO_MIN AS minutos_refrigerio,
    CASE h.H_LIBRE
        WHEN 1 THEN 'Día Libre'
        ELSE 'Día Laboral'
    END AS tipo_dia,
    h.H_HORAS AS horas_esperadas,
    h.H_P1 AS requiere_permiso_1,
    h.H_P2 AS requiere_permiso_2
FROM TBL_HORARIO h
ORDER BY h.H_NOM;


-- ============================================================================
-- CONSULTA 11: RESUMEN DE ASISTENCIA POR DEPARTAMENTO (CON NO CUMPLIMIENTO)
-- Propósito: KPIs a nivel de departamento para dashboard de gestión
-- Incluye: No cumple horario, horas de salida anticipada, minutos faltantes
-- ============================================================================
SELECT
    ar.AREA_NOM AS area_nombre,
    ar.AREA_DES AS area_descripcion,
    COUNT(DISTINCT a.EMP_ID) AS total_empleados,
    COUNT(DISTINCT CASE WHEN a.Ausente = 0 THEN a.EMP_ID END) AS empleados_presentes,
    COUNT(DISTINCT CASE WHEN a.Ausente = 1 THEN a.EMP_ID END) AS empleados_ausentes,
    COUNT(DISTINCT CASE WHEN a.Atraso = 1 THEN a.EMP_ID END) AS empleados_atraso,
    CAST(COUNT(DISTINCT CASE WHEN a.Ausente = 0 THEN a.EMP_ID END) AS FLOAT) /
        NULLIF(COUNT(DISTINCT a.EMP_ID), 0) * 100 AS porcentaje_asistencia,
    AVG(CAST(a.Atrasos AS FLOAT)) AS promedio_minutos_atraso,
    AVG(CAST(a.Horas_Laboradas AS FLOAT)) AS promedio_horas_laboradas,
    SUM(ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) +
        ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) +
        ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) AS total_minutos_horas_extra,
    
    -- NUEVO: No cumple horario (salida anticipada)
    COUNT(DISTINCT CASE WHEN vm.Estado_Cumplimiento = 'No Cumple Horario' THEN a.EMP_ID END) AS empleados_no_cumplen,
    CAST(SUM(ISNULL(vm.Horas_No_Cumple_Horario, 0)) AS DECIMAL(10,2)) AS total_horas_no_cumple,
    SUM(ISNULL(vm.Minutos_Tiempo_Faltante, 0)) AS total_minutos_faltantes,
    
    a.Fecha_Ingreso AS fecha,
    DATENAME(WEEKDAY, a.Fecha_Ingreso) AS dia_semana
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN dbo.vm_atrasos vm ON a.EMP_ID = vm.Codigo AND a.Fecha_Ingreso = vm.Fecha_Inicio
GROUP BY ar.AREA_NOM, ar.AREA_DES, a.Fecha_Ingreso
ORDER BY a.Fecha_Ingreso DESC, ar.AREA_NOM;


-- ============================================================================
-- CONSULTA 12: TENDENCIAS MENSUALES DE ASISTENCIA (CON NO CUMPLIMIENTO)
-- Propósito: Tendencias mensuales para dashboard ejecutivo
-- Incluye: No cumple horario, horas de salida anticipada, minutos faltantes
-- ============================================================================
SELECT
    YEAR(a.Fecha_Ingreso) AS anio,
    MONTH(a.Fecha_Ingreso) AS mes,
    DATENAME(MONTH, a.Fecha_Ingreso) AS nombre_mes,
    COUNT(DISTINCT a.EMP_ID) AS total_registros,
    COUNT(DISTINCT a.EMP_ID) - COUNT(DISTINCT CASE WHEN a.Ausente = 1 THEN a.EMP_ID END) AS total_presentes,
    COUNT(DISTINCT CASE WHEN a.Ausente = 1 THEN a.EMP_ID END) AS total_ausencias,
    COUNT(DISTINCT CASE WHEN a.Atraso = 1 THEN a.EMP_ID END) AS total_atrasos,
    
    -- NUEVO: No cumple horario
    COUNT(DISTINCT CASE WHEN vm.Estado_Cumplimiento = 'No Cumple Horario' THEN a.EMP_ID END) AS empleados_no_cumplen,
    SUM(CASE WHEN vm.Estado_Cumplimiento = 'No Cumple Horario' THEN 1 ELSE 0 END) AS casos_no_cumple,
    
    CAST(SUM(CAST(a.Horas_Laboradas AS FLOAT)) AS DECIMAL(10,2)) AS total_horas_laboradas,
    CAST(SUM(CAST(a.Atrasos AS FLOAT)) AS DECIMAL(10,2)) AS total_minutos_atraso,
    CAST(SUM(ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) +
             ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) +
             ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) AS DECIMAL(10,2)) AS total_minutos_horas_extra,
    
    -- NUEVO: Horas no cumplidas
    CAST(SUM(ISNULL(vm.Horas_No_Cumple_Horario, 0)) AS DECIMAL(10,2)) AS total_horas_no_cumple,
    SUM(ISNULL(vm.Minutos_Tiempo_Faltante, 0)) AS total_minutos_faltantes,
    
    CAST(AVG(CAST(a.Horas_Laboradas AS FLOAT)) AS DECIMAL(10,2)) AS promedio_horas_por_empleado,
    CAST(AVG(CAST(a.Atrasos AS FLOAT)) AS DECIMAL(10,2)) AS promedio_atraso_por_empleado
FROM TBL_ASISTENCIA a
LEFT JOIN dbo.vm_atrasos vm ON a.EMP_ID = vm.Codigo AND a.Fecha_Ingreso = vm.Fecha_Inicio
GROUP BY YEAR(a.Fecha_Ingreso), MONTH(a.Fecha_Ingreso), DATENAME(MONTH, a.Fecha_Ingreso)
ORDER BY YEAR(a.Fecha_Ingreso) DESC, MONTH(a.Fecha_Ingreso) DESC;


-- ============================================================================
-- CONSULTA 13: TOP EMPLEADOS CON MÁS ATRASOS
-- Propósito: Identificar empleados con mayor cantidad de atrasos
-- ============================================================================
SELECT TOP 50
    n.NOMINA_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    c.CALI_NOM AS cargo_nombre,
    COUNT(*) AS total_dias_atraso,
    SUM(CAST(a.Atrasos AS INT)) AS total_minutos_atraso,
    AVG(CAST(a.Atrasos AS FLOAT)) AS promedio_minutos_atraso,
    MIN(a.Hora_Ingreso) AS hora_entrada_mas_temprana,
    MAX(a.Hora_Ingreso) AS hora_entrada_mas_tardia,
    MIN(a.Fecha_Ingreso) AS periodo_inicio,
    MAX(a.Fecha_Ingreso) AS periodo_fin
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
WHERE a.Atraso = 1 OR a.Atrasos > 0
GROUP BY n.NOMINA_ID, n.NOMINA_NOM, n.NOMINA_APE, ar.AREA_NOM, c.CALI_NOM
ORDER BY total_minutos_atraso DESC;


-- ============================================================================
-- CONSULTA 14: TOP EMPLEADOS CON MÁS HORAS EXTRAS
-- Propósito: Identificar empleados con mayor cantidad de horas extras
-- ============================================================================
SELECT TOP 50
    n.NOMINA_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    c.CALI_NOM AS cargo_nombre,
    COUNT(*) AS total_dias_horas_extra,
    SUM(ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) + 
        ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
        ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) AS total_minutos_horas_extra,
    CAST(SUM(ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) + 
        ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
        ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) / 60.0 AS DECIMAL(10,2)) AS total_horas_extra,
    SUM(ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
        ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) AS minutos_horas_extra_alta_tarifa,
    AVG(CAST(a.Horas_Laboradas AS FLOAT)) AS promedio_horas_laboradas
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
WHERE (ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) + 
       ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
       ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) > 0
GROUP BY n.NOMINA_ID, n.NOMINA_NOM, n.NOMINA_APE, ar.AREA_NOM, c.CALI_NOM
ORDER BY total_minutos_horas_extra DESC;


-- ============================================================================
-- CONSULTA 15: RESUMEN POR PERÍODO DE NÓMINA
-- Propósito: Resumen de asistencia y horas extras por período de nómina
-- ============================================================================
SELECT 
    p.PER_INI AS periodo_inicio,
    p.PER_FIN AS periodo_fin,
    p.ESTADO AS periodo_estado,
    CASE p.ESTADO
        WHEN 'A' THEN 'Aprobado'
        WHEN 'P' THEN 'Pendiente'
        ELSE 'Desconocido'
    END AS periodo_estado_descripcion,
    COUNT(DISTINCT a.EMP_ID) AS empleados_con_registros,
    SUM(CAST(a.Horas_Laboradas AS FLOAT)) AS total_horas_laboradas,
    SUM(CAST(a.Atrasos AS FLOAT)) AS total_minutos_atraso,
    SUM(ISNULL(a.min_25, 0)) AS total_he_25_min,
    SUM(ISNULL(a.min_50, 0)) AS total_he_50_min,
    SUM(ISNULL(a.min_75, 0)) AS total_he_75_min,
    SUM(ISNULL(a.min_100, 0)) AS total_he_100_min,
    SUM(ISNULL(a.min_125, 0)) AS total_he_125_min,
    SUM(ISNULL(a.min_150, 0)) AS total_he_150_min,
    SUM(ISNULL(a.min_175, 0)) AS total_he_175_min,
    SUM(ISNULL(a.min_200, 0)) AS total_he_200_min,
    SUM(ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) + 
        ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
        ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) AS total_minutos_horas_extra,
    COUNT(DISTINCT CASE WHEN a.Ausente = 1 THEN a.EMP_ID END) AS total_ausencias,
    COUNT(DISTINCT CASE WHEN a.Atraso = 1 THEN a.EMP_ID END) AS total_atrasos
FROM TBL_PERIODO p
LEFT JOIN TBL_ASISTENCIA a ON a.Fecha_Ingreso BETWEEN p.PER_INI AND p.PER_FIN
GROUP BY p.PER_INI, p.PER_FIN, p.ESTADO
ORDER BY p.PER_INI DESC;


-- ============================================================================
-- CONSULTA 16: UTILIZACIÓN DE DISPOSITIVOS BIOMÉTRICOS
-- Propósito: Monitorear uso y estado de dispositivos biométricos
-- ============================================================================
SELECT 
    eq.EQ_ID AS dispositivo_id,
    eq.EQ_NOM AS dispositivo_nombre,
    eq.EQ_IP AS dispositivo_ip,
    eq.EQ_ESTADO AS dispositivo_estado,
    eq.EQ_MARCA AS dispositivo_marca,
    eq.EQ_MODELO AS dispositivo_modelo,
    COUNT(t.HA_ID) AS total_marcados,
    COUNT(DISTINCT t.HA_ID) AS empleados_unicos,
    MIN(t.HA_Registro) AS primer_marcado,
    MAX(t.HA_Registro) AS ultimo_marcado,
    COUNT(DISTINCT t.HA_Fecha) AS dias_activos,
    CAST(COUNT(t.HA_ID) AS FLOAT) / NULLIF(COUNT(DISTINCT t.HA_Fecha), 0) AS promedio_marcados_por_dia
FROM TBL_ASISTENCIA_EQUIPOS eq
LEFT JOIN TBL_ASISTENCIA_TRACE t ON eq.EQ_IP = t.HA_IP
GROUP BY eq.EQ_ID, eq.EQ_NOM, eq.EQ_IP, eq.EQ_ESTADO, eq.EQ_MARCA, eq.EQ_MODELO
ORDER BY total_marcados DESC;


-- ============================================================================
-- CONSULTA 17: CALENDARIO DE FESTIVOS
-- Propósito: Tabla de referencia de días festivos para programación
-- ============================================================================
SELECT 
    F_ID AS festivo_id,
    F_FECHA AS fecha_festivo,
    F_DET AS descripcion_festivo,
    F_LOCAL AS localidad,
    F_TIPO AS tipo_festivo,
    DATENAME(WEEKDAY, F_FECHA) AS dia_semana
FROM TBL_FESTIVOS
ORDER BY F_FECHA;


-- ============================================================================
-- CONSULTA 18: MATRIZ DE PERMISOS DE EMPLEADOS
-- Propósito: Dashboard de permisos de usuario y control de acceso
-- ============================================================================
SELECT 
    p.USER AS nombre_usuario,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    p.PWD AS password_hash,
    p.TIPO AS tipo_usuario,
    p.EMPID AS empleado_id,
    -- Flags de permisos (muestra de permisos clave)
    p.P1 AS perm_1, p.P2 AS perm_2, p.P3 AS perm_3, p.P4 AS perm_4,
    p.P5 AS perm_5, p.P6 AS perm_6, p.P7 AS perm_7, p.P8 AS perm_8,
    p.P9 AS perm_9, p.P10 AS perm_10,
    -- Agregar más según necesidad: p.P11 hasta p.P41
    p.USU_CRE AS creado_por,
    p.FECHA AS fecha_creacion
FROM TBL_PERMISOS p
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON p.EMPID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
ORDER BY p.USER;


-- ============================================================================
-- CONSULTA 19: REGISTRO DE ACTIVIDAD DEL SISTEMA
-- Propósito: Pista de auditoría y monitoreo de uso del sistema
-- ============================================================================
SELECT TOP 1000
    l.LOG_ID AS log_id,
    l.IP AS direccion_ip,
    l.USER AS nombre_usuario,
    l.FECHA AS fecha_actividad,
    l.PC AS nombre_computadora,
    l.ACCION AS accion,
    l.DESCRIPCION AS descripcion
FROM TBL_LOG l
ORDER BY l.FECHA DESC;


-- ============================================================================
-- CONSULTA 20: VISTA INTEGRAL 360 DEL EMPLEADO
-- Propósito: Perfil completo de un solo empleado para análisis detallado
-- ============================================================================
-- Reemplazar '000001' con el ID de empleado deseado
SELECT 
    -- Datos Maestros del Empleado
    n.NOMINA_ID AS empleado_id,
    n.NOMINA_NOM AS nombres,
    n.NOMINA_APE AS apellidos,
    n.NOMINA_COD AS codigo_identificacion,
    n.NOMINA_TIPO AS tipo_usuario,
    ar.AREA_NOM AS area_nombre,
    d.DEP_NOM AS departamento_nombre,
    c.CALI_NOM AS cargo_nombre,
    e.EMPE_NOM AS empresa_nombre,
    n.NOMINA_FING AS fecha_ingreso,
    n.NOMINA_FSAL AS fecha_salida,
    DATEDIFF(YEAR, n.NOMINA_FING, GETDATE()) AS anos_servicio,
    nd.NOMINA_CELULAR AS celular,
    nd.NOMINA_DIRECCION AS direccion,
    
    -- Estadísticas del Período Actual (últimos 30 días)
    (SELECT COUNT(*) FROM TBL_ASISTENCIA WHERE EMP_ID = n.NOMINA_ID 
     AND Fecha_Ingreso >= DATEADD(DAY, -30, GETDATE())) AS dias_presentes_30d,
    (SELECT COUNT(*) FROM TBL_ASISTENCIA WHERE EMP_ID = n.NOMINA_ID 
     AND Fecha_Ingreso >= DATEADD(DAY, -30, GETDATE()) AND (Atraso = 1 OR Atrasos > 0)) AS dias_atraso_30d,
    (SELECT COUNT(*) FROM TBL_ASISTENCIA WHERE EMP_ID = n.NOMINA_ID 
     AND Fecha_Ingreso >= DATEADD(DAY, -30, GETDATE()) AND Ausente = 1) AS dias_ausente_30d,
    (SELECT SUM(CAST(Horas_Laboradas AS FLOAT)) FROM TBL_ASISTENCIA 
     WHERE EMP_ID = n.NOMINA_ID AND Fecha_Ingreso >= DATEADD(DAY, -30, GETDATE())) AS horas_laboradas_30d,
    (SELECT SUM(ISNULL(min_25, 0) + ISNULL(min_50, 0) + ISNULL(min_75, 0) + 
                ISNULL(min_100, 0) + ISNULL(min_125, 0) + ISNULL(min_150, 0) + 
                ISNULL(min_175, 0) + ISNULL(min_200, 0)) 
     FROM TBL_ASISTENCIA WHERE EMP_ID = n.NOMINA_ID 
     AND Fecha_Ingreso >= DATEADD(DAY, -30, GETDATE())) AS minutos_horas_extra_30d,
    
    -- Resumen de Permisos
    (SELECT COUNT(*) FROM TBL_PERM_AUS WHERE E_EMPID = n.NOMINA_ID) AS total_permisos,
    (SELECT COUNT(*) FROM TBL_PERM_AUS WHERE E_EMPID = n.NOMINA_ID AND E_NOM = 'VC') AS permisos_vacaciones,
    (SELECT COUNT(*) FROM TBL_PERM_AUS WHERE E_EMPID = n.NOMINA_ID AND E_NOM = 'SP') AS permisos_enfermedad,
    
    -- Resumen de Justificaciones
    (SELECT COUNT(*) FROM TBL_JUSTIFICACIONES WHERE EMP_ID = n.NOMINA_ID) AS total_justificaciones,
    
    -- Último Marcado Entrada/Salida
    (SELECT TOP 1 Hora_Ingreso FROM TBL_ASISTENCIA 
     WHERE EMP_ID = n.NOMINA_ID ORDER BY Fecha_Ingreso DESC) AS ultima_entrada,
    (SELECT TOP 1 Hora_Salida FROM TBL_ASISTENCIA 
     WHERE EMP_ID = n.NOMINA_ID ORDER BY Fecha_Ingreso DESC) AS ultima_salida,
    (SELECT TOP 1 Fecha_Ingreso FROM TBL_ASISTENCIA 
     WHERE EMP_ID = n.NOMINA_ID ORDER BY Fecha_Ingreso DESC) AS fecha_ultima_asistencia
    
FROM ONLYCONTROL.dbo.NOMINA n
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.DPTO d ON n.NOMINA_DEP = d.DEP_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
LEFT JOIN ONLYCONTROL.dbo.EXTERNOE e ON n.NOMINA_EMP = e.EMPE_ID
LEFT JOIN ONLYCONTROL.dbo.NOMINA_DATOS_ADICIONAL nd ON n.NOMINA_ID = nd.NOMINA_ID
WHERE n.NOMINA_ID = '000001';  -- <-- Cambiar este ID de empleado


-- ============================================================================
-- CONSULTA 21: DASHBOARD COMPARATIVO POR ÁREA
-- Propósito: Comparar rendimiento entre departamentos/áreas
-- ============================================================================
SELECT 
    ar.AREA_NOM AS area_nombre,
    COUNT(DISTINCT n.NOMINA_ID) AS total_empleados,
    COUNT(DISTINCT CASE WHEN n.NOMINA_FSAL IS NULL THEN n.NOMINA_ID END) AS empleados_activos,
    COUNT(DISTINCT CASE WHEN n.NOMINA_FSAL IS NOT NULL THEN n.NOMINA_ID END) AS empleados_retirados,
    
    -- Métricas de asistencia (últimos 30 días)
    COUNT(DISTINCT a.EMP_ID) AS empleados_con_asistencia,
    CAST(SUM(CAST(a.Horas_Laboradas AS FLOAT)) AS DECIMAL(10,2)) AS total_horas_laboradas,
    CAST(AVG(CAST(a.Horas_Laboradas AS FLOAT)) AS DECIMAL(10,2)) AS promedio_horas_por_empleado,
    SUM(CAST(a.Atrasos AS INT)) AS total_minutos_atraso,
    CAST(AVG(CAST(a.Atrasos AS FLOAT)) AS DECIMAL(10,2)) AS promedio_minutos_atraso,
    
    -- Métricas de horas extras
    SUM(ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) + 
        ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
        ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) AS total_minutos_horas_extra,
    CAST(SUM(ISNULL(a.min_25, 0) + ISNULL(a.min_50, 0) + ISNULL(a.min_75, 0) + 
        ISNULL(a.min_100, 0) + ISNULL(a.min_125, 0) + ISNULL(a.min_150, 0) + 
        ISNULL(a.min_175, 0) + ISNULL(a.min_200, 0)) / 60.0 AS DECIMAL(10,2)) AS total_horas_extra,
    
    -- Métricas de ausencias
    COUNT(DISTINCT CASE WHEN a.Ausente = 1 THEN a.EMP_ID END) AS cantidad_ausencias,
    COUNT(DISTINCT pa.E_EMPID) AS solicitudes_permiso,
    
    -- Métricas de justificaciones
    COUNT(DISTINCT j.EMP_ID) AS empleados_con_justificaciones,
    COUNT(j.ID) AS total_justificaciones

FROM ONLYCONTROL.dbo.AREA ar
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON ar.AREA_ID = n.NOMINA_AREA
LEFT JOIN TBL_ASISTENCIA a ON n.NOMINA_ID = a.EMP_ID 
    AND a.Fecha_Ingreso >= DATEADD(DAY, -30, GETDATE())
LEFT JOIN TBL_PERM_AUS pa ON n.NOMINA_ID = pa.E_EMPID
LEFT JOIN TBL_JUSTIFICACIONES j ON n.NOMINA_ID = j.EMP_ID
GROUP BY ar.AREA_NOM
ORDER BY total_horas_laboradas DESC;


-- ============================================================================
-- CONSULTA 22: REPORTE DIARIO DE EXCEPCIONES DE ASISTENCIA (CON NO CUMPLIMIENTO)
-- Propósito: Reporte diario de anomalías para revisión de RRHH
-- Incluye: No cumple horario, horas de salida anticipada, minutos faltantes
-- ============================================================================
SELECT
    a.EMP_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    c.CALI_NOM AS cargo_nombre,
    a.Fecha_Ingreso AS fecha,
    a.Hora_Ingreso AS hora_entrada,
    h.H_HRA_ING AS hora_entrada_programada,
    a.Hora_Salida AS hora_salida,
    h.H_HRA_SAL AS hora_salida_programada,
    a.Atrasos AS minutos_atraso,
    a.Horas_Laboradas AS horas_laboradas,
    h.H_HORAS AS horas_esperadas,

    -- Flags de excepciones (actualizado con No Cumple)
    CASE
        WHEN vm.Estado_Cumplimiento = 'No Cumple Horario' THEN 'NO CUMPLE - SALIDA ANTICIPADA'
        WHEN a.Ausente = 1 THEN 'AUSENTE'
        WHEN a.Atraso = 1 AND a.Atrasos > 20 THEN 'ATRASO SIGNIFICATIVO'
        WHEN a.Hora_Cerrada = 1 THEN 'HORA CERRADA'
        WHEN a.Hora_Ingreso IS NULL THEN 'SIN MARCACIÓN ENTRADA'
        WHEN a.Hora_Salida IS NULL THEN 'SIN MARCACIÓN SALIDA'
        WHEN CAST(a.Horas_Laboradas AS FLOAT) < (h.H_HORAS * 0.8) THEN 'HORAS INSUFICIENTES'
        ELSE 'NORMAL'
    END AS tipo_excepcion,

    -- NUEVO: Estado de cumplimiento
    vm.Estado_Cumplimiento AS estado_cumplimiento,
    
    -- NUEVO: Horas de no cumplimiento
    CAST(ISNULL(vm.Horas_No_Cumple_Horario, 0) AS DECIMAL(10,2)) AS horas_no_cumple,
    
    -- NUEVO: Minutos faltantes
    ISNULL(vm.Minutos_Tiempo_Faltante, 0) AS minutos_faltantes,

    -- Problemas detallados
    CASE WHEN a.Ausente = 1 THEN 'Empleado marcado como ausente' END AS problema_ausente,
    CASE WHEN a.Atraso = 1 THEN 'Empleado llegó ' + CAST(a.Atrasos AS VARCHAR) + ' minutos tarde' END AS problema_atraso,
    CASE WHEN a.Hora_Ingreso IS NULL THEN 'Sin registro de entrada' END AS problema_sin_entrada,
    CASE WHEN a.Hora_Salida IS NULL THEN 'Sin registro de salida' END AS problema_sin_salida,
    CASE WHEN vm.Estado_Cumplimiento = 'No Cumple Horario' 
         THEN 'Empleado salió ' + CAST(CAST(vm.Horas_No_Cumple_Horario AS DECIMAL(10,2)) AS VARCHAR) + ' horas antes' 
    END AS problema_no_cumple,

    a.Observacion AS observaciones,
    j.OBSERVACION AS justificacion

FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
LEFT JOIN TBL_T_HORARIOS th ON a.EMP_ID = th.H_EMPID AND a.Fecha_Ingreso = th.H_FECHA
LEFT JOIN TBL_MODALIDAD m ON th.H_IDMOD = m.M_ID
LEFT JOIN TBL_HORARIO h ON m.M_1 = h.H_ID
LEFT JOIN TBL_JUSTIFICACIONES j ON a.EMP_ID = j.EMP_ID AND a.Fecha_Ingreso = j.FECHA
LEFT JOIN dbo.vm_atrasos vm ON a.EMP_ID = vm.Codigo AND a.Fecha_Ingreso = vm.Fecha_Inicio
WHERE a.Fecha_Ingreso >= DATEADD(DAY, -7, GETDATE())
  AND (a.Ausente = 1 OR a.Atraso = 1 OR a.Hora_Ingreso IS NULL
       OR a.Hora_Salida IS NULL OR a.Hora_Cerrada = 1
       OR vm.Estado_Cumplimiento = 'No Cumple Horario')
ORDER BY a.Fecha_Ingreso DESC, 
         CASE WHEN vm.Estado_Cumplimiento = 'No Cumple Horario' THEN 0 ELSE 1 END,
         a.Atrasos DESC;


-- ============================================================================
-- CONSULTA 23: CÁLCULO DE SALDO DE VACACIONES
-- Propósito: Calcular días de vacaciones usados vs disponibles
-- ============================================================================
SELECT 
    n.NOMINA_ID AS empleado_id,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS nombre_completo,
    ar.AREA_NOM AS area_nombre,
    n.NOMINA_FING AS fecha_ingreso,
    DATEDIFF(YEAR, n.NOMINA_FING, GETDATE()) AS anos_servicio,
    
    -- Días de vacaciones usados (año actual)
    COUNT(CASE WHEN pa.E_NOM = 'VC' AND YEAR(pa.E_FECHA_I) = YEAR(GETDATE()) 
               THEN 1 END) AS dias_vacacion_usados_anio,
    
    -- Total de días de vacaciones usados (todo el tiempo)
    COUNT(CASE WHEN pa.E_NOM = 'VC' THEN 1 END) AS total_dias_vacacion,
    
    -- Pagadas vs no pagadas
    SUM(CASE WHEN pa.E_NOM = 'VC' AND pa.D_PAG = 1 THEN 1 ELSE 0 END) AS dias_vacacion_pagados,
    SUM(CASE WHEN pa.E_NOM = 'VC' AND pa.D_PAG = 0 THEN 1 ELSE 0 END) AS dias_vacacion_no_pagados,
    
    -- Desglose de permisos del año actual
    COUNT(CASE WHEN pa.E_NOM = 'SP' AND YEAR(pa.E_FECHA_I) = YEAR(GETDATE()) 
               THEN 1 END) AS dias_enfermedad_usados,
    COUNT(CASE WHEN pa.E_NOM = 'LE' AND YEAR(pa.E_FECHA_I) = YEAR(GETDATE()) 
               THEN 1 END) AS dias_permiso_personal,
    
    -- Saldo estimado de vacaciones (asumiendo 15 días por año para demostración)
    15 * DATEDIFF(YEAR, n.NOMINA_FING, GETDATE()) AS total_dias_vacacion_estimados,
    (15 * DATEDIFF(YEAR, n.NOMINA_FING, GETDATE())) - 
        COUNT(CASE WHEN pa.E_NOM = 'VC' THEN 1 END) AS saldo_vacaciones_estimado

FROM ONLYCONTROL.dbo.NOMINA n
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN TBL_PERM_AUS pa ON n.NOMINA_ID = pa.E_EMPID
WHERE n.NOMINA_FSAL IS NULL  -- Solo empleados activos
GROUP BY n.NOMINA_ID, n.NOMINA_NOM, n.NOMINA_APE, ar.AREA_NOM, n.NOMINA_FING
ORDER BY saldo_vacaciones_estimado DESC;


-- ============================================================================
-- CONSULTA 24: ANÁLISIS DE COBERTURA DE TURNOS
-- Propósito: Analizar qué turnos tienen cobertura y cuáles no
-- ============================================================================
SELECT 
    m.M_NOM AS modalidad_nombre,
    m.M_ID AS modalidad_id,
    m.M_CANT_SEMANA AS dias_ciclo,
    COUNT(DISTINCT th.H_EMPID) AS empleados_asignados,
    COUNT(DISTINCT th.H_FECHA) AS fechas_programadas,
    
    h1.H_NOM AS horario_lunes,
    h1.H_HRA_ING AS entrada_lunes,
    h1.H_HRA_SAL AS salida_lunes,
    
    h2.H_NOM AS horario_martes,
    h2.H_HRA_ING AS entrada_martes,
    h2.H_HRA_SAL AS salida_martes,
    
    h3.H_NOM AS horario_miercoles,
    h3.H_HRA_ING AS entrada_miercoles,
    h3.H_HRA_SAL AS salida_miercoles,
    
    h4.H_NOM AS horario_jueves,
    h4.H_HRA_ING AS entrada_jueves,
    h4.H_HRA_SAL AS salida_jueves,
    
    h5.H_NOM AS horario_viernes,
    h5.H_HRA_ING AS entrada_viernes,
    h5.H_HRA_SAL AS salida_viernes,
    
    h6.H_NOM AS horario_sabado,
    h6.H_HRA_ING AS entrada_sabado,
    h6.H_HRA_SAL AS salida_sabado,
    
    h7.H_NOM AS horario_domingo,
    h7.H_HRA_ING AS entrada_domingo,
    h7.H_HRA_SAL AS salida_domingo,
    
    -- Días libres
    CASE WHEN m.M_LIBRE = 1 THEN 'Tiene Día Libre' ELSE 'Sin Día Libre' END AS flag_dia_libre

FROM TBL_MODALIDAD m
LEFT JOIN TBL_T_HORARIOS th ON m.M_ID = th.H_IDMOD
LEFT JOIN TBL_HORARIO h1 ON m.M_1 = h1.H_ID
LEFT JOIN TBL_HORARIO h2 ON m.M_2 = h2.H_ID
LEFT JOIN TBL_HORARIO h3 ON m.M_3 = h3.H_ID
LEFT JOIN TBL_HORARIO h4 ON m.M_4 = h4.H_ID
LEFT JOIN TBL_HORARIO h5 ON m.M_5 = h5.H_ID
LEFT JOIN TBL_HORARIO h6 ON m.M_6 = h6.H_ID
LEFT JOIN TBL_HORARIO h7 ON m.M_7 = h7.H_ID
GROUP BY m.M_ID, m.M_NOM, m.M_CANT_SEMANA, m.M_LIBRE,
         h1.H_NOM, h1.H_HRA_ING, h1.H_HRA_SAL,
         h2.H_NOM, h2.H_HRA_ING, h2.H_HRA_SAL,
         h3.H_NOM, h3.H_HRA_ING, h3.H_HRA_SAL,
         h4.H_NOM, h4.H_HRA_ING, h4.H_HRA_SAL,
         h5.H_NOM, h5.H_HRA_ING, h5.H_HRA_SAL,
         h6.H_NOM, h6.H_HRA_ING, h6.H_HRA_SAL,
         h7.H_NOM, h7.H_HRA_ING, h7.H_HRA_SAL
ORDER BY empleados_asignados DESC;


-- ============================================================================
-- CONSULTA 25: DASHBOARD RESUMEN EJECUTIVO
-- Propósito: KPIs de alto nivel para dashboard ejecutivo
-- ============================================================================
SELECT 
    -- Período
    CAST(GETDATE() AS DATE) AS fecha_reporte,
    DATENAME(WEEKDAY, GETDATE()) AS dia_semana,
    
    -- Conteos de empleados
    (SELECT COUNT(*) FROM ONLYCONTROL.dbo.NOMINA WHERE NOMINA_FSAL IS NULL) AS empleados_activos,
    (SELECT COUNT(*) FROM ONLYCONTROL.dbo.NOMINA WHERE NOMINA_FSAL IS NOT NULL) AS empleados_retirados,
    (SELECT COUNT(*) FROM ONLYCONTROL.dbo.NOMINA) AS total_empleados,
    
    -- Asistencia de hoy
    (SELECT COUNT(DISTINCT EMP_ID) FROM TBL_ASISTENCIA 
     WHERE Fecha_Ingreso = CAST(GETDATE() AS DATE)) AS empleados_marcados_hoy,
    (SELECT COUNT(DISTINCT EMP_ID) FROM TBL_ASISTENCIA 
     WHERE Fecha_Ingreso = CAST(GETDATE() AS DATE) AND Ausente = 1) AS ausentes_hoy,
    (SELECT COUNT(DISTINCT EMP_ID) FROM TBL_ASISTENCIA 
     WHERE Fecha_Ingreso = CAST(GETDATE() AS DATE) AND Atraso = 1) AS atrasos_hoy,
    
    -- Estadísticas del mes
    (SELECT AVG(CAST(Horas_Laboradas AS FLOAT)) FROM TBL_ASISTENCIA 
     WHERE MONTH(Fecha_Ingreso) = MONTH(GETDATE()) AND YEAR(Fecha_Ingreso) = YEAR(GETDATE())) AS promedio_horas_mes,
    (SELECT SUM(ISNULL(min_25, 0) + ISNULL(min_50, 0) + ISNULL(min_75, 0) + 
                ISNULL(min_100, 0) + ISNULL(min_125, 0) + ISNULL(min_150, 0) + 
                ISNULL(min_175, 0) + ISNULL(min_200, 0)) 
     FROM TBL_ASISTENCIA 
     WHERE MONTH(Fecha_Ingreso) = MONTH(GETDATE()) AND YEAR(Fecha_Ingreso) = YEAR(GETDATE())) AS minutos_horas_extra_mes,
    
    -- Permisos actuales
    (SELECT COUNT(*) FROM TBL_PERM_AUS 
     WHERE GETDATE() BETWEEN E_FECHA_I AND E_FECHA_F) AS actualmente_en_permiso,
    
    -- Justificaciones pendientes
    (SELECT COUNT(*) FROM TBL_JUSTIFICACIONES WHERE ENVIO IS NULL) AS justificaciones_pendientes,
    
    -- Dispositivos biométricos activos
    (SELECT COUNT(*) FROM TBL_ASISTENCIA_EQUIPOS WHERE EQ_ESTADO = 1) AS dispositivos_activos,
    
    -- Total registros de asistencia (todo el tiempo)
    (SELECT COUNT(*) FROM TBL_ASISTENCIA) AS total_registros_asistencia,
    
    -- Períodos de nómina pendientes
    (SELECT COUNT(*) FROM TBL_PERIODO WHERE ESTADO = 'P') AS periodos_nomina_pendientes;


-- ============================================================================
-- CONSULTA 26: TOP EMPLEADOS QUE NO CUMPLEN HORARIO (SALIDA ANTICIPADA)
-- Propósito: Identificar empleados con mayor cantidad de salidas anticipadas
-- Fuente: Vista vm_atrasos (Estado_Cumplimiento = 'No Cumple Horario')
-- Incluye: Tipo_Registro y Nombre_Registro para clasificación por filas
-- ============================================================================
SELECT TOP 30
    vm.Codigo AS empleado_id,
    vm.Cedula,
    vm.Nombre_Completo AS nombre,
    vm.Sucursal AS empresa,
    vm.Area AS area,
    vm.Departamento AS departamento,
    vm.Cargo AS cargo,
    vm.Ciudad_Sede AS ciudad,
    vm.Descripcion_Jornada AS tipo_jornada,
    
    -- NUEVO: Tipo y nombre de registro (para agrupación por filas)
    vm.Tipo_Registro AS tipo_registro,
    vm.Nombre_Registro AS nombre_registro,

    COUNT(*) AS total_no_cumple,
    CAST(SUM(vm.Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS total_horas_no_cumple,
    CAST(AVG(vm.Horas_No_Cumple_Horario) AS DECIMAL(10,2)) AS promedio_horas_no_cumple,
    SUM(vm.Minutos_Tiempo_Faltante) AS total_minutos_faltantes,

    MIN(vm.Fecha_Inicio) AS primera_vez,
    MAX(vm.Fecha_Inicio) AS ultima_vez,
    DATEDIFF(DAY, MIN(vm.Fecha_Inicio), MAX(vm.Fecha_Inicio)) AS dias_span,

    -- Distribución por día de semana
    SUM(CASE WHEN DATEPART(WEEKDAY, vm.Fecha_Inicio) = 2 THEN 1 ELSE 0 END) AS no_cumple_lunes,
    SUM(CASE WHEN DATEPART(WEEKDAY, vm.Fecha_Inicio) = 3 THEN 1 ELSE 0 END) AS no_cumple_martes,
    SUM(CASE WHEN DATEPART(WEEKDAY, vm.Fecha_Inicio) = 4 THEN 1 ELSE 0 END) AS no_cumple_miercoles,
    SUM(CASE WHEN DATEPART(WEEKDAY, vm.Fecha_Inicio) = 5 THEN 1 ELSE 0 END) AS no_cumple_jueves,
    SUM(CASE WHEN DATEPART(WEEKDAY, vm.Fecha_Inicio) = 6 THEN 1 ELSE 0 END) AS no_cumple_viernes,
    SUM(CASE WHEN DATEPART(WEEKDAY, vm.Fecha_Inicio) IN (7, 1) THEN 1 ELSE 0 END) AS no_cumple_fds,

    -- Frecuencia
    CASE
        WHEN COUNT(*) >= 10 THEN 'CRÍTICO - Reincidente'
        WHEN COUNT(*) >= 5 THEN 'ALTO - Accion requerida'
        WHEN COUNT(*) >= 3 THEN 'MODERADO - Seguimiento'
        ELSE 'BAJO - Observar'
    END AS nivel_frecuencia

FROM dbo.vm_atrasos vm
WHERE vm.Estado_Cumplimiento = 'No Cumple Horario'
  AND vm.Fecha_Inicio >= DATEADD(MONTH, -3, GETDATE())
GROUP BY vm.Codigo, vm.Cedula, vm.Nombre_Completo, vm.Sucursal, vm.Area,
         vm.Departamento, vm.Cargo, vm.Ciudad_Sede, vm.Descripcion_Jornada,
         vm.Tipo_Registro, vm.Nombre_Registro
HAVING COUNT(*) >= 2
ORDER BY total_horas_no_cumple DESC, total_no_cumple DESC;


-- ============================================================================
-- NOTAS PARA IMPLEMENTACIÓN EN POWER BI:
-- ============================================================================
-- 1. Usar Linked Server o consultas cruzadas si TCONTROL y ONLYCONTROL
--    están en la misma instancia de servidor
-- 2. Si son conexiones separadas, crear Power Query en Power BI:
--    - Importar ONLYCONTROL.dbo.NOMINA como tabla dimensional
--    - Importar TCONTROL.TBL_ASISTENCIA como tabla de hechos
--    - Crear relaciones en EMP_ID = NOMINA_ID
--    - Importar dbo.vm_atrasos para métricas de no cumplimiento
-- 3. Páginas recomendadas para Dashboard:
--    - Resumen Ejecutivo (Consulta 25)
--    - Vista General de Asistencia (Consultas 2, 11, 12)
--    - Análisis de Horas Extras (Consulta 4, 14)
--    - Ausencias y Permisos (Consultas 5, 23)
--    - Comparación por Departamentos (Consulta 21)
--    - Directorio de Empleados (Consulta 1)
--    - Monitoreo en Tiempo Real (Consulta 8)
--    - Reporte de Excepciones (Consulta 22)
--    - Estado de Dispositivos (Consulta 16)
--    - Vista 360 del Empleado (Consulta 20)
--    - No Cumple Horario (Consulta 26)
-- 4. Crear columnas calculadas en Power BI:
--    - Tasa de Asistencia = (Días Presentes / Días Totales) * 100
--    - Horas Extras = Total Minutos Horas Extra / 60
--    - Puntualidad = (Días Puntuales / Días Totales) * 100
--    - Tasa de No Cumplimiento = Casos No Cumple / Empleados Activos * 100
-- 5. Crear medidas para:
--    - Promedio de Horas por Empleado
--    - Costo Total de Horas Extras
--    - Tasa de Ausentismo
--    - Tasa de Rotación
--    - Horas No Cumplidas (Suma de Horas_No_Cumple_Horario)
--    - % Empleados No Cumplen (Empleados No Cumple / Total Empleados * 100)
-- ============================================================================
