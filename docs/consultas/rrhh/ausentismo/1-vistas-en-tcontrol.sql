/* ============================================================================
   AUSENTISMO · PARTE 1 de 2   ·   VISTAS EN EL ORIGEN
   Servidor: SRV-BIOM-001\SQLEXPRESS2008R2      Base: TCONTROL
   ----------------------------------------------------------------------------
   Aqui vive la LOGICA DE NEGOCIO: catalogo, jornadas, novedades y timbradas.
   Cada vista se resuelve en este servidor y por el linked server solo viaja
   el resultado, no las tablas.

   El CRUCE entre novedades y timbradas NO esta aqui: vive en TH, porque a
   grano de dia son 747.632 filas y este servidor, que es Express con tope de
   1 GB, no las cruza sin expirar. Ver la seccion 0 y el script de la parte 2.

   POR QUE ESTE CAMBIO
   -------------------
   Con nombres de cuatro partes ([ONLYC].TCONTROL.DBO.TBL_ASISTENCIA) el
   optimizador de TH suele traer las tablas completas y unirlas del lado de TH.
   Medido: un GROUP BY sobre el fact tardaba 28-37 s y a veces expiraba,
   mientras las mismas consultas ejecutadas aqui tardan 40-500 ms.
   Con la vista definida en TCONTROL, el join lo resuelve este servidor.

   RESTRICCIONES DEL ENTORNO  (verificadas en vivo)
   -----------------------------------------------
   · SQL Server 2008 R2 SP2, Express Edition.
   · TCONTROL y ONLYCONTROL estan en compatibility_level 80.
   · SI funcionan: CTE, CROSS APPLY, VALUES como tabla, funciones de ventana
     (ROW_NUMBER, SUM OVER PARTITION BY). Probado contra estas mismas tablas.
   · NO existen: DATEFROMPARTS, CREATE OR ALTER, CONCAT, IIF, TRY_CONVERT.
     Por eso el periodo de nomina se arma con DATEADD/DATEDIFF y cada vista
     se recrea con DROP + CREATE.

   LA REGLA DE AUSENTISMO SALE DEL CATALOGO, NO DE UNA LISTA QUEMADA
   -----------------------------------------------------------------
   Criterio de Talento Humano: si la novedad es PAGADA, la empresa la cubre y
   cuenta como justificada. Si NO es pagada, es ausentismo.
   Eso es el check PAGADO de la pantalla Catalogo de Novedades (CD_PAGADO), asi
   que TH lo cambia ahi y las vistas se enteran solas. Se expone como
   Es_Ausentismo y Clasificacion en vw_th_novedades.

   Del lado de las marcaciones el catalogo no usa PAGADO: los codigos de las
   categorias 2, 6, 9 y 11 tienen todos CD_PAGADO = 0. El equivalente ahi es la
   categoria: 9 y 11 son JUSTIFICACIONES (AJ atraso justificado, FJ falta
   justificada, SJ salida justificada, MM marcacion manual). Se expone como
   Es_Justificado y Es_Ausentismo en vw_th_timbradas.

   OJO CON LO QUE ESTO SIGNIFICA
   -----------------------------
   Este criterio produce un indicador DISTINTO al del Excel historico.
   Medido sobre 21-jul a 20-ago 2025, Quito:
       No pagado (ausentismo) : SP PERMISO SIN PAGA          119,62 h
       Pagado (justificado)   : VC 5.512,88 · LM 2.016,00 · LE 810,00
                                CD 148,50 · PE 48,63 · CS 46,58
   El Excel daba 2.658,64 h para ese mismo periodo, porque sumaba LM, LE, CD y
   PE, que son pagadas. Los dos criterios son validos pero miden cosas
   distintas: uno es "ausentismo no cubierto por la empresa" y el otro es
   "horas-hombre perdidas". Las vistas traen las dos: agrupando por
   Es_Ausentismo sale el primero, ignorando la bandera sale el segundo.

   NO SE CREA NINGUNA TABLA
   ------------------------
   Todo sale de lo que TimeControl ya administra:
       TBL_CAT_MAESTRO / TBL_CAT_DETALLE  -> Catalogo de Novedades
       TBL_MODALIDAD  / TBL_HORARIO       -> Modalidades y Definicion de Horarios
       TBL_TIPO_HORA                      -> Tipos de Horas
       TBL_FESTIVOS                       -> Dias Festivos
       TBL_PERM_AUS  / TBL_ASISTENCIA     -> Novedades y marcaciones
       ONLYCONTROL.dbo.NOMINA / AREA / DPTO / EXTERNOE

   PERMISOS
   --------
   El usuario ocaccess puede no tener CREATE VIEW en TCONTROL. Si el script
   falla al crear, debe ejecutarlo el administrador de OnlyControl o un login
   con db_ddladmin sobre TCONTROL, y luego basta con:

       GRANT SELECT ON dbo.vw_th_novedades TO ocaccess;
       GRANT SELECT ON dbo.vw_th_timbradas TO ocaccess;
       GRANT SELECT ON dbo.vw_th_jornada_modalidad TO ocaccess;
       GRANT SELECT ON dbo.vw_th_catalogo_novedad  TO ocaccess;
       GRANT SELECT ON dbo.vw_th_empleado          TO ocaccess;
   ============================================================================ */

USE TCONTROL;

/* ===========================================================================
   0 · LIMPIEZA
   ---------------------------------------------------------------------------
   vw_th_ausentismo estuvo aqui y se saco. Cruzar novedades con timbradas a
   grano de dia es un FULL OUTER JOIN sobre 747.632 filas, y este servidor no
   lo aguanta: expira. Medido, no supuesto. Es Express con tope de 1 GB.
   Lo que este servidor SI hace rapido es entregar cada vista por separado:
       vw_th_novedades    23.525 filas en 0,25 s
       vw_th_timbradas   734.234 filas en 9,0  s
   Por eso el cruce se mudo a TH, contra tablas locales con indices.
   Ver ausentismo_2_consumo_en_th.sql.
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_ausentismo', 'V') IS NOT NULL DROP VIEW dbo.vw_th_ausentismo;


/* ===========================================================================
   1 · EMPLEADOS SIN EL FILTRO QUE BORRA EL HISTORIAL
   ---------------------------------------------------------------------------
   ViewEmpleados, la vista que ya existe, trae WHERE NOMINA_ES <> 0. Eso aplica
   el estado de HOY a datos historicos: cuando alguien sale de la empresa sus
   permisos y faltas de anios anteriores desaparecen del reporte.
   Medido: 909 empleados en NOMINA_ES = 0, y con ellos 411 permisos de 2025
   (16 %) de 63 personas. Por eso el 2025 que se corre hoy no es el mismo 2025
   que se corrio en 2025, y nunca cuadra con un Excel congelado.

   Esta vista trae la nomina COMPLETA y deja el estado como atributo.
   No reemplaza a ViewEmpleados: convive con ella.
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_empleado', 'V') IS NOT NULL DROP VIEW dbo.vw_th_empleado;
CREATE VIEW dbo.vw_th_empleado AS
SELECT
    N.NOMINA_ID, N.NOMINA_COD, N.NOMINA_APE, N.NOMINA_NOM,
    X.EMPE_NOM, A.AREA_NOM, D.DEP_NOM, N.NOMINA_CAL1, N.NOMINA_EMP,
    N.NOMINA_ES,
    CAST(CASE WHEN N.NOMINA_ES <> 0 THEN 1 ELSE 0 END AS BIT) AS Activo_Hoy,
    CAST(CASE WHEN X.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
              WHEN X.EMPE_NOM LIKE '%EMPAQPLAST%'  THEN 'UIO'
              ELSE 'OTRA' END AS VARCHAR(10)) AS Ciudad_Sede
FROM ONLYCONTROL.dbo.NOMINA   N
JOIN ONLYCONTROL.dbo.EXTERNOE X ON N.NOMINA_EMP  = X.EMPE_ID
JOIN ONLYCONTROL.dbo.AREA     A ON N.NOMINA_AREA = A.AREA_ID
JOIN ONLYCONTROL.dbo.DPTO     D ON N.NOMINA_DEP  = D.DEP_ID;


/* ===========================================================================
   2 · CATALOGO DE NOVEDADES  (Especificaciones Generales > Catalogo)
   ---------------------------------------------------------------------------
   CD_ID es varchar(2) y ES el codigo. CD_PAGADO y CD_FLAG son los checks
   PAGADO y ACTIVO de la pantalla. La clave es COMPUESTA (CD_CAT, CD_ID):
   el codigo PE existe tres veces (PERMISO SALIDA cat 2, PERMISO ENTRADA
   cat 6, CITA MEDICA cat 13).
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_catalogo_novedad', 'V') IS NOT NULL DROP VIEW dbo.vw_th_catalogo_novedad;
CREATE VIEW dbo.vw_th_catalogo_novedad AS
SELECT
    CAST(M.C_ID   AS INT)          AS Categoria_Id,
    CAST(M.C_NOM  AS VARCHAR(30))  AS Categoria,
    CAST(D.CD_ID  AS VARCHAR(2))   AS Codigo,
    CAST(D.CD_NOM AS VARCHAR(30))  AS Novedad,
    CAST(CASE WHEN ISNULL(D.CD_PAGADO,0) <> 0 THEN 1 ELSE 0 END AS BIT) AS Es_Pagado,
    CAST(CASE WHEN ISNULL(D.CD_FLAG  ,0) <> 0 THEN 1 ELSE 0 END AS BIT) AS Activo,
    CAST(CASE M.C_ID WHEN  2 THEN 'Salida'
                     WHEN  6 THEN 'Entrada'
                     WHEN  9 THEN 'Justificacion entrada'
                     WHEN 11 THEN 'Justificacion salida'
                     WHEN 13 THEN 'Permiso'
                     ELSE 'Otro' END AS VARCHAR(25)) AS Ambito,
    /* Una justificacion no es incumplimiento: el supervisor ya la aprobo. */
    CAST(CASE WHEN M.C_ID IN (9,11) THEN 1 ELSE 0 END AS BIT) AS Es_Justificacion
FROM dbo.TBL_CAT_MAESTRO M
JOIN dbo.TBL_CAT_DETALLE D ON D.CD_CAT = M.C_ID;


/* ===========================================================================
   3 · JORNADA POR MODALIDAD Y DIA  (Modalidades + Definicion de Horarios)
   ---------------------------------------------------------------------------
   TBL_MODALIDAD guarda por cada dia el flag M_x y el horario M_xH.
   Mapeo real, confirmado por tres vias independientes:
       M_1=Domingo  M_2=Lunes  M_3=Martes  M_4=Miercoles
       M_5=Jueves   M_6=Viernes  M_7=Sabado
     a) VENDEDORES-LUNES solo tiene M_2 y marca solo lunes (64 de 64).
     b) ADMINISTRATIVA HE apunta en M_7H al horario "ADMINISTRA SYD 8-16",
        donde SYD = Sabado Y Domingo.
     c) La pantalla de Modalidades lista los dias en el orden
        Domingo, Lunes, Martes, Miercoles, Jueves, Viernes, Sabado.

   Duracion: (H_HSAL1 - H_HENT, +24 h si cruza) menos el almuerzo, y el
   almuerzo SOLO se descuenta si H_BREAK = 1 (check "Realiza Control").
   PROD. 18-06 LAV tiene H_TIEMPO = 30 pero H_BREAK = 0, y el sistema reporta
   Horas_Laboradas = 721 min (12,02 h): no descuenta.

   DiaIdx = DATEDIFF(DAY,'19000101',fecha) % 7, independiente del idioma
   del servidor:  0=Lun 1=Mar 2=Mie 3=Jue 4=Vie 5=Sab 6=Dom
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_jornada_modalidad', 'V') IS NOT NULL DROP VIEW dbo.vw_th_jornada_modalidad;
CREATE VIEW dbo.vw_th_jornada_modalidad AS
SELECT
    CAST(M.M_ID  AS INT)            AS Modalidad_Id,
    CAST(M.M_DES AS VARCHAR(255))   AS Modalidad,
    CAST(D.DiaIdx AS TINYINT)       AS DiaIdx,
    CAST(D.DiaNombre AS VARCHAR(10)) AS Dia,
    CAST(ISNULL(D.Trabaja,0) AS BIT) AS Trabaja_Dia,
    CAST(H.H_ID  AS INT)            AS Horario_Id,
    CAST(H.H_NOM AS VARCHAR(120))   AS Horario,
    CONVERT(VARCHAR(5), H.H_HENT , 108) AS Hora_Entrada,
    CONVERT(VARCHAR(5), H.H_HSAL1, 108) AS Hora_Salida,

    /* Gracia real de ESTE horario: 15 min en 55, 0 en 12, 180 en 3, 640 en 4. */
    CAST(ISNULL(H.H_GENT ,0) AS INT) AS Gracia_Entrada_Min,
    CAST(ISNULL(H.H_GSAL1,0) AS INT) AS Gracia_Salida_Min,

    CAST(ISNULL(H.H_BREAK,0) AS BIT) AS Controla_Lunch,
    CAST(CASE WHEN ISNULL(H.H_BREAK,0) = 0 THEN 'No descuenta'
              WHEN H.H_BREM = 1 THEN 'Por marcacion'
              WHEN H.H_BREM = 2 THEN 'Tiempo fijo'
              WHEN H.H_BREM = 3 THEN 'Por excedente al tiempo fijo'
              ELSE 'No descuenta' END AS VARCHAR(30)) AS Modo_Lunch,
    CAST(CASE WHEN ISNULL(H.H_BREAK,0) = 1 THEN ISNULL(H.H_TIEMPO,0) ELSE 0 END AS INT)
                                     AS Lunch_Minutos,

    CAST(J.HorasNetas AS DECIMAL(6,2)) AS Horas_Jornada,
    /* Jornada ORDINARIA: el tramo que TBL_TIPO_HORA marca al 100 %.
       Un turno de 12 h suele ser 8 h ordinarias + 4 h con recargo. */
    CAST(O.HorasOrdinarias AS DECIMAL(6,2)) AS Horas_Ordinarias,
    CAST(CASE
        WHEN J.HorasNetas IS NULL                        THEN 'Sin horario'
        WHEN J.HorasNetas >= 7.5 AND J.HorasNetas <  9.5 THEN '8 horas'
        WHEN J.HorasNetas >= 11  AND J.HorasNetas <= 13  THEN '12 horas'
        WHEN J.HorasNetas <  7.5                         THEN 'Parcial'
        ELSE 'Revisar'
    END AS VARCHAR(20))              AS Tipo_Jornada,

    /* Fin de semana con horario EXCLUSIVO de fin de semana.
       ---------------------------------------------------------------------
       ADMINISTRATIVA HE usa ADMINISTRATIVO HE de lunes a viernes y
       ADMINISTRA SYD 8-16 los sabados y domingos. Ese horario SYD no aparece
       ningun dia de semana: existe para habilitar horas extras de fin de
       semana, no para obligar a trabajarlas. "HE" es horas extras
       autorizadas, no jornada.
       Cuando el horario del fin de semana SI se usa entre semana (produccion
       con PROD. 06-18 LAV los siete dias, o un rotativo), el fin de semana es
       jornada de verdad y la bandera queda en 0.
       Esta regla redescubre sola las mismas modalidades que la vista original
       excluia con LIKE por nombre (ADMINISTRATIVO HE y PLANTA 06 A 18:), pero
       sale del dato: si manana renombran la modalidad, sigue funcionando. */
    CAST(CASE WHEN D.DiaIdx IN (5,6) AND ISNULL(D.Trabaja,0) = 1
                   AND NOT EXISTS (
                       SELECT 1
                       FROM (VALUES (M.M_2,M.M_2h),(M.M_3,M.M_3h),(M.M_4,M.M_4H),
                                    (M.M_5,M.M_5H),(M.M_6,M.M_6H)) AS W(Trab, HId)
                       WHERE ISNULL(W.Trab,0) = 1 AND W.HId = D.H_ID )
              THEN 1 ELSE 0 END AS BIT)          AS Horario_Solo_Finde,

    CAST(ISNULL(M.M_FESTIVO,0) AS BIT) AS Trabaja_Feriado,
    CAST(M.M_FDES  AS VARCHAR(30))   AS Calculo_Feriados,
    CAST(M.M_LDES  AS VARCHAR(30))   AS Calculo_Libres,
    CAST(M.M_DIASR AS INT)           AS Ciclo_Dias,
    CAST(M.M_DiaT  AS INT)           AS Ciclo_Dias_Trabajo,
    CAST(M.M_DiaL  AS INT)           AS Ciclo_Dias_Libres,
    CAST(M.id_grupo AS INT)          AS Grupo_Id,
    CAST(CASE M.id_grupo WHEN 1 THEN 'GENERAL'    WHEN 2 THEN 'ADMINISTRATIVO'
                         WHEN 3 THEN 'PRODUCCION' WHEN 4 THEN 'MANTENIMIENTO'
                         WHEN 5 THEN 'LOGISTICA'  ELSE 'Sin grupo' END AS VARCHAR(20))
                                     AS Grupo,

    /* Solo 36 de los 75 horarios estan bien configurados. Se marca. */
    CAST(CASE
        WHEN J.HorasNetas IS NULL               THEN 'Sin horario'
        WHEN J.HorasNetas > 13                  THEN 'Franja abierta - revisar'
        WHEN J.HorasNetas < 3                   THEN 'Jornada muy corta - revisar'
        WHEN O.HorasOrdinarias IS NULL          THEN 'Sin tramo al 100%'
        WHEN O.HorasOrdinarias > J.HorasNetas   THEN 'Ordinarias mayores que la jornada'
        WHEN O.HorasOrdinarias < 3              THEN 'Tramos mal configurados'
        ELSE 'Coherente'
    END AS VARCHAR(36))              AS Config_Horario,
    CAST(CASE WHEN J.HorasNetas IS NULL OR J.HorasNetas > 13 OR J.HorasNetas < 3
              THEN 0 ELSE 1 END AS BIT) AS Jornada_Confiable
FROM dbo.TBL_MODALIDAD M
CROSS APPLY (VALUES (0,'Lunes'    , M.M_2, M.M_2h),
                    (1,'Martes'   , M.M_3, M.M_3h),
                    (2,'Miercoles', M.M_4, M.M_4H),
                    (3,'Jueves'   , M.M_5, M.M_5H),
                    (4,'Viernes'  , M.M_6, M.M_6H),
                    (5,'Sabado'   , M.M_7, M.M_7H),
                    (6,'Domingo'  , M.M_1, M.M_1H)) AS D(DiaIdx, DiaNombre, Trabaja, H_ID)
LEFT JOIN dbo.TBL_HORARIO H ON H.H_ID = D.H_ID
OUTER APPLY (
    SELECT CAST(
        (CASE WHEN DATEDIFF(MINUTE, H.H_HENT, H.H_HSAL1) <= 0
              THEN DATEDIFF(MINUTE, H.H_HENT, H.H_HSAL1) + 1440
              ELSE DATEDIFF(MINUTE, H.H_HENT, H.H_HSAL1) END
         - CASE WHEN ISNULL(H.H_BREAK,0) = 1 THEN ISNULL(H.H_TIEMPO,0) ELSE 0 END
        ) / 60.0 AS DECIMAL(6,2)) AS HorasNetas
) AS J
OUTER APPLY (
    SELECT TOP 1
        CAST((DATEPART(HOUR,T.Tiempo)*60 + DATEPART(MINUTE,T.Tiempo)) / 60.0 AS DECIMAL(6,2)) AS HorasOrdinarias
    FROM (VALUES (H.H_1TIEMPO,H.H_1TIPO),(H.H_2TIEMPO,H.H_2TIPO),(H.H_3TIEMPO,H.H_3TIPO),
                 (H.H_4TIEMPO,H.H_4TIPO),(H.H_5TIEMPO,H.H_5TIPO),(H.H_6TIEMPO,H.H_6TIPO)
         ) AS T(Tiempo, Tipo)
    JOIN dbo.TBL_TIPO_HORA TH ON TH.TH_ID = T.Tipo
    WHERE T.Tiempo IS NOT NULL AND TH.TH_PPAGO = 100
) AS O;


/* ===========================================================================
   4 · NOVEDADES   (permisos, licencias y ausencias declaradas)
   ---------------------------------------------------------------------------
   Una fila por novedad de TBL_PERM_AUS.
   Con rango horario -> vale las horas del rango.
   De dia completo (E_FDIA = 1) -> vale la suma de las jornadas de cada dia
   efectivamente programado: 8 h si ese dia era de 8, 12 h si era de 12, y
   cero si no le tocaba trabajar o era feriado que su modalidad no trabaja.

   E_FDIA es el campo correcto para "dia completo": de 160 citas medicas de
   2025 solo 6 son de dia completo. (E_HORAS existe pero esta vacio siempre.)
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_novedades', 'V') IS NOT NULL DROP VIEW dbo.vw_th_novedades;
CREATE VIEW dbo.vw_th_novedades AS
WITH Nums AS (
    /* Generador de dias sin tablas auxiliares. 500 cubre cualquier permiso. */
    SELECT TOP 500 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i FROM sys.all_objects
),
Perm AS (
    SELECT
        P.E_EMPID, P.E_TIPOM, P.E_TIPOP, P.E_FDIA, P.E_FPAG, P.U_ID,
        CAST(CONVERT(VARCHAR(10), P.E_FINICIO, 112) AS DATETIME) AS Fecha_Inicio,
        CAST(CONVERT(VARCHAR(10), ISNULL(P.E_FFINAL,P.E_FINICIO), 112) AS DATETIME) AS Fecha_Fin,
        P.E_HoraI, P.E_HoraF,
        DATEDIFF(MINUTE, P.E_HoraI, P.E_HoraF) AS Minutos_Rango,
        C.Categoria, C.Novedad, C.Es_Pagado, C.Activo,
        E.NOMINA_COD, E.NOMINA_APE, E.NOMINA_NOM, E.EMPE_NOM,
        E.AREA_NOM, E.DEP_NOM, E.NOMINA_CAL1, E.Ciudad_Sede, E.Activo_Hoy
    FROM dbo.TBL_PERM_AUS P
    JOIN dbo.vw_th_empleado E ON E.NOMINA_ID = P.E_EMPID
    /* Clave COMPUESTA: el codigo solo es unico dentro de su categoria. */
    LEFT JOIN dbo.vw_th_catalogo_novedad C
           ON C.Categoria_Id = P.E_TIPOM AND C.Codigo = P.E_TIPOP
    WHERE E.NOMINA_EMP IN ('7','8')
      AND P.E_FINICIO >= '2018-01-01'
)
SELECT
    CAST(P.E_EMPID AS VARCHAR(50))    AS Codigo,
    P.NOMINA_COD                      AS Cedula,
    P.NOMINA_APE + ' ' + P.NOMINA_NOM AS Nombre_Completo,
    P.EMPE_NOM                        AS Sucursal,
    P.AREA_NOM                        AS Area,
    P.DEP_NOM                         AS Departamento,
    P.NOMINA_CAL1                     AS Cargo,
    P.Ciudad_Sede,
    P.Activo_Hoy,

    /* La novedad, tal cual la define TimeControl. */
    CAST(P.E_TIPOM AS INT)            AS Categoria_Id,
    CAST(ISNULL(P.Categoria,'Sin categoria') AS VARCHAR(30)) AS Categoria,
    CAST(P.E_TIPOP AS VARCHAR(2))     AS Codigo_Novedad,
    CAST(ISNULL(P.Novedad,'Codigo fuera de catalogo') AS VARCHAR(30)) AS Novedad,
    CAST(ISNULL(P.Es_Pagado,0) AS BIT) AS Es_Pagado,
    CAST(ISNULL(P.Activo,0)    AS BIT) AS Codigo_Activo,
    /* Regla de negocio de Talento Humano, tomada del propio catalogo:
       si la novedad es PAGADA la empresa la cubre y cuenta como justificada;
       si NO es pagada, es ausentismo.
       Sale del check PAGADO de la pantalla Catalogo de Novedades, asi que TH
       la cambia ahi sin tocar SQL y sin ninguna lista quemada en la vista. */
    CAST(CASE WHEN ISNULL(P.Es_Pagado,0) = 1 THEN 0 ELSE 1 END AS BIT) AS Es_Ausentismo,
    CAST(CASE WHEN ISNULL(P.Es_Pagado,0) = 1 THEN 'Justificado - pagado'
              ELSE 'Ausentismo - no pagado' END AS VARCHAR(24)) AS Clasificacion,
    CAST(CASE WHEN ISNULL(P.E_FDIA,0) = 1 THEN 'Dia completo'
              WHEN P.Minutos_Rango > 0    THEN 'Por horas'
              ELSE 'Dia completo' END AS VARCHAR(14)) AS Forma_Registro,

    P.Fecha_Inicio, P.Fecha_Fin,
    CONVERT(VARCHAR(5), P.E_HoraI, 108) AS Hora_Desde,
    CONVERT(VARCHAR(5), P.E_HoraF, 108) AS Hora_Hasta,
    CAST(DATEDIFF(DAY, P.Fecha_Inicio, P.Fecha_Fin) + 1 AS INT) AS Dias_Calendario,
    CAST(D.Dias_Programados   AS INT) AS Dias_Programados,
    CAST(D.Dias_Feriado       AS INT) AS Dias_Feriado,
    CAST(D.Dias_No_Laborables AS INT) AS Dias_No_Laborables,

    CAST(J.Modalidad     AS VARCHAR(255)) AS Modalidad,
    CAST(J.Horario       AS VARCHAR(120)) AS Horario,
    CAST(J.Horas_Jornada AS DECIMAL(6,2)) AS Horas_Jornada_Dia,
    CAST(J.Tipo_Jornada  AS VARCHAR(20))  AS Tipo_Jornada,
    CAST(J.Origen        AS VARCHAR(30))  AS Origen_Jornada,

    CAST(CASE WHEN ISNULL(P.E_FDIA,0) = 0 AND P.Minutos_Rango > 0
              THEN P.Minutos_Rango / 60.0
              ELSE D.Horas_Programadas
         END AS DECIMAL(9,2))         AS Horas_Novedad,

    /* Periodo de nomina 21 -> 20, sin DATEFROMPARTS (no existe en 2008 R2). */
    CAST(CONVERT(VARCHAR(10), PN.Ini, 105) + ' al '
       + CONVERT(VARCHAR(10), DATEADD(DAY,-1,DATEADD(MONTH,1,PN.Ini)), 105)
         AS VARCHAR(40))              AS Periodo_Nomina,
    CAST(PN.Ini AS DATETIME)          AS Periodo_Inicio,
    CAST(YEAR(P.Fecha_Inicio)  AS SMALLINT) AS Anio,
    CAST(MONTH(P.Fecha_Inicio) AS TINYINT)  AS Mes,
    CAST(P.U_ID AS VARCHAR(10))       AS Usuario_Registra

FROM Perm P
CROSS APPLY (
    SELECT DATEADD(DAY, 20, DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(DAY,-20,P.Fecha_Inicio)), 0)) AS Ini
) AS PN
/* Jornada de referencia. Cascada de 3 niveles; Origen_Jornada dice cual se uso:
   1) el horario que el sistema asigno ese dia (unico que resuelve rotativos)
   2) la modalidad vigente cruzada con el dia de la semana
   3) 8 h por defecto */
OUTER APPLY (
    SELECT TOP 1
        COALESCE(HA.H_NOM, HM.Horario)                  AS Horario,
        COALESCE(JA.HorasNetas, HM.Horas_Jornada, 8.00) AS Horas_Jornada,
        COALESCE(MA.M_DES, HM.Modalidad)                AS Modalidad,
        CASE WHEN HA.H_ID       IS NOT NULL THEN 'Asistencia del dia'
             WHEN HM.Horario_Id IS NOT NULL THEN 'Modalidad x dia'
             ELSE 'Por defecto 8 h' END                 AS Origen,
        CASE WHEN JA.HorasNetas IS NOT NULL THEN
                  CASE WHEN JA.HorasNetas >= 7.5 AND JA.HorasNetas <  9.5 THEN '8 horas'
                       WHEN JA.HorasNetas >= 11  AND JA.HorasNetas <= 13  THEN '12 horas'
                       WHEN JA.HorasNetas <  7.5                          THEN 'Parcial'
                       ELSE 'Revisar' END
             ELSE ISNULL(HM.Tipo_Jornada, '8 horas') END AS Tipo_Jornada
    FROM (SELECT 1 AS x) Z
    OUTER APPLY (
        SELECT TOP 1 A.horario
        FROM dbo.TBL_ASISTENCIA A
        WHERE A.EMP_ID = P.E_EMPID
          AND A.Fecha_Ingreso >= P.Fecha_Inicio
          AND A.Fecha_Ingreso <  DATEADD(DAY,1,P.Fecha_Inicio)
          AND A.horario IS NOT NULL
    ) AR
    LEFT JOIN dbo.TBL_HORARIO HA ON HA.H_ID = AR.horario
    OUTER APPLY (
        SELECT CAST((CASE WHEN DATEDIFF(MINUTE,HA.H_HENT,HA.H_HSAL1) <= 0
                          THEN DATEDIFF(MINUTE,HA.H_HENT,HA.H_HSAL1)+1440
                          ELSE DATEDIFF(MINUTE,HA.H_HENT,HA.H_HSAL1) END
                     - CASE WHEN ISNULL(HA.H_BREAK,0)=1 THEN ISNULL(HA.H_TIEMPO,0) ELSE 0 END
                    ) / 60.0 AS DECIMAL(6,2)) AS HorasNetas
    ) JA
    OUTER APPLY (
        SELECT TOP 1 T.H_IDMOD
        FROM dbo.TBL_T_HORARIOS T
        WHERE T.H_EMPID = P.E_EMPID AND T.H_FECHA <= P.Fecha_Inicio
        ORDER BY T.H_FECHA DESC
    ) TM
    LEFT JOIN dbo.TBL_MODALIDAD MA ON MA.M_ID = TM.H_IDMOD
    LEFT JOIN dbo.vw_th_jornada_modalidad HM
           ON HM.Modalidad_Id = TM.H_IDMOD
          AND HM.DiaIdx = DATEDIFF(DAY,'19000101', P.Fecha_Inicio) % 7
) AS J
CROSS APPLY (
    SELECT
        SUM(CASE WHEN Dia.Laborable = 1 THEN 1 ELSE 0 END) AS Dias_Programados,
        SUM(CASE WHEN Dia.EsFeriado = 1 THEN 1 ELSE 0 END) AS Dias_Feriado,
        SUM(CASE WHEN Dia.Laborable = 0 AND Dia.EsFeriado = 0 THEN 1 ELSE 0 END) AS Dias_No_Laborables,
        CAST(SUM(CASE WHEN Dia.Laborable = 1 THEN Dia.Horas ELSE 0 END) AS DECIMAL(9,2)) AS Horas_Programadas
    FROM (
        SELECT
            F.Fecha,
            CASE WHEN FE.D_FESTIVO IS NOT NULL THEN 1 ELSE 0 END AS EsFeriado,
            /* El feriado solo deja de contar si la modalidad no lo trabaja. */
            CASE WHEN FE.D_FESTIVO IS NOT NULL
                  AND ISNULL(JD.Trabaja_Feriado,0) = 0 THEN 0
                 WHEN JD.Modalidad_Id IS NULL          THEN 1
                 WHEN JD.Trabaja_Dia = 1               THEN 1
                 ELSE 0 END                            AS Laborable,
            ISNULL(JD.Horas_Jornada, J.Horas_Jornada)  AS Horas
        FROM (SELECT DATEADD(DAY, n.i, P.Fecha_Inicio) AS Fecha
              FROM Nums n
              WHERE n.i <= DATEDIFF(DAY, P.Fecha_Inicio, P.Fecha_Fin)) F
        LEFT JOIN (SELECT DISTINCT CAST(CONVERT(VARCHAR(10),D_FESTIVO,112) AS DATETIME) AS D_FESTIVO
                   FROM dbo.TBL_FESTIVOS) FE
               ON FE.D_FESTIVO = F.Fecha
        LEFT JOIN dbo.vw_th_jornada_modalidad JD
               ON JD.Modalidad = J.Modalidad
              AND JD.DiaIdx = DATEDIFF(DAY,'19000101', F.Fecha) % 7
    ) AS Dia
) AS D;


/* ===========================================================================
   5 · TIMBRADAS   (asistencia diaria y cumplimiento de horario)
   ---------------------------------------------------------------------------
   Una fila por dia de TBL_ASISTENCIA.

   El estado del dia lo dicta TimeControl con Novedad_Entrada y Novedad_Salida,
   que son codigos del mismo catalogo. No se recalcula el atraso con umbrales
   propios: el sistema ya distingue EG (dentro de la gracia) de AI (atraso
   injustificado), y ya sabe que esta justificado (AJ, FJ, SJ, MM).
   La gracia es por horario (H_GENT): 15 min en 55 horarios, 0 en 12, 180 en 3
   y 640 en 4. Un umbral fijo de 15 min fallaba en 19 de los 75.

   Las horas perdidas salen de No_Laborado, que el sistema ya calcula contra
   el horario real: 480 = 8 h, 720 = 12 h, 540 = 9 h, 360 = 6 h. Verificado
   contra la jornada programada de cada fila en las faltas de 2026.
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_timbradas', 'V') IS NOT NULL DROP VIEW dbo.vw_th_timbradas;
CREATE VIEW dbo.vw_th_timbradas AS
WITH Base AS (
    SELECT
        A.EMP_ID,
        CAST(CONVERT(VARCHAR(10), A.Fecha_Ingreso, 112) AS DATETIME) AS Fecha,
        DATEDIFF(DAY,'19000101', A.Fecha_Ingreso) % 7 AS DiaIdx,
        DATEADD(DAY, -(DATEDIFF(DAY,'19000101', A.Fecha_Ingreso) % 7),
                CAST(CONVERT(VARCHAR(10), A.Fecha_Ingreso, 112) AS DATETIME)) AS Semana_Inicio,
        A.Hora_Ingreso, A.Hora_Salida, A.HORARIO_INGRESO, A.HORARIO_SALIDA,
        A.Novedad_Entrada, A.Novedad_Salida,
        ISNULL(A.min_AT,0)            AS Min_Atraso,
        ISNULL(A.min_SA,0)            AS Min_Salida_Antic,
        ISNULL(A.No_Laborado,0)       AS Min_No_Laborado,
        ISNULL(A.Hora_Extra_Tiempo,0) AS Min_Hora_Extra,
        ISNULL(A.Lunch_Total,0)       AS Lunch_Marcado_Min,
        E.NOMINA_COD, E.NOMINA_APE, E.NOMINA_NOM, E.EMPE_NOM,
        E.AREA_NOM, E.DEP_NOM, E.NOMINA_CAL1, E.Ciudad_Sede, E.Activo_Hoy,
        H.H_NOM                       AS Horario_Nombre,
        CASE WHEN ISNULL(H.H_BREAK,0) = 1 THEN ISNULL(H.H_TIEMPO,0) ELSE 0 END AS Lunch_Fijo_Min,
        ISNULL(H.H_BREAK,0)           AS Controla_Lunch,
        ISNULL(H.H_GENT ,0)           AS Gracia_Ent,
        M.M_DES                       AS Modalidad_Nombre,
        CASE WHEN FE.D_FESTIVO IS NOT NULL THEN 1 ELSE 0 END AS Es_Feriado,
        ISNULL(JM.Trabaja_Feriado,0)  AS Trabaja_Feriado,
        ISNULL(JM.Horario_Solo_Finde,0) AS Horario_Solo_Finde,
        JM.Horas_Ordinarias, JM.Grupo, JM.Trabaja_Dia,
        NE.Novedad AS Novedad_Entrada_Nom,
        NS.Novedad AS Novedad_Salida_Nom,
        /* Del lado de las marcaciones el catalogo NO usa el flag PAGADO:
           todos los codigos de las categorias 2, 6, 9 y 11 tienen CD_PAGADO=0.
           El equivalente aqui es la categoria: 9 y 11 son JUSTIFICACIONES
           (AJ atraso justificado, FJ falta justificada, SJ salida justificada,
           MM marcacion manual). Mismo principio: lo que la empresa cubre no
           es ausentismo, y sale del catalogo, no de una lista quemada. */
        CASE WHEN ISNULL(NE.Es_Justificacion,0) = 1
                  OR ISNULL(NS.Es_Justificacion,0) = 1 THEN 1 ELSE 0 END AS Justificado,
        CASE
            WHEN A.HORARIO_INGRESO IS NOT NULL AND A.HORARIO_SALIDA IS NOT NULL
             AND NOT (DATEPART(HOUR,A.HORARIO_INGRESO)=0 AND DATEPART(MINUTE,A.HORARIO_INGRESO)=0
                  AND DATEPART(HOUR,A.HORARIO_SALIDA )=0 AND DATEPART(MINUTE,A.HORARIO_SALIDA )=0)
            THEN (CASE WHEN DATEDIFF(MINUTE,A.HORARIO_INGRESO,A.HORARIO_SALIDA) <= 0
                       THEN DATEDIFF(MINUTE,A.HORARIO_INGRESO,A.HORARIO_SALIDA)+1440
                       ELSE DATEDIFF(MINUTE,A.HORARIO_INGRESO,A.HORARIO_SALIDA) END)
                 - CASE WHEN ISNULL(H.H_BREAK,0) = 1 THEN ISNULL(H.H_TIEMPO,0) ELSE 0 END
            ELSE NULL
        END                           AS Prog_Min,
        CASE
            WHEN A.Hora_Ingreso IS NULL OR A.Hora_Salida IS NULL THEN NULL
            ELSE (CASE WHEN DATEDIFF(MINUTE,A.Hora_Ingreso,A.Hora_Salida) <= 0
                       THEN DATEDIFF(MINUTE,A.Hora_Ingreso,A.Hora_Salida)+1440
                       ELSE DATEDIFF(MINUTE,A.Hora_Ingreso,A.Hora_Salida) END)
        END                           AS Presencia_Min
    FROM dbo.TBL_ASISTENCIA A
    JOIN dbo.vw_th_empleado E ON E.NOMINA_ID = A.EMP_ID
    LEFT JOIN dbo.TBL_HORARIO   H ON H.H_ID = A.horario
    LEFT JOIN dbo.TBL_MODALIDAD M ON M.M_ID = A.modalidad
    OUTER APPLY (SELECT TOP 1 C.Novedad, C.Es_Justificacion
                 FROM dbo.vw_th_catalogo_novedad C
                 WHERE C.Codigo = A.Novedad_Entrada AND C.Categoria_Id IN (6,9)
                 ORDER BY C.Categoria_Id DESC) NE
    OUTER APPLY (SELECT TOP 1 C.Novedad, C.Es_Justificacion
                 FROM dbo.vw_th_catalogo_novedad C
                 WHERE C.Codigo = A.Novedad_Salida  AND C.Categoria_Id IN (2,11)
                 ORDER BY C.Categoria_Id DESC) NS
    LEFT JOIN (SELECT DISTINCT CAST(CONVERT(VARCHAR(10),D_FESTIVO,112) AS DATETIME) AS D_FESTIVO
               FROM dbo.TBL_FESTIVOS) FE
           ON FE.D_FESTIVO = CAST(CONVERT(VARCHAR(10), A.Fecha_Ingreso, 112) AS DATETIME)
    LEFT JOIN dbo.vw_th_jornada_modalidad JM
           ON JM.Modalidad_Id = A.modalidad
          AND JM.DiaIdx = DATEDIFF(DAY,'19000101', A.Fecha_Ingreso) % 7
    WHERE E.NOMINA_EMP IN ('7','8')
      AND A.Fecha_Ingreso >= '2018-01-01'
),
Calc AS (
    SELECT B.*,
        /* Almuerzo: si el horario no lo controla, no se descuenta nada. Si lo
           controla, se usa el almuerzo realmente marcado y si no hay marca se
           cae al tiempo fijo del horario. */
        CASE WHEN B.Presencia_Min IS NULL THEN NULL
             WHEN B.Controla_Lunch = 0    THEN B.Presencia_Min
             WHEN B.Presencia_Min <= B.Lunch_Fijo_Min + 240 THEN B.Presencia_Min
             ELSE B.Presencia_Min - CASE WHEN B.Lunch_Marcado_Min > 0
                                         THEN B.Lunch_Marcado_Min
                                         ELSE B.Lunch_Fijo_Min END
        END AS Marcado_Min,
        CASE WHEN B.Es_Feriado = 1 AND B.Trabaja_Feriado = 0 THEN 0
             WHEN B.Prog_Min IS NULL OR B.Prog_Min <= 0 THEN 0
             WHEN B.Trabaja_Dia = 0 AND B.Hora_Ingreso IS NULL THEN 0
             /* Fin de semana habilitado solo para horas extras y sin ninguna
                marcacion: no era jornada, era disponibilidad. Si marco, si
                cuenta, porque entonces si trabajo. */
             WHEN B.Horario_Solo_Finde = 1
                  AND B.Hora_Ingreso IS NULL AND B.Hora_Salida IS NULL THEN 0
             ELSE 1 END AS Dia_Programado,
        CASE
            WHEN B.Es_Feriado = 1 AND B.Trabaja_Feriado = 0            THEN 'Feriado'
            /* Antes que cualquier otra cosa: si el fin de semana solo estaba
               habilitado para horas extras y no marco, fue dia libre. Time
               Control igual escribe FI ahi, y por eso la vista anterior lo
               excluia con un LIKE por nombre de modalidad. */
            WHEN B.Horario_Solo_Finde = 1
                 AND B.Hora_Ingreso IS NULL AND B.Hora_Salida IS NULL  THEN 'Dia libre'
            WHEN B.Novedad_Entrada = 'FI'                             THEN 'Falta injustificada'
            WHEN B.Novedad_Entrada = 'FJ' OR B.Novedad_Salida = 'FJ'  THEN 'Falta justificada'
            WHEN B.Novedad_Entrada = 'PE' OR B.Novedad_Salida = 'PE'  THEN 'Permiso'
            WHEN B.Novedad_Entrada = 'AI' AND B.Novedad_Salida = 'SA' THEN 'Atraso y salida anticipada'
            WHEN B.Novedad_Entrada = 'AI'                             THEN 'Atraso injustificado'
            WHEN B.Novedad_Entrada = 'AJ'                             THEN 'Atraso justificado'
            WHEN B.Novedad_Salida  = 'SA'                             THEN 'Salida anticipada'
            WHEN B.Novedad_Salida  = 'SJ'                             THEN 'Salida anticipada justificada'
            WHEN B.Novedad_Entrada = 'NF' OR B.Novedad_Salida = 'NF'  THEN 'No firmo'
            WHEN B.Novedad_Entrada = 'MM' OR B.Novedad_Salida = 'MM'  THEN 'Marcacion manual'
            WHEN B.Novedad_Entrada = 'EG'                             THEN 'Cumple (dentro de gracia)'
            WHEN B.Novedad_Entrada = 'OK' AND B.Novedad_Salida = 'OK' THEN 'Cumple'
            WHEN B.Hora_Ingreso IS NULL AND B.Hora_Salida IS NULL     THEN 'Sin marcacion'
            WHEN B.Hora_Ingreso IS NULL OR  B.Hora_Salida IS NULL     THEN 'Marcacion incompleta'
            ELSE 'Revisar'
        END AS Estado_Dia
    FROM Base B
)
SELECT
    CAST(C.EMP_ID AS VARCHAR(50))     AS Codigo,
    C.NOMINA_COD                      AS Cedula,
    C.NOMINA_APE + ' ' + C.NOMINA_NOM AS Nombre_Completo,
    C.EMPE_NOM AS Sucursal, C.AREA_NOM AS Area,
    C.DEP_NOM  AS Departamento, C.NOMINA_CAL1 AS Cargo,
    C.Ciudad_Sede, C.Activo_Hoy,

    C.Fecha,
    CAST(CASE C.DiaIdx WHEN 0 THEN 'Lunes'  WHEN 1 THEN 'Martes'  WHEN 2 THEN 'Miercoles'
                       WHEN 3 THEN 'Jueves' WHEN 4 THEN 'Viernes' WHEN 5 THEN 'Sabado'
                       ELSE 'Domingo' END AS VARCHAR(10)) AS Dia,
    CAST(C.Es_Feriado     AS BIT)     AS Es_Feriado,
    CAST(C.Dia_Programado AS BIT)     AS Dia_Programado,

    CAST(ISNULL(C.Modalidad_Nombre,'Sin modalidad') AS VARCHAR(255)) AS Modalidad,
    CAST(ISNULL(C.Horario_Nombre  ,'Sin horario'  ) AS VARCHAR(120)) AS Horario,
    CAST(ISNULL(C.Grupo,'Sin grupo') AS VARCHAR(20)) AS Grupo,
    CONVERT(VARCHAR(5), C.HORARIO_INGRESO, 108) AS Entrada_Programada,
    CONVERT(VARCHAR(5), C.HORARIO_SALIDA , 108) AS Salida_Programada,
    CAST(C.Gracia_Ent     AS INT)     AS Gracia_Entrada_Min,
    CAST(C.Lunch_Fijo_Min AS INT)     AS Lunch_Descontado_Min,
    CAST(C.Controla_Lunch AS BIT)     AS Controla_Lunch,
    CAST(C.Trabaja_Feriado AS BIT)    AS Modalidad_Trabaja_Feriado,
    CAST(C.Prog_Min / 60.0 AS DECIMAL(6,2))       AS Horas_Programadas,
    CAST(C.Horas_Ordinarias AS DECIMAL(6,2))      AS Horas_Ordinarias,
    CAST(C.Min_Hora_Extra / 60.0 AS DECIMAL(6,2)) AS Horas_Extra,
    CAST(CASE
        WHEN C.Prog_Min IS NULL                                THEN 'Sin horario'
        WHEN C.Prog_Min/60.0 >= 7.5 AND C.Prog_Min/60.0 <  9.5 THEN '8 horas'
        WHEN C.Prog_Min/60.0 >= 11  AND C.Prog_Min/60.0 <= 13  THEN '12 horas'
        WHEN C.Prog_Min/60.0 <  7.5                            THEN 'Parcial'
        ELSE 'Revisar' END AS VARCHAR(20))        AS Tipo_Jornada,

    CONVERT(VARCHAR(5), C.Hora_Ingreso, 108)      AS Entrada_Real,
    CONVERT(VARCHAR(5), C.Hora_Salida , 108)      AS Salida_Real,
    CAST(C.Marcado_Min / 60.0 AS DECIMAL(6,2))    AS Horas_Marcadas,
    CAST((C.Marcado_Min - C.Prog_Min) / 60.0 AS DECIMAL(6,2)) AS Saldo_Horas_Dia,

    CAST(C.Novedad_Entrada AS VARCHAR(2))         AS Cod_Entrada,
    CAST(ISNULL(C.Novedad_Entrada_Nom,'-') AS VARCHAR(30)) AS Novedad_Entrada,
    CAST(C.Novedad_Salida  AS VARCHAR(2))         AS Cod_Salida,
    CAST(ISNULL(C.Novedad_Salida_Nom ,'-') AS VARCHAR(30)) AS Novedad_Salida,
    CAST(C.Min_Atraso       AS INT)               AS Minutos_Atraso,
    CAST(C.Min_Salida_Antic AS INT)               AS Minutos_Salida_Anticipada,
    CAST(C.Estado_Dia AS VARCHAR(32))             AS Estado_Dia,
    /* Justificado = el codigo viene de una categoria de JUSTIFICACIONES (9/11),
       o el dia esta amparado por un permiso (PE). Es el equivalente, del lado
       de las marcaciones, al check PAGADO de las novedades. */
    CAST(CASE WHEN C.Justificado = 1
                   OR C.Novedad_Entrada = 'PE' OR C.Novedad_Salida = 'PE'
              THEN 1 ELSE 0 END AS BIT)           AS Es_Justificado,
    /* Ausentismo = dia programado, no cumplido y NO justificado. */
    CAST(CASE WHEN C.Dia_Programado = 1
                   AND C.Justificado = 0
                   AND C.Estado_Dia IN ('Falta injustificada','Atraso injustificado',
                                        'Atraso y salida anticipada','Salida anticipada',
                                        'Sin marcacion','Marcacion incompleta')
              THEN 1 ELSE 0 END AS BIT)           AS Es_Ausentismo,
    CAST(CASE WHEN C.Dia_Programado = 1
                   AND C.Estado_Dia IN ('Falta injustificada','Atraso injustificado',
                                        'Atraso y salida anticipada','Salida anticipada',
                                        'Sin marcacion','Marcacion incompleta')
              THEN 1 ELSE 0 END AS BIT)           AS Es_Incumplimiento,
    /* Se prefiere No_Laborado del sistema; solo si viene en cero se calcula. */
    /* Si el dia no era programado no se pierde nada, aunque Time Control
       haya escrito minutos en No_Laborado. */
    CAST(CASE WHEN C.Dia_Programado = 0 THEN 0
              WHEN C.Min_No_Laborado > 0 THEN C.Min_No_Laborado / 60.0
              WHEN C.Prog_Min > ISNULL(C.Marcado_Min,0)
                   THEN (C.Prog_Min - ISNULL(C.Marcado_Min,0)) / 60.0
              ELSE 0 END AS DECIMAL(6,2))         AS Horas_No_Trabajadas,
    CAST(CASE WHEN C.Min_No_Laborado > 0 THEN 'TimeControl (No_Laborado)'
              ELSE 'Calculado (programado - marcado)' END AS VARCHAR(32))
                                                  AS Origen_Horas_Perdidas,

    C.Semana_Inicio,
    CAST(DATEADD(DAY,6,C.Semana_Inicio) AS DATETIME) AS Semana_Fin,
    CAST(SUM(CASE WHEN C.Dia_Programado=1 THEN C.Prog_Min ELSE 0 END)
         OVER (PARTITION BY C.EMP_ID, C.Semana_Inicio) / 60.0 AS DECIMAL(7,2))
                                                  AS Horas_Programadas_Semana,
    CAST(SUM(CASE WHEN C.Dia_Programado=1 THEN ISNULL(C.Marcado_Min,0) ELSE 0 END)
         OVER (PARTITION BY C.EMP_ID, C.Semana_Inicio) / 60.0 AS DECIMAL(7,2))
                                                  AS Horas_Marcadas_Semana,
    CAST((SUM(CASE WHEN C.Dia_Programado=1 THEN ISNULL(C.Marcado_Min,0) ELSE 0 END)
          OVER (PARTITION BY C.EMP_ID, C.Semana_Inicio)
        - SUM(CASE WHEN C.Dia_Programado=1 THEN C.Prog_Min ELSE 0 END)
          OVER (PARTITION BY C.EMP_ID, C.Semana_Inicio)) / 60.0 AS DECIMAL(7,2))
                                                  AS Saldo_Horas_Semana,
    CAST(SUM(CASE WHEN C.Dia_Programado=1 THEN 1 ELSE 0 END)
         OVER (PARTITION BY C.EMP_ID, C.Semana_Inicio) AS INT)
                                                  AS Dias_Programados_Semana,
    CAST(CASE WHEN SUM(CASE WHEN C.Dia_Programado=1 THEN ISNULL(C.Marcado_Min,0) ELSE 0 END)
                   OVER (PARTITION BY C.EMP_ID, C.Semana_Inicio)
                 >= SUM(CASE WHEN C.Dia_Programado=1 THEN C.Prog_Min ELSE 0 END)
                   OVER (PARTITION BY C.EMP_ID, C.Semana_Inicio)
              THEN 'Cumple semana' ELSE 'No cumple semana' END AS VARCHAR(20))
                                                  AS Cumplimiento_Semana,

    CAST(CONVERT(VARCHAR(10), PN.Ini, 105) + ' al '
       + CONVERT(VARCHAR(10), DATEADD(DAY,-1,DATEADD(MONTH,1,PN.Ini)), 105)
         AS VARCHAR(40))                          AS Periodo_Nomina,
    CAST(PN.Ini AS DATETIME)                      AS Periodo_Inicio,
    CAST(YEAR(C.Fecha)  AS SMALLINT)              AS Anio,
    CAST(MONTH(C.Fecha) AS TINYINT)               AS Mes
FROM Calc C
CROSS APPLY (
    SELECT DATEADD(DAY, 20, DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(DAY,-20,C.Fecha)), 0)) AS Ini
) AS PN;

/* ===========================================================================
   6 · PERMISOS PARA EL LINKED SERVER
   ---------------------------------------------------------------------------
   Descomentar y ejecutar con el login que usa TH desde el linked server ONLYC.
   =========================================================================== */
/*

GRANT SELECT ON dbo.vw_th_empleado           TO ocaccess;
GRANT SELECT ON dbo.vw_th_catalogo_novedad   TO ocaccess;
GRANT SELECT ON dbo.vw_th_jornada_modalidad  TO ocaccess;
GRANT SELECT ON dbo.vw_th_novedades          TO ocaccess;
GRANT SELECT ON dbo.vw_th_timbradas          TO ocaccess;
*/

/* ===========================================================================
   7 · PRUEBAS LOCALES  (ejecutar AQUI, en TCONTROL, antes de ir a TH)
   =========================================================================== */

-- P1 · Horarios mal configurados. Solo 36 de 75 salen 'Coherente'.
/*
SELECT Config_Horario, COUNT(*) AS dias_modalidad
FROM dbo.vw_th_jornada_modalidad
GROUP BY Config_Horario ORDER BY dias_modalidad DESC;
*/

-- P2 · Cuantas modalidades son de 8 h y cuantas de 12 h.
/*
SELECT Tipo_Jornada, COUNT(DISTINCT Modalidad) AS modalidades
FROM dbo.vw_th_jornada_modalidad WHERE Trabaja_Dia = 1
GROUP BY Tipo_Jornada ORDER BY modalidades DESC;
*/

-- P3 · Estado de los dias del mes. Verifica que el catalogo resuelva.
/*
SELECT Estado_Dia, Tipo_Jornada, COUNT(*) AS dias,
       SUM(Horas_No_Trabajadas) AS horas_perdidas
FROM dbo.vw_th_timbradas
WHERE Fecha >= '2026-08-01' AND Fecha < '2026-09-01'
GROUP BY Estado_Dia, Tipo_Jornada ORDER BY dias DESC;
*/

-- P4 · Novedades del periodo, con el codigo real del catalogo.
/*
SELECT Codigo_Novedad, Novedad, Es_Pagado, Forma_Registro,
       COUNT(*) AS casos, SUM(Horas_Novedad) AS horas
FROM dbo.vw_th_novedades
WHERE Fecha_Inicio >= '2026-07-21' AND Fecha_Inicio <= '2026-08-20'
GROUP BY Codigo_Novedad, Novedad, Es_Pagado, Forma_Registro
ORDER BY horas DESC;
*/
