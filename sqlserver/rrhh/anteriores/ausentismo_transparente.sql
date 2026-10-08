/* ============================================================================
   AUSENTISMO TRANSPARENTE  ·  TH  (SRV-APP\SQLEXPRESS, 192.168.20.15)
   ----------------------------------------------------------------------------
   Reemplaza las condiciones hardcodeadas de vw_ausentismo / vm_atrasos por
   TABLAS DE PARAMETROS + REPLICA REAL. Toda regla de negocio pasa a ser una
   fila que Talento Humano puede leer, auditar y cambiar sin tocar SQL.

   DOS PROBLEMAS DE FONDO QUE RESUELVE
   ------------------------------------
   A) TH NO ES UNA REPLICA. Hoy tiene 0 tablas y 25 vistas que consultan
      SRV-BIOM-001 en vivo por linked server [ONLYC]. Consecuencias medidas:
        - Un GROUP BY sobre fact_ausentismo tarda 28-37 s y a veces expira.
        - No hay foto historica: si TH edita una marcacion de hace 6 meses,
          los reportes ya publicados cambian solos.
      Este script crea tablas stg_* reales y las carga con sp_th_cargar_replica.
      A partir de ahi TH SI es replica y las vistas leen local.

   B) LAS REGLAS ESTAN ESCONDIDAS EN CASE/LIKE. Verificado sobre datos 2025:
      1. Mapeo de dias corrido. Las vistas leen M_6 como Sabado y M_7 como
         Domingo. El real es M_1=Dom, M_2=Lun, M_3=Mar, M_4=Mie, M_5=Jue,
         M_6=Vie, M_7=Sab.
         Prueba: VENDEDORES-LUNES solo tiene M_2 y marca solo lunes (64/64).
         Efecto: toda modalidad Lun-Vie aparece como "Lun - Sab" en el tablero.
      2. FI (falta injustificada) valia 0 h en dia laborable:
         488 faltas Lun-Vie en 2025 = 3.904 h que nunca se contaron.
      3. FI si cobraba fin de semana, por el mismo corrimiento:
         960 h de sabado y 560 h de domingo eran falsos positivos.
      4. Filtros por nombre de modalidad ('ADMINISTRATIVO HE%' y la cadena
         literal 'PLANTA 06 A 18:') borraban 3.968 filas de 2025 en silencio.
      5. Las dos ramas del UNION usaban reglas DISTINTAS para lo mismo:
         ADMINISTRATIVA HE salia "Lun - Vie / sab=0" en atrasos y
         "Lun - Dom / sab=1" en permisos. Misma persona, mismo dia.
      6. TBL_FESTIVOS existe y esta al dia hasta ago-2026, pero ninguna vista
         la usaba: 536 h de feriado contadas como ausencia en 2025.
      7. ELSE UPPER(LEFT(CD_NOM,2)): un tipo de permiso nuevo entraba al
         reporte con un codigo inventado de 2 letras, sin que nadie se entere.
      8. VIEWEMPLEADOS filtra WHERE NOMINA_ES <> 0, es decir aplica el estado
         de HOY a datos historicos. 909 empleados estan en NOMINA_ES=0, y con
         eso 411 permisos de 2025 (16 %) de 63 personas ya desaparecieron del
         reporte. El 2025 que se corre hoy NO es el 2025 que se corrio en 2025.
         Esta es la razon estructural por la que el Excel, que es una foto
         congelada, nunca va a cuadrar, y la brecha crece cada mes.

   SUPUESTOS DECLARADOS (todos editables en param_regla_ausentismo)
   ----------------------------------------------------------------
     - Un dia completo de ausencia vale 8 h, como el Excel historico de TH,
       no las horas del turno.
     - FI en dia programado = 8 h. FI en dia NO programado no es ausencia.
     - NC (no cumple horario) NO entra al I/A oficial: el Excel no lo tiene.
     - Los feriados no cuentan como dias de ausencia.
     - Reposo medico y calamidad: hoy el codigo cuenta dias calendario y el
       Excel cuenta dias habiles. Queda explicito en param_tipo_permiso
       (Resta_Fin_Semana) para que TH decida. Es el origen de RM 1.144 vs 880.

   ORDEN DE EJECUCION
   ------------------
     Paso 1..4  crean estructura (una sola vez)
     Paso 5     EXEC dbo.sp_th_cargar_replica   -> agendar cada noche
     Paso 6..8  crean las vistas v2
     Paso 9     consultas de control y comparacion contra las vistas actuales
   ============================================================================ */

USE TH;
GO

/* ===========================================================================
   PASO 1 · PARAMETROS ESCALARES
   =========================================================================== */
IF OBJECT_ID('dbo.param_regla_ausentismo') IS NULL
BEGIN
    CREATE TABLE dbo.param_regla_ausentismo (
        Regla        VARCHAR(60)  NOT NULL PRIMARY KEY,
        Valor        DECIMAL(9,2) NOT NULL,
        Descripcion  VARCHAR(400) NOT NULL,
        Modificado   DATETIME     NOT NULL CONSTRAINT DF_param_regla_mod DEFAULT GETDATE()
    );

    INSERT INTO dbo.param_regla_ausentismo (Regla, Valor, Descripcion) VALUES
     ('HORAS_DIA_COMPLETO', 8.00,
      'Horas que vale un dia completo de ausencia. El Excel de TH usa 8 fijo. Poner 0 para usar las horas reales del turno.'),
     ('UMBRAL_ATRASO_MIN' ,15.00,
      'Minutos de atraso desde los cuales se registra atraso (A).'),
     ('FI_HORAS_DIA'      , 8.00,
      'Horas asignadas a una falta injustificada en dia programado.'),
     ('RESTAR_FERIADOS'   , 1.00,
      '1 = los feriados de TBL_FESTIVOS no cuentan como dias de ausencia.'),
     ('ANIO_DESDE'        , 2018.00,
      'Primer anio incluido en el fact.'),
     ('DIA_CORTE_NOMINA'  , 21.00,
      'Dia en que arranca el periodo de nomina. 21 = del 21 al 20.');
END
GO

/* ===========================================================================
   PASO 2 · JORNADA POR MODALIDAD   (reemplaza TODOS los LIKE de nombre)
   ---------------------------------------------------------------------------
   Src_* : mapeo REAL leido de TBL_MODALIDAD (M_1=Dom ... M_7=Sab)
   Ovr_* : correccion manual de TH. NULL = usar el origen.
   Asi TH arregla una modalidad puntual sin que nadie edite una vista.
   =========================================================================== */
IF OBJECT_ID('dbo.param_modalidad_jornada') IS NULL
BEGIN
    CREATE TABLE dbo.param_modalidad_jornada (
        M_ID        INT          NOT NULL PRIMARY KEY,
        M_DES       VARCHAR(255) NULL,
        Src_Lun BIT NULL, Src_Mar BIT NULL, Src_Mie BIT NULL, Src_Jue BIT NULL,
        Src_Vie BIT NULL, Src_Sab BIT NULL, Src_Dom BIT NULL,
        Ovr_Lun BIT NULL, Ovr_Mar BIT NULL, Ovr_Mie BIT NULL, Ovr_Jue BIT NULL,
        Ovr_Vie BIT NULL, Ovr_Sab BIT NULL, Ovr_Dom BIT NULL,
        Es_Rotativo BIT          NOT NULL CONSTRAINT DF_param_mod_rot DEFAULT 0,
        Nota        VARCHAR(400) NULL,
        Actualizado DATETIME     NOT NULL CONSTRAINT DF_param_mod_act DEFAULT GETDATE()
    );
END
GO

/* Vista resuelta: override si existe, si no el origen.
   Modalidad con los 7 flags en 0 = rotativa: puede caer cualquier dia. */
CREATE OR ALTER VIEW dbo.vw_param_jornada AS
SELECT
    M_ID, M_DES, Es_Rotativo,
    CAST(CASE WHEN Es_Rotativo=1 THEN 1 ELSE ISNULL(Ovr_Lun, ISNULL(Src_Lun,0)) END AS BIT) AS Lun,
    CAST(CASE WHEN Es_Rotativo=1 THEN 1 ELSE ISNULL(Ovr_Mar, ISNULL(Src_Mar,0)) END AS BIT) AS Mar,
    CAST(CASE WHEN Es_Rotativo=1 THEN 1 ELSE ISNULL(Ovr_Mie, ISNULL(Src_Mie,0)) END AS BIT) AS Mie,
    CAST(CASE WHEN Es_Rotativo=1 THEN 1 ELSE ISNULL(Ovr_Jue, ISNULL(Src_Jue,0)) END AS BIT) AS Jue,
    CAST(CASE WHEN Es_Rotativo=1 THEN 1 ELSE ISNULL(Ovr_Vie, ISNULL(Src_Vie,0)) END AS BIT) AS Vie,
    CAST(CASE WHEN Es_Rotativo=1 THEN 1 ELSE ISNULL(Ovr_Sab, ISNULL(Src_Sab,0)) END AS BIT) AS Sab,
    CAST(CASE WHEN Es_Rotativo=1 THEN 1 ELSE ISNULL(Ovr_Dom, ISNULL(Src_Dom,0)) END AS BIT) AS Dom,
    CAST(CASE
        WHEN Es_Rotativo = 1 THEN 'Rotativo'
        WHEN ISNULL(Ovr_Sab,ISNULL(Src_Sab,0))=0 AND ISNULL(Ovr_Dom,ISNULL(Src_Dom,0))=0 THEN 'Lun - Vie'
        WHEN ISNULL(Ovr_Sab,ISNULL(Src_Sab,0))=1 AND ISNULL(Ovr_Dom,ISNULL(Src_Dom,0))=0 THEN 'Lun - Sab'
        ELSE 'Lun - Dom'
    END AS VARCHAR(20)) AS Descripcion_Jornada
FROM dbo.param_modalidad_jornada;
GO

/* ===========================================================================
   PASO 3 · CATALOGO DE TIPOS  (reemplaza la cascada de LIKE y mata el ELSE)
   =========================================================================== */
IF OBJECT_ID('dbo.param_tipo_permiso') IS NULL
BEGIN
    CREATE TABLE dbo.param_tipo_permiso (
        CD_CAT              INT          NOT NULL,
        CD_ID               INT          NOT NULL,
        CD_NOM              VARCHAR(255) NOT NULL,
        Codigo_Reporte      VARCHAR(10)  NOT NULL,
        Descripcion_Reporte VARCHAR(100) NOT NULL,
        Cuenta_En_IA        BIT NOT NULL CONSTRAINT DF_ptp_ia   DEFAULT 1,
        Resta_Fin_Semana    BIT NOT NULL CONSTRAINT DF_ptp_fs   DEFAULT 1,
        Resta_Feriados      BIT NOT NULL CONSTRAINT DF_ptp_fer  DEFAULT 1,
        Activo              BIT NOT NULL CONSTRAINT DF_ptp_act  DEFAULT 1,
        Nota                VARCHAR(400) NULL,
        CONSTRAINT PK_param_tipo_permiso PRIMARY KEY (CD_CAT, CD_ID)
    );
END
GO

/* Semaforo. Si devuelve filas, hay reglas sin definir: NO publicar el tablero. */
CREATE OR ALTER VIEW dbo.vw_control_parametros AS
SELECT 'Tipo de permiso sin clasificar' AS Alerta,
       CAST(CD_ID AS VARCHAR(20)) AS Id, CD_NOM AS Nombre
FROM dbo.param_tipo_permiso
WHERE Codigo_Reporte = 'SIN_MAPEAR' AND Activo = 1
UNION ALL
SELECT 'Modalidad sin ningun dia laborable definido',
       CAST(M_ID AS VARCHAR(20)), M_DES
FROM dbo.param_modalidad_jornada
WHERE Es_Rotativo = 0
  AND ISNULL(Ovr_Lun,ISNULL(Src_Lun,0)) = 0 AND ISNULL(Ovr_Mar,ISNULL(Src_Mar,0)) = 0
  AND ISNULL(Ovr_Mie,ISNULL(Src_Mie,0)) = 0 AND ISNULL(Ovr_Jue,ISNULL(Src_Jue,0)) = 0
  AND ISNULL(Ovr_Vie,ISNULL(Src_Vie,0)) = 0;
GO

/* ===========================================================================
   PASO 4 · REPLICA LOCAL + CALENDARIO
   ---------------------------------------------------------------------------
   Esto es lo que convierte a TH en replica de verdad y lo que hace que las
   consultas bajen de ~30 s a milisegundos.
   =========================================================================== */
IF OBJECT_ID('dbo.stg_modalidad')  IS NULL
    CREATE TABLE dbo.stg_modalidad (
        M_ID INT NOT NULL PRIMARY KEY, M_DES VARCHAR(255) NULL,
        M_1 BIT, M_2 BIT, M_3 BIT, M_4 BIT, M_5 BIT, M_6 BIT, M_7 BIT);

IF OBJECT_ID('dbo.stg_empleado')   IS NULL
    CREATE TABLE dbo.stg_empleado (
        NOMINA_ID INT NOT NULL PRIMARY KEY, NOMINA_COD VARCHAR(30) NULL,
        NOMINA_APE VARCHAR(120) NULL, NOMINA_NOM VARCHAR(120) NULL,
        EMPE_NOM VARCHAR(150) NULL, AREA_NOM VARCHAR(150) NULL,
        DEP_NOM VARCHAR(150) NULL, NOMINA_CAL1 VARCHAR(150) NULL,
        NOMINA_EMP VARCHAR(10) NULL,
        NOMINA_ES  INT NULL,          -- estado actual: 0 = fuera de VIEWEMPLEADOS
        Activo_Hoy BIT NULL);

IF OBJECT_ID('dbo.stg_asistencia') IS NULL
BEGIN
    CREATE TABLE dbo.stg_asistencia (
        EMP_ID INT NOT NULL, FECHA_INGRESO DATE NOT NULL,
        Hora_Ingreso DATETIME NULL, Hora_Salida DATETIME NULL,
        HORARIO_INGRESO DATETIME NULL, HORARIO_SALIDA DATETIME NULL,
        NOVEDAD_ENTRADA VARCHAR(10) NULL, NOVEDAD_SALIDA VARCHAR(10) NULL,
        MIN_AT INT NULL, MIN_SA INT NULL, modalidad INT NULL,
        CONSTRAINT PK_stg_asistencia PRIMARY KEY (EMP_ID, FECHA_INGRESO));
    CREATE INDEX IX_stg_asistencia_fecha ON dbo.stg_asistencia (FECHA_INGRESO) INCLUDE (EMP_ID, modalidad);
END

IF OBJECT_ID('dbo.stg_perm_aus')   IS NULL
BEGIN
    CREATE TABLE dbo.stg_perm_aus (
        E_EMPID INT NOT NULL, E_TIPOM INT NOT NULL, E_TIPOP INT NOT NULL,
        E_FINICIO DATE NOT NULL, E_FFINAL DATE NULL,
        E_HoraI DATETIME NULL, E_HoraF DATETIME NULL);
    CREATE INDEX IX_stg_perm_aus ON dbo.stg_perm_aus (E_FINICIO) INCLUDE (E_EMPID, E_TIPOM, E_TIPOP);
END

IF OBJECT_ID('dbo.stg_festivo')    IS NULL
    CREATE TABLE dbo.stg_festivo (D_FESTIVO DATE NOT NULL PRIMARY KEY, D_DESC VARCHAR(200) NULL);

/* Calendario: una fila por dia. Es lo que permite contar dias programados
   con un JOIN en vez de aritmetica DATEDIFF/7 imposible de auditar. */
IF OBJECT_ID('dbo.dim_calendario') IS NULL
BEGIN
    CREATE TABLE dbo.dim_calendario (
        Fecha    DATE NOT NULL PRIMARY KEY,
        DiaIdx   TINYINT NOT NULL,           -- 0=Lun 1=Mar 2=Mie 3=Jue 4=Vie 5=Sab 6=Dom
        Anio     SMALLINT NOT NULL,
        Mes      TINYINT NOT NULL);

    ;WITH N(x) AS (SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
                   UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
                   UNION ALL SELECT 1 UNION ALL SELECT 1),
     Nums AS (SELECT TOP (12000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
              FROM N a, N b, N c, N d)
    INSERT INTO dbo.dim_calendario (Fecha, DiaIdx, Anio, Mes)
    SELECT  DATEADD(DAY, i, '2015-01-01'),
            DATEDIFF(DAY, '19000101', DATEADD(DAY, i, '2015-01-01')) % 7,
            YEAR (DATEADD(DAY, i, '2015-01-01')),
            MONTH(DATEADD(DAY, i, '2015-01-01'))
    FROM Nums;
END
GO

/* Etiqueta de periodo de nomina 21->20, en un solo lugar.
   Antes estaba duplicada, con la misma expresion copiada en las dos vistas. */
CREATE OR ALTER FUNCTION dbo.fn_periodo_nomina (@Fecha DATE)
RETURNS VARCHAR(40)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @ini DATE =
        CASE WHEN DAY(@Fecha) >= 21
             THEN DATEFROMPARTS(YEAR(@Fecha), MONTH(@Fecha), 21)
             ELSE DATEFROMPARTS(YEAR(DATEADD(MONTH,-1,@Fecha)), MONTH(DATEADD(MONTH,-1,@Fecha)), 21)
        END;
    RETURN CONVERT(VARCHAR(10), @ini, 105) + ' al '
         + CONVERT(VARCHAR(10), DATEADD(DAY, -1, DATEADD(MONTH, 1, @ini)), 105);
END
GO

/* ===========================================================================
   PASO 5 · CARGA DE LA REPLICA   ·  agendar en SQL Agent, 1 vez por noche
   =========================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_th_cargar_replica
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    DELETE FROM dbo.stg_modalidad;
    INSERT INTO dbo.stg_modalidad (M_ID,M_DES,M_1,M_2,M_3,M_4,M_5,M_6,M_7)
    SELECT M_ID,M_DES,M_1,M_2,M_3,M_4,M_5,M_6,M_7
    FROM [ONLYC].TCONTROL.DBO.TBL_MODALIDAD;

    /* IMPORTANTE: NO se carga desde VIEWEMPLEADOS.
       Esa vista trae WHERE NOMINA_ES <> 0, o sea filtra por el estado de HOY
       y lo aplica a datos historicos: cuando alguien sale de la empresa sus
       ausencias pasadas desaparecen del reporte de forma retroactiva.
       Medido: 909 empleados con NOMINA_ES=0; 411 permisos de 2025 (16 %) de
       63 personas ya no aparecen. Por eso el 2025 que se corre hoy no es el
       mismo 2025 que se corrio en 2025, y nunca va a cuadrar con el Excel.
       Aqui se carga la nomina COMPLETA y el estado queda como atributo. */
    DELETE FROM dbo.stg_empleado;
    INSERT INTO dbo.stg_empleado
        (NOMINA_ID,NOMINA_COD,NOMINA_APE,NOMINA_NOM,EMPE_NOM,AREA_NOM,DEP_NOM,
         NOMINA_CAL1,NOMINA_EMP,NOMINA_ES,Activo_Hoy)
    SELECT N.NOMINA_ID, N.NOMINA_COD, N.NOMINA_APE, N.NOMINA_NOM,
           X.EMPE_NOM, A.AREA_NOM, D.DEP_NOM, N.NOMINA_CAL1, N.NOMINA_EMP,
           N.NOMINA_ES,
           CASE WHEN N.NOMINA_ES <> 0 THEN 1 ELSE 0 END
    FROM [ONLYC].ONLYCONTROL.dbo.NOMINA   N
    JOIN [ONLYC].ONLYCONTROL.dbo.EXTERNOE X ON N.NOMINA_EMP  = X.EMPE_ID
    JOIN [ONLYC].ONLYCONTROL.dbo.AREA     A ON N.NOMINA_AREA = A.AREA_ID
    JOIN [ONLYC].ONLYCONTROL.dbo.DPTO     D ON N.NOMINA_DEP  = D.DEP_ID;

    DELETE FROM dbo.stg_festivo;
    INSERT INTO dbo.stg_festivo (D_FESTIVO, D_DESC)
    SELECT DISTINCT CAST(D_FESTIVO AS DATE), MAX(D_DESC)
    FROM [ONLYC].TCONTROL.DBO.TBL_FESTIVOS
    GROUP BY CAST(D_FESTIVO AS DATE);

    DELETE FROM dbo.stg_asistencia;
    INSERT INTO dbo.stg_asistencia
    SELECT EMP_ID, CAST(FECHA_INGRESO AS DATE), Hora_Ingreso, Hora_Salida,
           HORARIO_INGRESO, HORARIO_SALIDA, NOVEDAD_ENTRADA, NOVEDAD_SALIDA,
           ISNULL(MIN_AT,0), ISNULL(MIN_SA,0), modalidad
    FROM [ONLYC].TCONTROL.DBO.TBL_ASISTENCIA
    WHERE FECHA_INGRESO >= '2018-01-01';

    DELETE FROM dbo.stg_perm_aus;
    INSERT INTO dbo.stg_perm_aus
    SELECT E_EMPID, E_TIPOM, E_TIPOP, CAST(E_FINICIO AS DATE),
           CAST(ISNULL(E_FFINAL,E_FINICIO) AS DATE), E_HoraI, E_HoraF
    FROM [ONLYC].TCONTROL.DBO.TBL_PERM_AUS
    WHERE E_FINICIO >= '2018-01-01';

    /* Refresco de parametros: agrega lo nuevo, NUNCA pisa un override de TH. */
    MERGE dbo.param_modalidad_jornada AS d
    USING (SELECT M_ID, M_DES,
                  M_2 AS Lun, M_3 AS Mar, M_4 AS Mie, M_5 AS Jue,
                  M_6 AS Vie, M_7 AS Sab, M_1 AS Dom,
                  CASE WHEN M_1=0 AND M_2=0 AND M_3=0 AND M_4=0
                            AND M_5=0 AND M_6=0 AND M_7=0 THEN 1 ELSE 0 END AS Rot
           FROM dbo.stg_modalidad) AS s
    ON s.M_ID = d.M_ID
    WHEN MATCHED THEN UPDATE SET
        d.M_DES=s.M_DES, d.Src_Lun=s.Lun, d.Src_Mar=s.Mar, d.Src_Mie=s.Mie,
        d.Src_Jue=s.Jue, d.Src_Vie=s.Vie, d.Src_Sab=s.Sab, d.Src_Dom=s.Dom,
        d.Es_Rotativo=s.Rot, d.Actualizado=GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (M_ID,M_DES,Src_Lun,Src_Mar,Src_Mie,Src_Jue,Src_Vie,Src_Sab,Src_Dom,Es_Rotativo)
        VALUES (s.M_ID,s.M_DES,s.Lun,s.Mar,s.Mie,s.Jue,s.Vie,s.Sab,s.Dom,s.Rot);

    MERGE dbo.param_tipo_permiso AS d
    USING (
        SELECT CD_CAT, CD_ID, CD_NOM,
          CASE WHEN CD_NOM LIKE '%SIN PAGA%'    THEN 'PP'
               WHEN CD_NOM LIKE '%PATERN%'      THEN 'LP'
               WHEN CD_NOM LIKE '%ENFERMEDAD%' OR CD_NOM LIKE '%REPOSO%'    THEN 'RM'
               WHEN CD_NOM LIKE '%MATERNA%'    OR CD_NOM LIKE '%LACTANCIA%' THEN 'LM'
               WHEN CD_NOM LIKE '%MEDICA%'      THEN 'CM'
               WHEN CD_NOM LIKE '%CALAMIDAD%'   THEN 'CD'
               WHEN CD_NOM LIKE '%INJUSTIFICA%' THEN 'FI'
               WHEN CD_NOM LIKE '%PERSONAL%'
                 OR CD_NOM IN ('PERMISO SALIDA','PERMISO ENTRADA') THEN 'PP'
               WHEN CD_NOM LIKE '%VACACIONES%'  THEN 'VAC'
               ELSE 'SIN_MAPEAR' END AS Cod,
          CASE WHEN CD_NOM LIKE '%VACACIONES%'     OR CD_NOM LIKE '%SABADO-DOMINGO%'
                 OR CD_NOM LIKE '%CON SUELDO%'     OR CD_NOM LIKE '%ERROR%'
                 OR CD_NOM LIKE '%CURSO%'          OR CD_NOM LIKE '%COMISION%'
               THEN 0 ELSE 1 END AS EnIA,
          CASE WHEN CD_NOM LIKE '%ENFERMEDAD%' OR CD_NOM LIKE '%REPOSO%'
                 OR CD_NOM LIKE '%CALAMIDAD%' THEN 0 ELSE 1 END AS RestaFS
        FROM [ONLYC].TCONTROL.DBO.TBL_CAT_DETALLE) AS s
    ON s.CD_CAT = d.CD_CAT AND s.CD_ID = d.CD_ID
    WHEN NOT MATCHED THEN
        INSERT (CD_CAT,CD_ID,CD_NOM,Codigo_Reporte,Descripcion_Reporte,Cuenta_En_IA,Resta_Fin_Semana,Nota)
        VALUES (s.CD_CAT, s.CD_ID, s.CD_NOM, s.Cod,
                CASE s.Cod WHEN 'PP'  THEN 'Permiso personal'
                           WHEN 'LP'  THEN 'Licencia paternidad'
                           WHEN 'RM'  THEN 'Reposo medico'
                           WHEN 'LM'  THEN 'Licencia maternidad'
                           WHEN 'CM'  THEN 'Citas medicas'
                           WHEN 'CD'  THEN 'Calamidad domestica'
                           WHEN 'FI'  THEN 'Falta Injustificada'
                           WHEN 'VAC' THEN 'Vacaciones'
                           ELSE 'SIN MAPEAR - revisar' END,
                s.EnIA, s.RestaFS,
                CASE WHEN s.Cod='SIN_MAPEAR'
                     THEN 'Alta automatica sin clasificar. TH debe definir el codigo.' END);

    COMMIT;

    /* Aviso operativo */
    IF EXISTS (SELECT 1 FROM dbo.vw_control_parametros)
        RAISERROR('Hay parametros sin definir. Revisar dbo.vw_control_parametros.', 10, 1) WITH NOWAIT;
END
GO

/* ===========================================================================
   PASO 6 · RAMA PERMISOS   ·  vw_ausentismo_v2
   ---------------------------------------------------------------------------
   El conteo de dias deja de ser aritmetica DATEDIFF/7 y pasa a ser un JOIN
   contra el calendario: se cuentan los dias que la persona SI trabajaba.
   Cualquiera puede abrir el detalle y ver que dia entro y cual no.
   =========================================================================== */
CREATE OR ALTER VIEW dbo.vw_ausentismo_v2 AS
WITH R AS (
    SELECT MAX(CASE WHEN Regla='HORAS_DIA_COMPLETO' THEN Valor END) AS HorasDia,
           MAX(CASE WHEN Regla='RESTAR_FERIADOS'    THEN Valor END) AS RestaFer,
           MAX(CASE WHEN Regla='ANIO_DESDE'         THEN Valor END) AS AnioDesde
    FROM dbo.param_regla_ausentismo
)
SELECT
    CAST(P.E_EMPID AS VARCHAR(50))                        AS Codigo,
    E.NOMINA_COD                                          AS Cedula,
    E.NOMINA_APE + ' ' + E.NOMINA_NOM                     AS Nombre_Completo,
    E.EMPE_NOM                                            AS Sucursal,
    E.AREA_NOM                                            AS Area,
    E.DEP_NOM                                             AS Departamento,
    E.NOMINA_CAL1                                         AS Cargo,
    CAST(TP.CD_ID AS VARCHAR(50))                         AS Tipo_Permiso,
    CAST(TP.CD_NOM AS VARCHAR(255))                       AS Nombre_Tipo_Permiso,
    CAST(P.E_FINICIO AS DATETIME)                         AS Fecha_Inicio,
    CAST(P.E_FFINAL  AS DATETIME)                         AS Fecha_Fin,
    CONVERT(VARCHAR(5), P.E_HoraI, 108)                   AS Hora_Inicio_Permiso,
    CONVERT(VARCHAR(5), P.E_HoraF, 108)                   AS Hora_Fin_Permiso,
    CAST(NULL AS DATETIME)                                AS Timbrado_Inicio,
    CAST(NULL AS DATETIME)                                AS Timbrado_Fin,
    CAST(NULL AS INT)                                     AS Minutos_Tiempo_Faltante,
    CAST(0.00 AS DECIMAL(9,2))                            AS Horas_No_Cumple_Horario,
    CAST('N/A' AS VARCHAR(30))                            AS Estado_Cumplimiento,
    dbo.fn_periodo_nomina(P.E_FINICIO)                    AS PeriodoEtiqueta,
    CAST(ISNULL(J.M_DES,'Sin Modalidad') AS VARCHAR(255)) AS ModalidadNombre,
    ISNULL(CONVERT(VARCHAR(5), Ref.HORARIO_INGRESO, 108), '08:00') AS Turno_Hora_Entrada,
    ISNULL(CONVERT(VARCHAR(5), Ref.HORARIO_SALIDA , 108), '16:00') AS Turno_Hora_Salida,
    CAST(R.HorasDia AS DECIMAL(19,2))                     AS Horas_Diarias_Turno,
    CAST(ISNULL(J.Sab,0) AS INT)                          AS Trabaja_Sabado,
    CAST(ISNULL(J.Dom,0) AS INT)                          AS Trabaja_Domingo,
    CAST(ISNULL(J.Descripcion_Jornada,'Sin Modalidad') AS VARCHAR(40)) AS Descripcion_Jornada,
    CAST(TP.Codigo_Reporte      AS VARCHAR(50))           AS Codigo_Reporte,
    CAST(TP.Descripcion_Reporte AS VARCHAR(255))          AS Descripcion_Reporte,
    CAST(
      CASE WHEN DATEDIFF(MINUTE, P.E_HoraI, P.E_HoraF) > 0
           THEN DATEDIFF(MINUTE, P.E_HoraI, P.E_HoraF) / 60.0
           ELSE D.DiasProgramados * R.HorasDia
      END AS DECIMAL(9,2))                                AS Horas_Permiso_Calculadas,
    CAST(CASE WHEN E.EMPE_NOM LIKE '%EMPAQPLAST%'  THEN 'UIO'
              WHEN E.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
              ELSE 'OTRA' END AS VARCHAR(20))             AS Ciudad_Sede
FROM dbo.stg_perm_aus P
CROSS JOIN R
JOIN dbo.param_tipo_permiso TP ON TP.CD_ID = P.E_TIPOP AND TP.CD_CAT = P.E_TIPOM
JOIN dbo.stg_empleado      E  ON E.NOMINA_ID = P.E_EMPID
OUTER APPLY (
    SELECT TOP 1 A.HORARIO_INGRESO, A.HORARIO_SALIDA, A.modalidad
    FROM dbo.stg_asistencia A
    WHERE A.EMP_ID = P.E_EMPID
      AND A.FECHA_INGRESO <= P.E_FINICIO
      AND A.FECHA_INGRESO >= DATEADD(DAY, -90, P.E_FINICIO)   -- ventana acotada
      AND A.HORARIO_INGRESO IS NOT NULL AND A.HORARIO_SALIDA IS NOT NULL
      AND NOT (DATEPART(HOUR,A.HORARIO_INGRESO)=0 AND DATEPART(MINUTE,A.HORARIO_INGRESO)=0
           AND DATEPART(HOUR,A.HORARIO_SALIDA )=0 AND DATEPART(MINUTE,A.HORARIO_SALIDA )=0)
    ORDER BY A.FECHA_INGRESO DESC
) AS Ref
LEFT JOIN dbo.vw_param_jornada J ON J.M_ID = Ref.modalidad
CROSS APPLY (
    /* Dias efectivamente programados dentro del permiso. Auditable dia a dia. */
    SELECT COUNT(*) AS DiasProgramados
    FROM dbo.dim_calendario C
    WHERE C.Fecha BETWEEN P.E_FINICIO AND P.E_FFINAL
      AND (TP.Resta_Feriados = 0 OR R.RestaFer = 0
           OR NOT EXISTS (SELECT 1 FROM dbo.stg_festivo F WHERE F.D_FESTIVO = C.Fecha))
      AND (TP.Resta_Fin_Semana = 0 OR J.M_ID IS NULL
           OR (C.DiaIdx=0 AND J.Lun=1) OR (C.DiaIdx=1 AND J.Mar=1)
           OR (C.DiaIdx=2 AND J.Mie=1) OR (C.DiaIdx=3 AND J.Jue=1)
           OR (C.DiaIdx=4 AND J.Vie=1) OR (C.DiaIdx=5 AND J.Sab=1)
           OR (C.DiaIdx=6 AND J.Dom=1))
) AS D
WHERE E.NOMINA_EMP IN ('7','8')
  AND YEAR(P.E_FINICIO) >= R.AnioDesde
  AND TP.Cuenta_En_IA = 1
  AND TP.Activo = 1;
GO

/* ===========================================================================
   PASO 7 · RAMA ATRASOS   ·  vm_atrasos_v2
   ---------------------------------------------------------------------------
   Cambio de fondo: ya NO se excluyen filas por nombre de modalidad.
   Un dia sin marcacion solo es ausencia si ERA un dia programado.
   Eso reemplaza los dos NOT(...) que borraban 3.968 filas en 2025.
   =========================================================================== */
CREATE OR ALTER VIEW dbo.vm_atrasos_v2 AS
WITH R AS (
    SELECT MAX(CASE WHEN Regla='UMBRAL_ATRASO_MIN' THEN Valor END) AS Umbral,
           MAX(CASE WHEN Regla='FI_HORAS_DIA'      THEN Valor END) AS FiHoras,
           MAX(CASE WHEN Regla='ANIO_DESDE'        THEN Valor END) AS AnioDesde
    FROM dbo.param_regla_ausentismo
),
Base AS (
    SELECT
        E.NOMINA_ID, E.NOMINA_COD, E.NOMINA_APE, E.NOMINA_NOM, E.EMPE_NOM,
        E.AREA_NOM, E.DEP_NOM, E.NOMINA_CAL1,
        A.FECHA_INGRESO, A.Hora_Ingreso, A.Hora_Salida,
        A.HORARIO_INGRESO, A.HORARIO_SALIDA, A.MIN_AT, A.MIN_SA,
        J.M_DES, J.Sab, J.Dom, J.Descripcion_Jornada,
        R.Umbral, R.FiHoras,
        CASE WHEN A.NOVEDAD_ENTRADA IN ('FI','NF') OR A.NOVEDAD_SALIDA IN ('FI','NF')
                  OR (A.Hora_Ingreso IS NULL AND A.Hora_Salida IS NULL) THEN 'FI'
             WHEN A.MIN_SA > 0      THEN 'NC'
             WHEN A.MIN_AT > R.Umbral THEN 'A'
             ELSE 'OK' END AS Cod
    FROM dbo.stg_asistencia A
    CROSS JOIN R
    JOIN dbo.stg_empleado   E ON E.NOMINA_ID = A.EMP_ID
    JOIN dbo.dim_calendario C ON C.Fecha     = A.FECHA_INGRESO
    LEFT JOIN dbo.vw_param_jornada J ON J.M_ID = A.modalidad
    WHERE E.NOMINA_EMP IN ('7','8')
      AND C.Anio >= R.AnioDesde
      AND NOT EXISTS (SELECT 1 FROM dbo.stg_festivo F WHERE F.D_FESTIVO = A.FECHA_INGRESO)
      /* Dia programado. Unica regla, misma que usa la rama de permisos. */
      AND (J.M_ID IS NULL
           OR (C.DiaIdx=0 AND J.Lun=1) OR (C.DiaIdx=1 AND J.Mar=1)
           OR (C.DiaIdx=2 AND J.Mie=1) OR (C.DiaIdx=3 AND J.Jue=1)
           OR (C.DiaIdx=4 AND J.Vie=1) OR (C.DiaIdx=5 AND J.Sab=1)
           OR (C.DiaIdx=6 AND J.Dom=1))
)
SELECT
    CAST(NOMINA_ID AS VARCHAR(50))                        AS Codigo,
    NOMINA_COD                                            AS Cedula,
    NOMINA_APE + ' ' + NOMINA_NOM                         AS Nombre_Completo,
    EMPE_NOM AS Sucursal, AREA_NOM AS Area, DEP_NOM AS Departamento, NOMINA_CAL1 AS Cargo,
    CAST(Cod AS VARCHAR(50))                              AS Tipo_Permiso,
    CAST('ATRASO SISTEMA' AS VARCHAR(255))                AS Nombre_Tipo_Permiso,
    CAST(ISNULL(Hora_Ingreso, CAST(FECHA_INGRESO AS DATETIME)) AS DATETIME) AS Fecha_Inicio,
    CAST(ISNULL(Hora_Salida , Hora_Ingreso) AS DATETIME)  AS Fecha_Fin,
    CONVERT(VARCHAR(5), Hora_Ingreso, 108)                AS Hora_Inicio_Permiso,
    CONVERT(VARCHAR(5), Hora_Salida , 108)                AS Hora_Fin_Permiso,
    Hora_Ingreso                                          AS Timbrado_Inicio,
    Hora_Salida                                           AS Timbrado_Fin,
    CAST(MIN_AT + MIN_SA AS INT)                          AS Minutos_Tiempo_Faltante,
    CAST(MIN_SA / 60.0 AS DECIMAL(9,2))                   AS Horas_No_Cumple_Horario,
    CAST(CASE Cod WHEN 'FI' THEN 'Falta Injustificada'
                  WHEN 'NC' THEN 'No Cumple Horario'
                  ELSE 'Atraso' END AS VARCHAR(30))       AS Estado_Cumplimiento,
    dbo.fn_periodo_nomina(FECHA_INGRESO)                  AS PeriodoEtiqueta,
    CAST(ISNULL(M_DES,'Sin Modalidad') AS VARCHAR(255))   AS ModalidadNombre,
    CONVERT(VARCHAR(5), HORARIO_INGRESO, 108)             AS Turno_Hora_Entrada,
    CONVERT(VARCHAR(5), HORARIO_SALIDA , 108)             AS Turno_Hora_Salida,
    CAST(CASE WHEN HORARIO_INGRESO IS NULL OR HORARIO_SALIDA IS NULL THEN 8.00
              WHEN HORARIO_SALIDA < HORARIO_INGRESO
                   THEN (DATEDIFF(MINUTE,HORARIO_INGRESO,HORARIO_SALIDA)+1440)/60.0
              ELSE DATEDIFF(MINUTE,HORARIO_INGRESO,HORARIO_SALIDA)/60.0
         END AS DECIMAL(19,2))                            AS Horas_Diarias_Turno,
    CAST(ISNULL(Sab,0) AS INT)                            AS Trabaja_Sabado,
    CAST(ISNULL(Dom,0) AS INT)                            AS Trabaja_Domingo,
    CAST(ISNULL(Descripcion_Jornada,'Sin Modalidad') AS VARCHAR(40)) AS Descripcion_Jornada,
    CAST(Cod AS VARCHAR(50))                              AS Codigo_Reporte,
    CAST(CASE Cod WHEN 'FI' THEN 'Falta Injustificada'
                  WHEN 'NC' THEN 'No Cumple Horario'
                  ELSE 'Atrasos' END AS VARCHAR(255))     AS Descripcion_Reporte,
    /* FI = dia completo SIEMPRE que fuera dia programado, sea lunes o sabado. */
    CAST(CASE WHEN Cod = 'FI' THEN FiHoras
              ELSE (MIN_AT + MIN_SA) / 60.0 END AS DECIMAL(9,2)) AS Horas_Permiso_Calculadas,
    CAST(CASE WHEN EMPE_NOM LIKE '%EMPAQPLAST%'  THEN 'UIO'
              WHEN EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
              ELSE 'OTRA' END AS VARCHAR(20))             AS Ciudad_Sede
FROM Base
WHERE Cod <> 'OK';
GO

/* ===========================================================================
   PASO 8 · FACT   ·  UNION ALL con columnas NOMBRADAS
   ---------------------------------------------------------------------------
   SELECT * en un UNION ALL empareja por POSICION: si manana alguien agrega
   una columna en una sola rama, los datos se corren de columna y NO da error.
   Se agrega Origen_Rama para que el usuario final pueda separar permisos de
   atrasos en el tablero sin adivinar por Nombre_Tipo_Permiso.
   =========================================================================== */
CREATE OR ALTER VIEW dbo.fact_ausentismo_v2 AS
SELECT Codigo, Cedula, Nombre_Completo, Sucursal, Area, Departamento, Cargo,
       Tipo_Permiso, Nombre_Tipo_Permiso, Fecha_Inicio, Fecha_Fin,
       Hora_Inicio_Permiso, Hora_Fin_Permiso, Timbrado_Inicio, Timbrado_Fin,
       Minutos_Tiempo_Faltante, Horas_No_Cumple_Horario, Estado_Cumplimiento,
       PeriodoEtiqueta, ModalidadNombre, Turno_Hora_Entrada, Turno_Hora_Salida,
       Horas_Diarias_Turno, Trabaja_Sabado, Trabaja_Domingo, Descripcion_Jornada,
       Codigo_Reporte, Descripcion_Reporte, Horas_Permiso_Calculadas, Ciudad_Sede,
       CAST('PERMISO' AS VARCHAR(10)) AS Origen_Rama
FROM dbo.vw_ausentismo_v2
UNION ALL
SELECT Codigo, Cedula, Nombre_Completo, Sucursal, Area, Departamento, Cargo,
       Tipo_Permiso, Nombre_Tipo_Permiso, Fecha_Inicio, Fecha_Fin,
       Hora_Inicio_Permiso, Hora_Fin_Permiso, Timbrado_Inicio, Timbrado_Fin,
       Minutos_Tiempo_Faltante, Horas_No_Cumple_Horario, Estado_Cumplimiento,
       PeriodoEtiqueta, ModalidadNombre, Turno_Hora_Entrada, Turno_Hora_Salida,
       Horas_Diarias_Turno, Trabaja_Sabado, Trabaja_Domingo, Descripcion_Jornada,
       Codigo_Reporte, Descripcion_Reporte, Horas_Permiso_Calculadas, Ciudad_Sede,
       CAST('ATRASO' AS VARCHAR(10)) AS Origen_Rama
FROM dbo.vm_atrasos_v2;
GO

/* ===========================================================================
   PASO 9 · CONTROLES  ·  correr ANTES de reemplazar el modelo de Power BI
   =========================================================================== */

-- 9.1  Parametros sin definir. Debe devolver 0 filas.
-- SELECT * FROM dbo.vw_control_parametros;

-- 9.2  Comparacion vieja vs nueva por tipo, periodo del Excel.
/*
SELECT ISNULL(v.Codigo_Reporte, n.Codigo_Reporte) AS Codigo,
       v.horas AS horas_ACTUAL, n.horas AS horas_V2,
       ISNULL(n.horas,0) - ISNULL(v.horas,0) AS diferencia
FROM (SELECT Codigo_Reporte, SUM(Horas_Permiso_Calculadas) horas
      FROM dbo.fact_ausentismo
      WHERE Fecha_Inicio >= '2025-07-21' AND Fecha_Inicio < '2025-08-21'
      GROUP BY Codigo_Reporte) v
FULL JOIN
     (SELECT Codigo_Reporte, SUM(Horas_Permiso_Calculadas) horas
      FROM dbo.fact_ausentismo_v2
      WHERE Fecha_Inicio >= '2025-07-21' AND Fecha_Inicio < '2025-08-21'
      GROUP BY Codigo_Reporte) n ON n.Codigo_Reporte = v.Codigo_Reporte
ORDER BY ABS(ISNULL(n.horas,0) - ISNULL(v.horas,0)) DESC;
*/

-- 9.3  Las dos ramas ya NO pueden contradecirse. Debe devolver 0 filas.
/*
SELECT ModalidadNombre, COUNT(DISTINCT Descripcion_Jornada) AS jornadas,
       COUNT(DISTINCT Trabaja_Sabado) AS valores_sabado
FROM dbo.fact_ausentismo_v2
GROUP BY ModalidadNombre
HAVING COUNT(DISTINCT Descripcion_Jornada) > 1 OR COUNT(DISTINCT Trabaja_Sabado) > 1;
*/

-- 9.4  FI ya no puede valer 0 h. Debe devolver 0 filas.
/*
SELECT TOP 100 * FROM dbo.fact_ausentismo_v2
WHERE Codigo_Reporte = 'FI' AND ISNULL(Horas_Permiso_Calculadas,0) = 0;
*/

-- 9.5  Auditoria dia a dia de un permiso concreto (lo que el usuario final pide).
/*
DECLARE @emp INT = 0, @ini DATE = '2025-07-21', @fin DATE = '2025-08-20';
SELECT C.Fecha,
       CASE C.DiaIdx WHEN 0 THEN 'Lun' WHEN 1 THEN 'Mar' WHEN 2 THEN 'Mie'
                     WHEN 3 THEN 'Jue' WHEN 4 THEN 'Vie' WHEN 5 THEN 'Sab'
                     ELSE 'Dom' END AS Dia,
       CASE WHEN F.D_FESTIVO IS NOT NULL THEN 'FERIADO: ' + F.D_DESC ELSE '' END AS Feriado,
       CASE WHEN (C.DiaIdx=0 AND J.Lun=1) OR (C.DiaIdx=1 AND J.Mar=1)
                 OR (C.DiaIdx=2 AND J.Mie=1) OR (C.DiaIdx=3 AND J.Jue=1)
                 OR (C.DiaIdx=4 AND J.Vie=1) OR (C.DiaIdx=5 AND J.Sab=1)
                 OR (C.DiaIdx=6 AND J.Dom=1) THEN 'SI' ELSE 'NO' END AS Dia_Programado
FROM dbo.dim_calendario C
LEFT JOIN dbo.stg_festivo F ON F.D_FESTIVO = C.Fecha
CROSS JOIN dbo.vw_param_jornada J
WHERE C.Fecha BETWEEN @ini AND @fin AND J.M_ID = (SELECT TOP 1 modalidad FROM dbo.stg_asistencia WHERE EMP_ID=@emp ORDER BY FECHA_INGRESO DESC)
ORDER BY C.Fecha;
*/
