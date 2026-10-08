/* ============================================================================
   AUSENTISMO · PARTE 2 de 2   ·   CONSUMO EN TH
   Servidor: SRV-APP\SQLEXPRESS (192.168.20.15)      Base: TH
   ----------------------------------------------------------------------------
   Requiere haber ejecutado antes ausentismo_1_vistas_en_tcontrol.sql en
   SRV-BIOM-001\SQLEXPRESS2008R2, base TCONTROL.

   POR QUE HAY TRES TABLAS AQUI  (medido, no supuesto)
   ---------------------------------------------------
   El origen entrega sus dos vistas rapido:
       vw_th_novedades    23.525 filas en  0,25 s
       vw_th_timbradas   734.234 filas en  9,0  s  (proyeccion completa)
   Lo que NO aguanta SRV-BIOM-001 es cruzarlas: un FULL OUTER JOIN a grano de
   dia sobre 747.632 filas expira en ese servidor. Es SQL Server 2008 R2
   EXPRESS, con tope de 1 GB de memoria; no hay ajuste de consulta que lo
   salve, se probo.

   Asi que cada servidor hace lo que puede hacer bien:
       TCONTROL  resuelve la logica de negocio y entrega dos flujos planos
       TH        guarda esos flujos y hace el cruce en local, con indices

   La tercera tabla dice en que periodos cobro rol cada persona, y sale de los
   roles de pago (EMP_NOM, MySQL). Cruzar nomina en vivo contra 747 mil filas
   subia el fact de 1,75 s a 38 s. Materializada de noche y con la agregacion
   empujada a MySQL por OPENQUERY, la vista completa tarda unos 6 s (1,5 s sin
   calcular En_Nomina).

   ESTO ADEMAS CONGELA EL HISTORIAL
   --------------------------------
   Las vistas leen en vivo: si Talento Humano edita una marcacion de hace seis
   meses, el reporte ya publicado cambia solo. Al guardar la foto cada noche,
   el periodo cerrado deja de moverse. Era el unico problema que la
   arquitectura de vistas no resolvia.

   Las tablas NO duplican ningun catalogo: son la foto de los hechos. El
   catalogo de novedades y las modalidades se siguen leyendo en vivo del
   origen, porque son chicos y deben reflejar lo que TH cambie hoy mismo.

   COMO SE OPERA
   -------------
     Una vez  : correr este script completo
     Cada noche: EXEC dbo.sp_th_cargar_ausentismo   (agendar en SQL Agent)
     Power BI : leer dbo.vw_th_ausentismo

   Sin separadores GO: cada sentencia termina en ; y el cliente las manda una
   por una. En DBeaver, Ejecutar script (Alt+X).
   Se usa DROP + CREATE, no CREATE OR ALTER, para que los dos scripts se
   ejecuten igual. Si el editor te cambia CREATE por ALTER, falla.
   ============================================================================ */

USE TH;

/* ===========================================================================
   1 · LA FOTO DEL ORIGEN
   ---------------------------------------------------------------------------
   El esquema se deriva solo del origen con WHERE 1=0, para no mantener a mano
   90 columnas. Si manana cambia una vista del origen, basta con borrar la
   tabla y volver a correr este bloque.
   =========================================================================== */
IF OBJECT_ID('dbo.stg_th_novedades') IS NULL
    SELECT * INTO dbo.stg_th_novedades
    FROM OPENQUERY([ONLYC], 'SELECT * FROM TCONTROL.dbo.vw_th_novedades WHERE 1=0');

IF OBJECT_ID('dbo.stg_th_timbradas') IS NULL
    SELECT * INTO dbo.stg_th_timbradas
    FROM OPENQUERY([ONLYC], 'SELECT * FROM TCONTROL.dbo.vw_th_timbradas WHERE 1=0');

/* QUIEN ESTABA EN NOMINA EN CADA PERIODO
   --------------------------------------
   Una fila por persona y periodo de nomina (21->20) en que cobro rol. Es la
   MISMA poblacion que cuenta el denominador: la medida de headcount de Power
   BI ('Colaboradores por Mes') cuenta cedulas con lineas de rol en estos
   cuatro conceptos, y el Calendario Nomina asigna cada Fecha_Rol a su periodo
   con la misma regla del dia 21. Quien no esta en el denominador de un
   periodo no puede estar en su numerador.

   Se probaron y descartaron las alternativas:
     * rp01fechaingreso: se sobrescribe en migraciones y cambios de contrato.
       62 personas marcan antes de su supuesto ingreso, con 3.595 h reales;
       ocho comparten la fecha inventada 2024-12-01.
     * Solo el primer rol: cubre a los candidatos que se enrolan antes de
       entrar, pero no a quien se va y nadie desactiva en OnlyControl. Un
       grupo de GYE retirado en 2022-2023 siguio generando faltas hasta
       feb-2025, 1.890 h por persona.
     * Rol de cualquier concepto: en abril cobran utilidades los ex empleados,
       430 personas con rol contra ~350 el resto del ano.
     * El rol del mes siguiente al periodo: queda desfasado un mes del
       denominador, que empareja 21-jul -> 20-ago con el rol del 31-jul.
   Medido: del historial quedan fuera 54.509 h de 267.926, y el 95,5 % son
   faltas sin marcacion de gente que ese periodo no estaba en nomina.

   La agregacion se empuja a MySQL con OPENQUERY: viajan solo los pares
   persona-periodo, no todas las lineas de rol.

   NVARCHAR y no VARCHAR a proposito: Cedula llega como nvarchar(15) desde el
   origen. Si esta tabla fuera VARCHAR, cada comparacion convertiria la columna
   a NVARCHAR (mayor precedencia) y el indice dejaria de servir. */
IF OBJECT_ID('dbo.stg_th_nomina') IS NOT NULL
   AND COL_LENGTH('dbo.stg_th_nomina', 'Periodo_ID') IS NULL
    DROP TABLE dbo.stg_th_nomina;

IF OBJECT_ID('dbo.stg_th_nomina') IS NULL
    CREATE TABLE dbo.stg_th_nomina (
        Cedula     NVARCHAR(25) NOT NULL,
        Periodo_ID INT          NOT NULL,  -- YYYYMM del mes en que INICIA el periodo, = 'Periodo Nomina ID'
        CONSTRAINT PK_stg_th_nomina PRIMARY KEY CLUSTERED (Cedula, Periodo_ID)
    );

/* Indices para el cruce y para los filtros de fecha del tablero. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_stg_nov_cod_fecha')
    CREATE INDEX IX_stg_nov_cod_fecha ON dbo.stg_th_novedades (Codigo, Fecha_Inicio, Fecha_Fin);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_stg_tim_cod_fecha')
    CREATE INDEX IX_stg_tim_cod_fecha ON dbo.stg_th_timbradas (Codigo, Fecha);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_stg_tim_fecha')
    CREATE INDEX IX_stg_tim_fecha ON dbo.stg_th_timbradas (Fecha) INCLUDE (Codigo);


/* ===========================================================================
   2 · CARGA NOCTURNA
   ---------------------------------------------------------------------------
   OPENQUERY y no nombre de cuatro partes: garantiza que el origen resuelva su
   propia vista y por la red viaje solo el resultado.
   =========================================================================== */
IF OBJECT_ID('dbo.sp_th_cargar_ausentismo', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_th_cargar_ausentismo;
CREATE PROCEDURE dbo.sp_th_cargar_ausentismo
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ini DATETIME = GETDATE();
    DECLARE @nov INT, @tim INT, @nom INT;

    BEGIN TRAN;

    /* Primero la nomina: es el tramo mas fragil (MySQL por linked server). Si
       esa conexion esta caida conviene fallar aqui, antes de traer 734 mil
       filas del biometrico, y que el job avise. */
    /* Cada linea de rol se asigna a su periodo igual que el Calendario
       Nomina: una Fecha_Rol del dia 21 en adelante cae en el periodo que
       inicia ese mes; antes del 21, en el que inicio el mes anterior. Restar
       20 dias y tomar el ano-mes da exactamente eso. Los cuatro conceptos son
       los mismos de la medida de headcount: sin ese filtro entrarian las
       utilidades que en abril se pagan a ex empleados. */
    TRUNCATE TABLE dbo.stg_th_nomina;
    INSERT INTO dbo.stg_th_nomina (Cedula, Periodo_ID)
    SELECT * FROM OPENQUERY([EMP_NOM],
        'SELECT rp05noemp AS ced,
                YEAR(DATE_SUB(rp05fechaliq, INTERVAL 20 DAY)) * 100
              + MONTH(DATE_SUB(rp05fechaliq, INTERVAL 20 DAY)) AS periodo
         FROM liqrol
         WHERE rp05conc1 IN (''01'', ''41'', ''81'', ''85'')
           AND rp05noemp IS NOT NULL AND rp05noemp <> ''''
         GROUP BY ced, periodo');
    SET @nom = @@ROWCOUNT;

    TRUNCATE TABLE dbo.stg_th_novedades;
    INSERT INTO dbo.stg_th_novedades
    SELECT * FROM OPENQUERY([ONLYC], 'SELECT * FROM TCONTROL.dbo.vw_th_novedades');
    SET @nov = @@ROWCOUNT;

    TRUNCATE TABLE dbo.stg_th_timbradas;
    INSERT INTO dbo.stg_th_timbradas
    SELECT * FROM OPENQUERY([ONLYC], 'SELECT * FROM TCONTROL.dbo.vw_th_timbradas');
    SET @tim = @@ROWCOUNT;

    COMMIT;

    /* PRINT solo admite expresiones escalares: una subconsulta ahi da
       "No se permiten subconsultas en este contexto". Por eso los conteos
       salen de @@ROWCOUNT, que ademas evita recorrer las tablas otra vez. */
    PRINT 'Nomina    : ' + CAST(@nom AS VARCHAR(20)) + ' pares persona-periodo';
    PRINT 'Novedades : ' + CAST(@nov AS VARCHAR(20));
    PRINT 'Timbradas : ' + CAST(@tim AS VARCHAR(20));
    PRINT 'Segundos  : ' + CAST(DATEDIFF(SECOND, @ini, GETDATE()) AS VARCHAR(20));
END;


/* ===========================================================================
   3 · LAS VISTAS DE DETALLE, ya sobre la foto local
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_novedades', 'V') IS NOT NULL DROP VIEW dbo.vw_th_novedades;
CREATE VIEW dbo.vw_th_novedades AS
SELECT * FROM dbo.stg_th_novedades;

IF OBJECT_ID('dbo.vw_th_timbradas', 'V') IS NOT NULL DROP VIEW dbo.vw_th_timbradas;
CREATE VIEW dbo.vw_th_timbradas AS
SELECT * FROM dbo.stg_th_timbradas;

/* Catalogo y modalidades siguen en vivo: son chicos y deben reflejar de
   inmediato lo que Talento Humano cambie en Time Control. */
IF OBJECT_ID('dbo.vw_th_catalogo_novedad', 'V') IS NOT NULL DROP VIEW dbo.vw_th_catalogo_novedad;
CREATE VIEW dbo.vw_th_catalogo_novedad AS
SELECT * FROM [ONLYC].TCONTROL.dbo.vw_th_catalogo_novedad;

IF OBJECT_ID('dbo.vw_th_jornada_modalidad', 'V') IS NOT NULL DROP VIEW dbo.vw_th_jornada_modalidad;
CREATE VIEW dbo.vw_th_jornada_modalidad AS
SELECT * FROM [ONLYC].TCONTROL.dbo.vw_th_jornada_modalidad;


/* ===========================================================================
   4 · LA TABLA DE HECHOS PARA POWER BI
   ---------------------------------------------------------------------------
   Una fila por EMPLEADO y DIA. Reemplaza a fact_ausentismo.
   El cruce se hace AQUI, contra tablas locales con indices, no contra el
   servidor biometrico.

   Horas_Perdidas se resuelve una sola vez, en este orden:
     1. Si hay novedad que cubre el dia -> las horas de esa novedad
        (las de dia completo se prorratean entre sus dias programados;
         las de rango horario caen enteras en su dia de inicio)
     2. Si no hay novedad y el dia quedo incumplido -> Horas_No_Trabajadas
     3. En cualquier otro caso -> 0
   =========================================================================== */
IF OBJECT_ID('dbo.vw_th_ausentismo', 'V') IS NOT NULL DROP VIEW dbo.vw_th_ausentismo;
CREATE VIEW dbo.vw_th_ausentismo AS
WITH Nums AS (
    SELECT TOP 400 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i FROM sys.all_objects
),
NovDia AS (
    SELECT
        N.Codigo, N.Cedula,
        CAST(CONVERT(VARCHAR(10), DATEADD(DAY, nm.i, N.Fecha_Inicio), 112) AS DATETIME) AS Fecha,
        N.Nombre_Completo, N.Sucursal, N.Area, N.Departamento, N.Cargo,
        N.Ciudad_Sede, N.Activo_Hoy,
        N.Categoria_Id, N.Codigo_Novedad, N.Novedad, N.Es_Pagado, N.Es_Ausentismo,
        N.Clasificacion,
        CASE WHEN N.Forma_Registro = 'Por horas'
             THEN CASE WHEN nm.i = 0 THEN N.Horas_Novedad ELSE 0 END
             ELSE CAST(N.Horas_Novedad / NULLIF(N.Dias_Programados, 0) AS DECIMAL(9,2))
        END AS Horas_Dia
    FROM dbo.stg_th_novedades N
    /* alias nm, no n: en collation insensible a mayusculas chocaria con N */
    JOIN Nums nm ON nm.i <= DATEDIFF(DAY, N.Fecha_Inicio, N.Fecha_Fin)
),
/* Un dia puede tener dos novedades. Se queda UNA, la no pagada primero, para
   que el ausentismo no se disimule detras de un permiso pagado. Quedarse con
   una es lo que hace imposible el doble conteo. */
NovUno AS (
    SELECT D.*,
           ROW_NUMBER() OVER (PARTITION BY D.Codigo, D.Fecha
                              ORDER BY D.Es_Ausentismo DESC, D.Horas_Dia DESC) AS rn
    FROM NovDia D
)
SELECT
    CAST(COALESCE(T.Codigo, V.Codigo) AS VARCHAR(50))             AS Codigo,
    CAST(COALESCE(T.Cedula, V.Cedula) AS VARCHAR(30))             AS Cedula,
    CAST(COALESCE(T.Nombre_Completo, V.Nombre_Completo) AS VARCHAR(255)) AS Nombre_Completo,
    CAST(COALESCE(T.Sucursal    , V.Sucursal    ) AS VARCHAR(150)) AS Sucursal,
    CAST(COALESCE(T.Area        , V.Area        ) AS VARCHAR(150)) AS Area,
    CAST(COALESCE(T.Departamento, V.Departamento) AS VARCHAR(150)) AS Departamento,
    CAST(COALESCE(T.Cargo       , V.Cargo       ) AS VARCHAR(150)) AS Cargo,
    CAST(COALESCE(T.Ciudad_Sede , V.Ciudad_Sede ) AS VARCHAR(10))  AS Ciudad_Sede,
    CAST(COALESCE(T.Activo_Hoy  , V.Activo_Hoy  ) AS BIT)          AS Activo_Hoy,

    /* Si esa persona cobro rol en ESE periodo de nomina. Ninguna fila se
       borra: se etiqueta. Es la misma poblacion del denominador, periodo por
       periodo: quien no esta entre los colaboradores de nomina de un periodo
       no aporta D-H, asi que tampoco puede aportar horas perdidas.

       Cubre los dos casos que inflaban el indice:
         * candidatos enrolados en el biometrico antes de entrar, a los que el
           horario les genera una falta diaria (RRHH: "no son activos ni
           pasivos, son por entrar");
         * gente que se fue y nadie desactivo en OnlyControl.

       PN.Ini es el dia 21 en que inicia el periodo; su ano-mes es el mismo
       'Periodo Nomina ID' del Calendario Nomina. */
    CAST(CASE WHEN EXISTS (
                   SELECT 1 FROM dbo.stg_th_nomina NM
                   WHERE NM.Cedula     = COALESCE(T.Cedula, V.Cedula)
                     AND NM.Periodo_ID = YEAR(PN.Ini) * 100 + MONTH(PN.Ini))
              THEN 1 ELSE 0 END AS BIT)                            AS En_Nomina,

    F.Fecha,
    CAST(CASE DATEDIFF(DAY,'19000101',F.Fecha) % 7
              WHEN 0 THEN 'Lunes'  WHEN 1 THEN 'Martes'  WHEN 2 THEN 'Miercoles'
              WHEN 3 THEN 'Jueves' WHEN 4 THEN 'Viernes' WHEN 5 THEN 'Sabado'
              ELSE 'Domingo' END AS VARCHAR(10))                  AS Dia,
    CAST(YEAR(F.Fecha)  AS SMALLINT)                              AS Anio,
    CAST(MONTH(F.Fecha) AS TINYINT)                               AS Mes,
    CAST(CONVERT(VARCHAR(10), PN.Ini, 105) + ' al '
       + CONVERT(VARCHAR(10), DATEADD(DAY,-1,DATEADD(MONTH,1,PN.Ini)), 105)
         AS VARCHAR(40))                                          AS Periodo_Nomina,
    CAST(PN.Ini AS DATETIME)                                      AS Periodo_Inicio,
    CAST(DATEADD(DAY, -(DATEDIFF(DAY,'19000101',F.Fecha) % 7), F.Fecha) AS DATETIME) AS Semana_Inicio,

    CAST(ISNULL(T.Modalidad   ,'Sin marcacion') AS VARCHAR(255))  AS Modalidad,
    CAST(ISNULL(T.Horario     ,'Sin marcacion') AS VARCHAR(120))  AS Horario,
    CAST(ISNULL(T.Tipo_Jornada,'Sin marcacion') AS VARCHAR(20))   AS Tipo_Jornada,
    CAST(ISNULL(T.Grupo       ,'Sin grupo'    ) AS VARCHAR(20))   AS Grupo,
    CAST(ISNULL(T.Dia_Programado,0) AS BIT)                       AS Dia_Programado,
    CAST(ISNULL(T.Es_Feriado    ,0) AS BIT)                       AS Es_Feriado,
    CAST(T.Horas_Programadas AS DECIMAL(6,2))                     AS Horas_Programadas,
    CAST(T.Horas_Marcadas    AS DECIMAL(6,2))                     AS Horas_Marcadas,
    T.Entrada_Programada, T.Salida_Programada,
    T.Entrada_Real, T.Salida_Real,
    CAST(ISNULL(T.Minutos_Atraso,0) AS INT)                       AS Minutos_Atraso,

    /* De donde salio la fila. Sirve para auditar sin adivinar. */
    CAST(CASE WHEN T.Codigo IS NOT NULL AND V.Codigo IS NOT NULL THEN 'Marcacion y novedad'
              WHEN T.Codigo IS NOT NULL                          THEN 'Solo marcacion'
              ELSE 'Solo novedad' END AS VARCHAR(20))             AS Origen_Fila,

    CAST(V.Codigo_Novedad AS VARCHAR(2))                          AS Codigo_Novedad,
    CAST(V.Novedad        AS VARCHAR(30))                         AS Novedad,
    CAST(V.Categoria_Id   AS INT)                                 AS Categoria_Id,
    CAST(V.Es_Pagado      AS BIT)                                 AS Es_Pagado,

    CAST(ISNULL(T.Estado_Dia,
         CASE WHEN V.Codigo_Novedad IS NOT NULL THEN 'Cubierto por novedad'
              ELSE 'Sin registro' END) AS VARCHAR(32))            AS Estado_Dia,

    /* La novedad manda: si el dia esta amparado, se clasifica por ella.
       Si no, por el estado de la marcacion. */
    CAST(CASE WHEN V.Codigo_Novedad IS NOT NULL THEN V.Es_Ausentismo
              ELSE ISNULL(T.Es_Ausentismo, 0) END AS BIT)         AS Es_Ausentismo,
    CAST(CASE WHEN V.Codigo_Novedad IS NOT NULL THEN V.Clasificacion
              WHEN ISNULL(T.Es_Ausentismo,0) = 1 THEN 'Ausentismo - sin respaldo'
              WHEN ISNULL(T.Es_Justificado,0) = 1 THEN 'Justificado - marcacion'
              ELSE 'Sin novedad' END AS VARCHAR(26))              AS Clasificacion,

    /* UN solo numero de horas por persona y dia: las de la novedad si el dia
       esta amparado, o las no trabajadas si no. Son horas PERDIDAS, pagadas o
       no. Para el indicador de ausentismo hay que filtrar Es_Ausentismo = 1;
       sin filtrar, esto mide horas-hombre perdidas. */
    CAST(CASE WHEN V.Codigo_Novedad IS NOT NULL THEN ISNULL(V.Horas_Dia, 0)
              ELSE ISNULL(T.Horas_No_Trabajadas, 0) END AS DECIMAL(9,2)) AS Horas_Perdidas

FROM dbo.stg_th_timbradas T
FULL OUTER JOIN (SELECT * FROM NovUno WHERE rn = 1) V
       ON V.Codigo = T.Codigo AND V.Fecha = T.Fecha
CROSS APPLY (SELECT COALESCE(T.Fecha, V.Fecha) AS Fecha) AS F
CROSS APPLY (
    SELECT DATEADD(DAY, 20, DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(DAY,-20,F.Fecha)), 0)) AS Ini
) AS PN;


/* ===========================================================================
   5 · CONTROLES
   =========================================================================== */

-- C0 · Primera carga. Debe imprimir ~23.500 novedades y ~734.000 timbradas.
/*
EXEC dbo.sp_th_cargar_ausentismo;
*/

-- C1 · Tamano y velocidad del fact.
/*
SET STATISTICS TIME ON;
SELECT COUNT(*) AS filas FROM dbo.vw_th_ausentismo;
SET STATISTICS TIME OFF;
*/

-- C2 · Codigos en uso con su flag de pagado y la clasificacion resultante.
--      Ojo: el codigo solo es unico dentro de su categoria. PE es CITA MEDICA
--      en la 13 y PERMISO SALIDA en la 2, por eso se agrupa por las dos.
/*
SELECT Categoria_Id, Codigo_Novedad, Novedad, Es_Pagado, Clasificacion,
       COUNT(*) AS dias, SUM(Horas_Perdidas) AS horas
FROM dbo.vw_th_ausentismo
WHERE Codigo_Novedad IS NOT NULL
GROUP BY Categoria_Id, Codigo_Novedad, Novedad, Es_Pagado, Clasificacion
ORDER BY horas DESC;
*/

-- C3 · Horarios mal configurados. Corregir en Time Control, no aqui.
--      Solo 36 de los 75 salen 'Coherente'.
/*
SELECT Config_Horario, Horario, Hora_Entrada, Hora_Salida,
       Controla_Lunch, Modo_Lunch, Lunch_Minutos, Horas_Jornada, Horas_Ordinarias
FROM dbo.vw_th_jornada_modalidad
WHERE Config_Horario <> 'Coherente' AND Horario IS NOT NULL
GROUP BY Config_Horario, Horario, Hora_Entrada, Hora_Salida,
         Controla_Lunch, Modo_Lunch, Lunch_Minutos, Horas_Jornada, Horas_Ordinarias
ORDER BY Config_Horario;
*/

-- C4 · El indicador por area y clasificacion. Este es el reporte.
/*
SELECT Area, Clasificacion, COUNT(*) AS dias, SUM(Horas_Perdidas) AS horas
FROM dbo.vw_th_ausentismo
WHERE Fecha >= '2026-08-01' AND Fecha < '2026-09-01' AND Ciudad_Sede = 'UIO'
GROUP BY Area, Clasificacion
HAVING SUM(Horas_Perdidas) > 0
ORDER BY horas DESC;
*/

-- C5 · Cumplimiento semanal por persona.
/*
SELECT Cedula, Nombre_Completo, Modalidad, Tipo_Jornada,
       Semana_Inicio, Dias_Programados_Semana,
       Horas_Programadas_Semana, Horas_Marcadas_Semana,
       Saldo_Horas_Semana, Cumplimiento_Semana
FROM dbo.vw_th_timbradas
WHERE Semana_Inicio = '2026-08-17'
GROUP BY Cedula, Nombre_Completo, Modalidad, Tipo_Jornada, Semana_Inicio,
         Dias_Programados_Semana, Horas_Programadas_Semana,
         Horas_Marcadas_Semana, Saldo_Horas_Semana, Cumplimiento_Semana
ORDER BY Saldo_Horas_Semana;
*/

-- C6 · Faltas sin respaldo, dia por dia. Lo que Talento Humano reclama.
/*
SELECT Cedula, Nombre_Completo, Area, Modalidad, Tipo_Jornada,
       Fecha, Dia, Horas_Programadas, Estado_Dia, Horas_Perdidas
FROM dbo.vw_th_ausentismo
WHERE Clasificacion = 'Ausentismo - sin respaldo'
  AND Fecha >= '2026-08-01' AND Fecha < '2026-09-01'
ORDER BY Area, Nombre_Completo, Fecha;
*/

-- C7 · Quien marca en el biometrico sin estar en nomina ese periodo. No da
--      cero: es la lista de lo que el indicador deja fuera, para auditarla.
--      periodos_con_rol = 0: nunca cobro (candidato, o cedula mal escrita en
--      OnlyControl). Mayor que 0: dias antes de entrar o despues de irse.
/*
SELECT A.Cedula, MIN(A.Nombre_Completo) AS Nombre, MIN(A.Area) AS Area,
       COUNT(*) AS dias, SUM(A.Horas_Perdidas) AS horas,
       MIN(A.Fecha) AS primera, MAX(A.Fecha) AS ultima,
       (SELECT COUNT(*) FROM dbo.stg_th_nomina NM
         WHERE NM.Cedula = A.Cedula) AS periodos_con_rol
FROM dbo.vw_th_ausentismo A
WHERE A.En_Nomina = 0
GROUP BY A.Cedula
ORDER BY horas DESC;
*/

-- C9 · Que trajo la carga de nomina, periodo por periodo. Cada fila tiene que
--      coincidir con la medida de headcount de Power BI en ese periodo:
--      202607 (21-jul al 20-ago 2026) = 347.
/*
SELECT Periodo_ID, COUNT(*) AS colaboradores
FROM dbo.stg_th_nomina
WHERE Periodo_ID >= 202601
GROUP BY Periodo_ID
ORDER BY Periodo_ID;
*/

-- C10 · A quien desactivar HOY en OnlyControl: tiene dias generados en el
--       ultimo periodo cargado sin estar en nomina. Correrla en cada cierre;
--       es la que evita que se repita lo de GYE 2023-2025. Codigo es el
--       NOMINA_ID de OnlyControl.
/*
DECLARE @ult DATETIME = (SELECT MAX(Fecha) FROM dbo.stg_th_timbradas);
DECLARE @ini DATETIME = DATEADD(DAY, 20, DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(DAY, -20, @ult)), 0));
SELECT A.Codigo, A.Cedula, MIN(A.Nombre_Completo) AS Nombre, MIN(A.Area) AS Area,
       COUNT(*) AS dias, SUM(A.Horas_Perdidas) AS horas
FROM dbo.vw_th_ausentismo A
WHERE A.En_Nomina = 0
  AND A.Origen_Fila <> 'Solo novedad'
  AND A.Fecha BETWEEN @ini AND @ult
GROUP BY A.Codigo, A.Cedula
ORDER BY horas DESC;
*/

-- C8 · Cuanto pesan esos fantasmas en el periodo. Replica el numerador de la
--      medida Total H-h de Power BI, partido en dos poblaciones.
/*
SELECT CASE WHEN En_Nomina = 1 THEN 'En nomina' ELSE 'Fuera de nomina' END AS Poblacion,
       COUNT(*) AS dias, SUM(Horas_Perdidas) AS h_h
FROM dbo.vw_th_ausentismo
WHERE Fecha >= '2026-07-21' AND Fecha <= '2026-08-20'
  AND ( (Categoria_Id = 13 AND Codigo_Novedad IN ('LE','LM','PP','CD','SP','PE'))
     OR (Codigo_Novedad IS NULL AND Estado_Dia IN
         ('Falta injustificada','Atraso injustificado','Atraso y salida anticipada','No firmo')) )
GROUP BY En_Nomina;
*/
