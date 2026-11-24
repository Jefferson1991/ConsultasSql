-- =============================================================================
-- ACTIVOS FIJOS PARA POWER BI (SAP B1 sobre HANA)
-- Esquema: EMPAQPLAST_PROD  |  Área de depreciación: FINANCIERO
--
-- Vistas
--   1. EMPAQPLAST_PROD.SB1_VIEW_ACTIVOS_FIJOS_SALDOS: la sábana de activos fijos,
--      con una fila por activo. Incluye grupo, clase, cuentas, asignación, UDF,
--      fechas, depreciación, saldos a hoy y el proyecto de origen.
--   2. EMPAQPLAST_PROD.SB1_VIEW_PROYECTOS_ACTIVOS_FIJOS: cuenta "Proyectos Activos
--      Fijos" (hijas de 150110). Una fila por línea de asiento, con su estado de
--      reconciliación y a qué se destinó (activo o reclasificación).
--
-- Despliegue
--   Ejecutar en DBeaver las dos sentencias CREATE OR REPLACE VIEW. No hay orden:
--   las vistas no dependen entre sí.
--   NO se toca la vista existente SB1_VIEW_ACTIVOS_FIJOS (2025-11-25): tiene otro
--   alcance (219 activos, 234 filas) y puede alimentar otro tablero.
--   En Power BI: conector SAP HANA > esquema EMPAQPLAST_PROD > elegir las vistas.
--   No usan parámetros [%0]: el año contable se toma solo (último año de ITM8).
--
-- Lógica de saldos (verificada en vivo el 2026-09-16)
--   ITM8 guarda el saldo de APERTURA de cada año; no se actualiza en el año.
--   Saldo a hoy = ITM8 del año
--               + movimientos del año en FIX1 (capitalización, NC, retiro),
--                 excluyendo documentos cancelados (OFIX.Canceled = 'Y')
--               + depreciación contabilizada del año (ODPV.OrdDprPost).
--   Pruebas:
--   * Con esta fórmula, el cierre 2025 reproduce ITM8 2026 en los 1.613
--     activos, con 0 diferencias en costo y en depreciación.
--   * Service Layer FixedAssetItemsService_GetAssetEndBalance (año 2025) coincide
--     al centavo en 6 activos: con alta, con baja, edificio, totalmente depreciado.
--   * Contra el mayor (OACT) cuadra al centavo en Maquinaria, Reavalúo
--     Maquinaria, Muebles y Enseres, Equipo de Oficina y Computación. Edificios,
--     Reavalúo Edificios y Vehículos NO cuadran porque tienen asientos manuales
--     (TransType 30) y facturas (18) fuera del módulo de activos fijos.
--   * El "fin de año" del reporte estándar de SAP usa la depreciación PLANIFICADA
--     del año completo; eso es Dep_Acum_Proyectada_Cierre / VNC_Proyectado_Cierre.
--
-- Supuestos verificados
--   * Clase de activo: OITM.AssetClass -> ACS1 (FINANCIERO) -> OADT (determinación)
--     -> cuenta de balance. El nombre de esa cuenta es la clase ("Muebles y Enseres").
--   * OITM.AsstStatus: A = Activo, I = Inactivo, N = Nuevo (confirmado con SL).
--   * OACQ.DocStatus: P = contabilizado, C = cancelado (coincide con OFIX.Canceled).
--   * OPMG.STATUS: S = Iniciado, F = Terminado, T = Detenido, N = Cancelado (SL).
--   * OITR.Canceled: N = vigente, Y = anulada, C = registro de anulación.
--
-- Vínculo proyecto <-> activo (verificado 2026-09-16)
--   SAP no tiene un campo que una activo y proyecto (ACQ1.Project va vacío).
--   El flujo real en la cuenta 15011001 es:
--     a) Las facturas y reclasificaciones entran con código de proyecto.
--     b) Al activar, un asiento manual acredita 15011001 y debita la cuenta del
--        activo (1501xxxx). Contabilidad lo reconcilia internamente (OITR/ITR1)
--        contra las líneas del proyecto.
--     c) Aparte se hace la capitalización (OACQ) del activo. Desde 2025 su texto
--        dice el proyecto ("ACTIVACION PROY 147 ...", "ACT PROY 134 ...").
--   * Vista 2: "Saldo_Abierto" (BalDueDeb - BalDueCred) = lo no reconciliado.
--     Suma 2.347.272,79, igual al saldo de la cuenta, y ninguna línea abierta
--     queda sin proyecto. Reproduce la ventana "Saldo de cuenta" de SAP con
--     "Visualizar sólo operaciones no reconciliadas" (saldo previo a las últimas
--     50 operaciones = 1.956.297,468237, igual que en SAP).
--   * Vista 2: "Situacion" usa la reconciliación. Si el grupo se cerró contra una
--     cuenta 1501 (propiedad, planta y equipo), la línea es "Activado"; si se cerró
--     contra otra cuenta, "Reclasificado". Las 4 situaciones suman el saldo exacto.
--   * Vista 1: el proyecto se lee del texto de la capitalización (línea, comentario
--     o referencia) y solo se muestra si el código existe en OPRJ. Cubre el 94 %
--     del valor capitalizado de 2025 y 2026. Antes de 2025 el texto no lo trae.
-- =============================================================================


-- =============================================================================
-- VISTA 1: SÁBANA DE ACTIVOS FIJOS (una fila por activo)
-- =============================================================================
CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_ACTIVOS_FIJOS_SALDOS AS
SELECT
    -- Identificación ---------------------------------------------------------
    T."ItemCode"                                            AS "Cod_Activo",
    T."ItemName"                                            AS "Descripcion",
    T."FrgnName"                                            AS "Nombre_Extranjero",
    T."ItmsGrpCod"                                          AS "Cod_Grupo",
    G."ItmsGrpNam"                                          AS "Grupo",
    T."AsstStatus"                                          AS "Cod_Estado_SAP",
    CASE T."AsstStatus"
        WHEN 'A' THEN 'Activo'
        WHEN 'I' THEN 'Inactivo'
        WHEN 'N' THEN 'Nuevo'
        ELSE T."AsstStatus"
    END                                                     AS "Estado_SAP",
    T."validFor"                                            AS "Habilitado",
    T."frozenFor"                                           AS "Congelado",

    -- Clasificación contable -------------------------------------------------
    T."AssetClass"                                          AS "Cod_Subclase",
    C."Name"                                                AS "Subclase",
    S."AcctDtn"                                             AS "Cod_Determinacion",
    AD."Descr"                                              AS "Determinacion",
    AD."BalanceAct"                                         AS "Cta_Activo",
    A1."AcctName"                                           AS "Clase_Activo",
    AD."OrdDprAcc"                                          AS "Cta_Dep_Acumulada",
    A2."AcctName"                                           AS "Cta_Dep_Acumulada_Nombre",
    AD."OrdDprAct"                                          AS "Cta_Gasto_Dep",
    A3."AcctName"                                           AS "Cta_Gasto_Dep_Nombre",

    -- Asignación (dimensiones vigentes hoy) -----------------------------------
    D."OcrCode"                                             AS "Cod_Sucursal",
    OC1."OcrName"                                           AS "Sucursal",
    D."OcrCode2"                                            AS "Cod_Area",
    OC2."OcrName"                                           AS "Area",
    D."OcrCode3"                                            AS "Cod_Departamento",
    OC3."OcrName"                                           AS "Departamento",
    L."Location"                                            AS "Ubicacion_SAP",
    T."U_UBICACION_ITEM"                                    AS "Ubicacion_Item",
    E."firstName" || ' ' || E."lastName"                    AS "Empleado",
    TE."firstName" || ' ' || TE."lastName"                  AS "Tecnico",

    -- Datos del bien (UDF) ------------------------------------------------------
    T."AssetSerNo"                                          AS "Serie_SAP",
    T."U_EMPA_SERIE"                                        AS "Serie",
    T."U_EMPA_MARCA"                                        AS "Marca",
    T."U_EMPA_MODELO"                                       AS "Modelo",
    T."U_EMPA_PROCEDENCIA"                                  AS "Procedencia",
    T."U_EMPA_TIPO_ITEM"                                    AS "Tipo_Item",
    T."U_EMPA_ESTADO_ACTIVO"                                AS "Estado_Activo_UDF",
    T."U_EMPA_COD_RECURSO"                                  AS "Recurso",
    T."U_COD_RECURSO"                                       AS "Cod_Recurso_Legacy",
    T."U_EMPA_COD_BEAS"                                     AS "Cod_BEAS",
    T."U_EMPA_COD_FRACTTAL"                                 AS "Cod_Fracttal",
    T."U_Codigo_Secundario"                                 AS "Codigo_Secundario",
    T."U_ProcesoProductivo"                                 AS "Proceso_Productivo",
    T."U_SEGURO"                                            AS "Monto_Asegurado",
    T."U_VAL_SEGURO"                                        AS "Valor_Seguro",
    T."U_Poliza_Seguros"                                    AS "Poliza_Seguros",
    T."U_EMPA_AVALUADOR"                                    AS "Avaluador",
    T."U_EMPA_VALOR_AVALUO"                                 AS "Valor_Avaluo",
    T."U_Garantia_Banco"                                    AS "Cod_Ent_Financiera",
    B."BankName"                                            AS "Ent_Financiera",
    T."U_EMPA_VALOR_PRENDA"                                 AS "Valor_Prenda",
    T."U_Valor_Garantia"                                    AS "Valor_Garantia",
    T."U_Valor_Reevaluo"                                    AS "Valor_Reevaluo",
    CAST(SUBSTRING(T."UserText", 1, 1000) AS NVARCHAR(1000)) AS "Comentarios",

    -- Fechas ------------------------------------------------------------------
    T."AcqDate"                                             AS "F_Adquisicion",
    T."CapDate"                                             AS "F_Capitalizacion",
    T."RetDate"                                             AS "F_Retiro",
    CQ."F_Primera_Capitalizacion"                           AS "F_Doc_Capitalizacion",
    CQ."No_Doc_Capitalizacion"                              AS "No_Doc_Capitalizacion",
    CQ."Docs_Capitalizacion"                                AS "Docs_Capitalizacion",
    T."CreateDate"                                          AS "F_Creacion_SAP",
    T."UpdateDate"                                          AS "F_Modificacion_SAP",

    -- Proyecto de origen (texto de la capitalización, validado contra OPRJ) ------
    PRJ."PrjCode"                                           AS "Cod_Proyecto",
    PRJ."PrjName"                                           AS "Proyecto",
    CASE
        WHEN PRJ."PrjCode" IS NULL THEN 'Sin vinculo'
        WHEN PJ."Proyectos_Distintos" > 1 THEN 'Texto capitalizacion (varios proyectos)'
        ELSE 'Texto capitalizacion'
    END                                                     AS "Vinculo_Proyecto",

    -- Parámetros de depreciación del año ----------------------------------------
    T7."DprType"                                            AS "Metodo_Depreciacion",
    T7."DprStart"                                           AS "F_Inicio_Depreciacion",
    T7."DprEnd"                                             AS "F_Fin_Depreciacion",
    T7."UsefulLife"                                         AS "Vida_Util_Meses",
    T7."RemainLife"                                         AS "Vida_Restante_Inicio_Anio",

    -- Valores del año contable (FINANCIERO) --------------------------------------
    P."Anio"                                                AS "Anio_Contable",
    COALESCE(T8."Quantity", 0) + COALESCE(MV."Cantidad", 0) AS "Cantidad",
    COALESCE(T8."APC", 0)                                   AS "Costo_Inicio_Anio",
    COALESCE(T8."OrDpAcc", 0) + COALESCE(T8."UnDpAcc", 0)   AS "Dep_Acum_Inicio_Anio",
    COALESCE(T8."APC", 0)
      - COALESCE(T8."OrDpAcc", 0) - COALESCE(T8."UnDpAcc", 0) AS "VNC_Inicio_Anio",
    COALESCE(MV."Altas", 0)                                 AS "Altas_Anio",
    COALESCE(MV."NC_Altas", 0)                              AS "NC_Capitalizacion_Anio",
    COALESCE(MV."Bajas_Costo", 0)                           AS "Bajas_Costo_Anio",
    COALESCE(MV."Otros_Costo", 0)                           AS "Otros_Costo_Anio",
    COALESCE(DP."Dep_Contabilizada", 0)                     AS "Dep_Contabilizada_Anio",
    -- Negativo: depreciación acumulada que sale con el retiro
    COALESCE(MV."Bajas_Dep", 0)                             AS "Bajas_Dep_Anio",
    COALESCE(MV."Otros_Dep", 0)                             AS "Otros_Dep_Anio",

    -- Saldos a hoy (cuadran con el mayor) ---------------------------------------
    COALESCE(T8."APC", 0) + COALESCE(MV."Costo", 0)         AS "Costo_Actual",
    COALESCE(T8."OrDpAcc", 0) + COALESCE(T8."UnDpAcc", 0)
      + COALESCE(DP."Dep_Contabilizada", 0)
      + COALESCE(MV."Dep", 0)                               AS "Dep_Acumulada",
    COALESCE(T8."APC", 0) + COALESCE(MV."Costo", 0)
      - COALESCE(T8."OrDpAcc", 0) - COALESCE(T8."UnDpAcc", 0)
      - COALESCE(DP."Dep_Contabilizada", 0)
      - COALESCE(MV."Dep", 0)                               AS "Valor_Neto_Contable",
    DP."Ult_Mes_Depreciado"                                 AS "Ult_Mes_Depreciado",

    -- Proyección al cierre del año (como el reporte de SAP) ------------------------
    COALESCE(DP."Dep_Planificada", 0)                       AS "Dep_Planificada_Anio",
    COALESCE(T8."OrDpAcc", 0) + COALESCE(T8."UnDpAcc", 0)
      + COALESCE(DP."Dep_Planificada", 0)
      + COALESCE(MV."Dep", 0)                               AS "Dep_Acum_Proyectada_Cierre",
    COALESCE(T8."APC", 0) + COALESCE(MV."Costo", 0)
      - COALESCE(T8."OrDpAcc", 0) - COALESCE(T8."UnDpAcc", 0)
      - COALESCE(DP."Dep_Planificada", 0)
      - COALESCE(MV."Dep", 0)                               AS "VNC_Proyectado_Cierre",
    COALESCE(T8."SalvageVal", 0)                            AS "Valor_Residual",

    -- Depreciación contabilizada por mes del año contable --------------------------
    COALESCE(DP."Enero", 0)                                 AS "Dep_Enero",
    COALESCE(DP."Febrero", 0)                               AS "Dep_Febrero",
    COALESCE(DP."Marzo", 0)                                 AS "Dep_Marzo",
    COALESCE(DP."Abril", 0)                                 AS "Dep_Abril",
    COALESCE(DP."Mayo", 0)                                  AS "Dep_Mayo",
    COALESCE(DP."Junio", 0)                                 AS "Dep_Junio",
    COALESCE(DP."Julio", 0)                                 AS "Dep_Julio",
    COALESCE(DP."Agosto", 0)                                AS "Dep_Agosto",
    COALESCE(DP."Septiembre", 0)                            AS "Dep_Septiembre",
    COALESCE(DP."Octubre", 0)                               AS "Dep_Octubre",
    COALESCE(DP."Noviembre", 0)                             AS "Dep_Noviembre",
    COALESCE(DP."Diciembre", 0)                             AS "Dep_Diciembre",

    -- Banderas (etiquetan, no filtran) ----------------------------------------------
    CASE
        WHEN COALESCE(T8."APC", 0) + COALESCE(MV."Costo", 0) <> 0 THEN 'SI'
        ELSE 'NO'
    END                                                     AS "Con_Saldo",
    CASE WHEN S."AcctDtn" IS NULL THEN 'SI' ELSE 'NO' END   AS "Sin_Clase_Contable",
    CURRENT_DATE                                            AS "F_Extraccion"
FROM OITM T
INNER JOIN OITB G
    ON G."ItmsGrpCod" = T."ItmsGrpCod"
CROSS JOIN (
    SELECT MAX("PeriodCat") AS "Anio"
    FROM ITM8
    WHERE "DprArea" = 'FINANCIERO'
) P
LEFT JOIN ITM7 T7
    ON T7."ItemCode" = T."ItemCode"
   AND T7."PeriodCat" = P."Anio"
   AND T7."DprArea" = 'FINANCIERO'
LEFT JOIN ITM8 T8
    ON T8."ItemCode" = T."ItemCode"
   AND T8."PeriodCat" = P."Anio"
   AND T8."DprArea" = 'FINANCIERO'
-- Movimientos del año no cancelados (FIX1), separados por documento origen
LEFT JOIN (
    SELECT
        F."ItemCode",
        SUM(F."Qty")                                                        AS "Cantidad",
        SUM(F."APC")                                                        AS "Costo",
        SUM(F."OrdDpr" + F."UnpDpr")                                        AS "Dep",
        SUM(CASE WHEN H."SrcObjType" = '1470000049' THEN F."APC" ELSE 0 END) AS "Altas",
        SUM(CASE WHEN H."SrcObjType" = '1470000060' THEN F."APC" ELSE 0 END) AS "NC_Altas",
        SUM(CASE WHEN H."SrcObjType" = '1470000094' THEN F."APC" ELSE 0 END) AS "Bajas_Costo",
        SUM(CASE WHEN H."SrcObjType" = '1470000094'
                 THEN F."OrdDpr" + F."UnpDpr" ELSE 0 END)                   AS "Bajas_Dep",
        SUM(CASE WHEN H."SrcObjType" NOT IN ('1470000049', '1470000060', '1470000094')
                 THEN F."APC" ELSE 0 END)                                   AS "Otros_Costo",
        SUM(CASE WHEN H."SrcObjType" NOT IN ('1470000049', '1470000060', '1470000094')
                 THEN F."OrdDpr" + F."UnpDpr" ELSE 0 END)                   AS "Otros_Dep"
    FROM FIX1 F
    INNER JOIN OFIX H
        ON H."AbsEntry" = F."AbsEntry"
    INNER JOIN (
        SELECT MAX("PeriodCat") AS "Anio"
        FROM ITM8
        WHERE "DprArea" = 'FINANCIERO'
    ) PX
        ON PX."Anio" = F."PeriodCat"
    WHERE H."Canceled" = 'N'
      AND F."DprArea" = 'FINANCIERO'
    GROUP BY F."ItemCode"
) MV
    ON MV."ItemCode" = T."ItemCode"
-- Depreciación del año: contabilizada, planificada y por mes (ODPV)
LEFT JOIN (
    SELECT
        V."ItemCode",
        SUM(V."OrdDprPost")                                                 AS "Dep_Contabilizada",
        SUM(V."OrdDprPlan")                                                 AS "Dep_Planificada",
        MAX(CASE WHEN V."OrdDprPost" <> 0 THEN V."ToDate" END)              AS "Ult_Mes_Depreciado",
        SUM(CASE WHEN MONTH(V."FromDate") =  1 THEN V."OrdDprPost" ELSE 0 END) AS "Enero",
        SUM(CASE WHEN MONTH(V."FromDate") =  2 THEN V."OrdDprPost" ELSE 0 END) AS "Febrero",
        SUM(CASE WHEN MONTH(V."FromDate") =  3 THEN V."OrdDprPost" ELSE 0 END) AS "Marzo",
        SUM(CASE WHEN MONTH(V."FromDate") =  4 THEN V."OrdDprPost" ELSE 0 END) AS "Abril",
        SUM(CASE WHEN MONTH(V."FromDate") =  5 THEN V."OrdDprPost" ELSE 0 END) AS "Mayo",
        SUM(CASE WHEN MONTH(V."FromDate") =  6 THEN V."OrdDprPost" ELSE 0 END) AS "Junio",
        SUM(CASE WHEN MONTH(V."FromDate") =  7 THEN V."OrdDprPost" ELSE 0 END) AS "Julio",
        SUM(CASE WHEN MONTH(V."FromDate") =  8 THEN V."OrdDprPost" ELSE 0 END) AS "Agosto",
        SUM(CASE WHEN MONTH(V."FromDate") =  9 THEN V."OrdDprPost" ELSE 0 END) AS "Septiembre",
        SUM(CASE WHEN MONTH(V."FromDate") = 10 THEN V."OrdDprPost" ELSE 0 END) AS "Octubre",
        SUM(CASE WHEN MONTH(V."FromDate") = 11 THEN V."OrdDprPost" ELSE 0 END) AS "Noviembre",
        SUM(CASE WHEN MONTH(V."FromDate") = 12 THEN V."OrdDprPost" ELSE 0 END) AS "Diciembre"
    FROM ODPV V
    INNER JOIN (
        SELECT MAX("PeriodCat") AS "Anio"
        FROM ITM8
        WHERE "DprArea" = 'FINANCIERO'
    ) PX
        ON PX."Anio" = V."PeriodCat"
    WHERE V."DprArea" = 'FINANCIERO'
    GROUP BY V."ItemCode"
) DP
    ON DP."ItemCode" = T."ItemCode"
-- Documentos de capitalización contabilizados (sin cancelados)
LEFT JOIN (
    SELECT
        X1."ItemCode",
        MIN(X0."PostDate")            AS "F_Primera_Capitalizacion",
        MIN(X0."DocNum")              AS "No_Doc_Capitalizacion",
        COUNT(DISTINCT X0."DocEntry") AS "Docs_Capitalizacion"
    FROM OACQ X0
    INNER JOIN ACQ1 X1
        ON X1."DocEntry" = X0."DocEntry"
    WHERE X0."DocStatus" = 'P'
    GROUP BY X1."ItemCode"
) CQ
    ON CQ."ItemCode" = T."ItemCode"
-- Proyecto escrito en la capitalización: primero la línea, luego comentario/referencia
LEFT JOIN (
    SELECT
        X."ItemCode",
        MAX(X."Cod_Proyecto")            AS "Cod_Proyecto",
        COUNT(DISTINCT X."Cod_Proyecto") AS "Proyectos_Distintos"
    FROM (
        SELECT
            X1."ItemCode",
            COALESCE(
                SUBSTR_REGEXPR('PROY(ECTO)?[^0-9A-Z]{0,4}([0-9]{1,4})' FLAG 'i'
                    IN COALESCE(X1."Remarks", '') GROUP 2),
                SUBSTR_REGEXPR('PROY(ECTO)?[^0-9A-Z]{0,4}([0-9]{1,4})' FLAG 'i'
                    IN COALESCE(X0."Comments", '') || ' ' || COALESCE(X0."Reference", '') GROUP 2)
            ) AS "Cod_Proyecto"
        FROM OACQ X0
        INNER JOIN ACQ1 X1
            ON X1."DocEntry" = X0."DocEntry"
        WHERE X0."DocStatus" = 'P'
    ) X
    INNER JOIN OPRJ XP
        ON XP."PrjCode" = X."Cod_Proyecto"
    GROUP BY X."ItemCode"
) PJ
    ON PJ."ItemCode" = T."ItemCode"
LEFT JOIN OPRJ PRJ
    ON PRJ."PrjCode" = PJ."Cod_Proyecto"
-- Clase, determinación de cuentas y cuentas
LEFT JOIN OACS C
    ON C."Code" = T."AssetClass"
LEFT JOIN ACS1 S
    ON S."Code" = T."AssetClass"
   AND S."DprAreaID" = 'FINANCIERO'
LEFT JOIN OADT AD
    ON AD."Code" = S."AcctDtn"
LEFT JOIN OACT A1
    ON A1."AcctCode" = AD."BalanceAct"
LEFT JOIN OACT A2
    ON A2."AcctCode" = AD."OrdDprAcc"
LEFT JOIN OACT A3
    ON A3."AcctCode" = AD."OrdDprAct"
-- Dimensiones vigentes a la fecha de extracción
LEFT JOIN (
    SELECT
        "ItemCode",
        MAX("LineNum") AS "LineNum"
    FROM ITM6
    WHERE "ValidFrom" <= CURRENT_DATE
      AND ("ValidTo" IS NULL OR "ValidTo" >= CURRENT_DATE)
    GROUP BY "ItemCode"
) DV
    ON DV."ItemCode" = T."ItemCode"
LEFT JOIN ITM6 D
    ON D."ItemCode" = DV."ItemCode"
   AND D."LineNum" = DV."LineNum"
LEFT JOIN OOCR OC1
    ON OC1."OcrCode" = D."OcrCode"
   AND OC1."DimCode" = 1
LEFT JOIN OOCR OC2
    ON OC2."OcrCode" = D."OcrCode2"
   AND OC2."DimCode" = 2
LEFT JOIN OOCR OC3
    ON OC3."OcrCode" = D."OcrCode3"
   AND OC3."DimCode" = 3
LEFT JOIN OLCT L
    ON L."Code" = T."Location"
LEFT JOIN OHEM E
    ON E."empID" = T."Employee"
LEFT JOIN OHEM TE
    ON TE."empID" = T."Technician"
LEFT JOIN ODSC B
    ON B."BankCode" = T."U_Garantia_Banco"
WHERE T."ItemType" = 'F';


-- =============================================================================
-- VISTA 2: PROYECTOS DE ACTIVOS FIJOS (una fila por línea de asiento)
--   Cuentas hijas de 150110 "PROYECTO ACTIVOS FIJOS" (hoy solo 15011001).
--   En Power BI, por Cod_Proyecto:
--     En construcción = SUM(Saldo_Abierto)       (igual que la ventana de SAP)
--     Activado        = SUM(Monto) con Situacion = 'Activado'
--     Reclasificado   = SUM(Monto) con Situacion = 'Reclasificado'
--   NO sumar Monto de todas las líneas por proyecto: los asientos de activación
--   suelen ir sin proyecto y dejarían saldos falsos en proyectos ya cerrados.
-- =============================================================================
CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_PROYECTOS_ACTIVOS_FIJOS AS
SELECT
    -- Proyecto -----------------------------------------------------------------
    NULLIF(J."Project", '')                                 AS "Cod_Proyecto",
    PR."PrjName"                                            AS "Proyecto",
    PR."Active"                                             AS "Proyecto_Activo",
    PR."ValidFrom"                                          AS "Proyecto_Desde",
    PR."ValidTo"                                            AS "Proyecto_Hasta",
    PM."DocNum"                                             AS "No_Gestion_Proyecto",
    PM."STATUS"                                             AS "Cod_Estado_Gestion",
    CASE PM."STATUS"
        WHEN 'S' THEN 'Iniciado'
        WHEN 'F' THEN 'Terminado'
        WHEN 'T' THEN 'Detenido'
        WHEN 'N' THEN 'Cancelado'
        ELSE PM."STATUS"
    END                                                     AS "Estado_Gestion",
    PM."START"                                              AS "F_Inicio_Gestion",
    PM."DUEDATE"                                            AS "F_Vencimiento_Gestion",
    PM."CLOSING"                                            AS "F_Cierre_Gestion",
    PM."U_EMPA_CLAS_PRY"                                    AS "Clasificacion_Proyecto",
    PM."U_EMPA_AREA"                                        AS "Area_Proyecto",
    PM."U_EMPA_PROCESO"                                     AS "Proceso_Proyecto",
    PM."U_EMPA_MAQ_PRY"                                     AS "Maquina_Proyecto",
    PM."U_EMPA_MOLD_PRY"                                    AS "Molde_Proyecto",

    -- Asiento ------------------------------------------------------------------
    J."Account"                                             AS "Cuenta",
    AC."AcctName"                                           AS "Cuenta_Nombre",
    J."TransId"                                             AS "No_Asiento",
    J."Line_ID"                                             AS "Linea_Asiento",
    J."RefDate"                                             AS "F_Contabilizacion",
    J."TaxDate"                                             AS "F_Documento",
    YEAR(J."RefDate")                                       AS "Anio",
    MONTH(J."RefDate")                                      AS "Mes",
    J."TransType"                                           AS "Cod_Tipo_Origen",
    CASE J."TransType"
        WHEN '18'         THEN 'Factura de proveedor'
        WHEN '19'         THEN 'Nota de crédito de proveedor'
        WHEN '20'         THEN 'Entrada de mercancías (compra)'
        WHEN '30'         THEN 'Asiento manual'
        WHEN '59'         THEN 'Entrada de mercancías'
        WHEN '60'         THEN 'Salida de mercancías'
        WHEN '69'         THEN 'Precio de entrega'
        WHEN '1470000049' THEN 'Capitalización'
        WHEN '1470000060' THEN 'NC de capitalización'
        WHEN '1470000094' THEN 'Retiro de activo'
        WHEN '-2'         THEN 'Saldo de apertura'
        WHEN '-3'         THEN 'Cierre de periodo'
        ELSE J."TransType"
    END                                                     AS "Tipo_Origen",
    J."BaseRef"                                             AS "No_Doc_Origen",
    J."Ref1"                                                AS "Referencia_1",
    J."Ref2"                                                AS "Referencia_2",
    J."LineMemo"                                            AS "Detalle_Linea",
    OJ."Memo"                                               AS "Comentario_Asiento",
    COALESCE(FP."CardCode", NP."CardCode")                  AS "Cod_Proveedor",
    COALESCE(FP."CardName", NP."CardName")                  AS "Proveedor",
    COALESCE(FP."NumAtCard", NP."NumAtCard")                AS "Factura_Proveedor",
    J."ProfitCode"                                          AS "Cod_Sucursal",
    J."OcrCode2"                                            AS "Cod_Area",
    J."OcrCode3"                                            AS "Cod_Departamento",

    -- Importes -------------------------------------------------------------------
    J."Debit"                                               AS "Debe",
    J."Credit"                                              AS "Haber",
    J."Debit" - J."Credit"                                  AS "Monto",
    J."BalDueDeb" - J."BalDueCred"                          AS "Saldo_Abierto",

    -- Reconciliación interna y destino -----------------------------------------------
    CASE
        WHEN J."BalDueDeb" - J."BalDueCred" = 0 THEN 'Reconciliada'
        WHEN J."BalDueDeb" - J."BalDueCred" = J."Debit" - J."Credit" THEN 'Abierta'
        ELSE 'Parcial'
    END                                                     AS "Estado_Reconciliacion",
    CASE
        WHEN J."BalDueDeb" - J."BalDueCred" <> 0 THEN 'En construccion'
        WHEN RL."ReconNum" IS NULL THEN 'Sin reconciliacion'
        WHEN J."Credit" > 0 THEN 'Cierre'
        WHEN RD."Destino_Activo" = 1 THEN 'Activado'
        ELSE 'Reclasificado'
    END                                                     AS "Situacion",
    RL."ReconNum"                                           AS "No_Reconciliacion",
    RH."ReconDate"                                          AS "F_Reconciliacion",
    RA."Asientos_Cierre"                                    AS "Asientos_Cierre",
    RD."Ctas_Destino"                                       AS "Ctas_Destino",

    -- Banderas -------------------------------------------------------------------
    CASE WHEN COALESCE(J."Project", '') = '' THEN 'SI' ELSE 'NO' END AS "Sin_Proyecto",
    CURRENT_DATE                                            AS "F_Extraccion"
FROM JDT1 J
INNER JOIN OACT AC
    ON AC."AcctCode" = J."Account"
   AND AC."FatherNum" = '150110'
INNER JOIN OJDT OJ
    ON OJ."TransId" = J."TransId"
LEFT JOIN OPRJ PR
    ON PR."PrjCode" = J."Project"
LEFT JOIN OPMG PM
    ON PM."FIPROJECT" = J."Project"
LEFT JOIN OPCH FP
    ON J."TransType" = '18'
   AND FP."DocEntry" = J."CreatedBy"
LEFT JOIN ORPC NP
    ON J."TransType" = '19'
   AND NP."DocEntry" = J."CreatedBy"
-- Última reconciliación vigente de la línea
LEFT JOIN (
    SELECT
        R."TransId",
        R."TransRowId",
        MAX(R."ReconNum") AS "ReconNum"
    FROM ITR1 R
    INNER JOIN OITR H
        ON H."ReconNum" = R."ReconNum"
       AND H."Canceled" = 'N'
    INNER JOIN OACT A
        ON A."AcctCode" = R."Account"
       AND A."FatherNum" = '150110'
    GROUP BY R."TransId", R."TransRowId"
) RL
    ON RL."TransId" = J."TransId"
   AND RL."TransRowId" = J."Line_ID"
LEFT JOIN OITR RH
    ON RH."ReconNum" = RL."ReconNum"
-- Asientos que cierran el grupo (líneas al haber de la cuenta de proyectos)
LEFT JOIN (
    SELECT
        C."ReconNum",
        STRING_AGG(TO_NVARCHAR(C."TransId"), ', ') AS "Asientos_Cierre"
    FROM (
        SELECT DISTINCT R."ReconNum", R."TransId"
        FROM ITR1 R
        INNER JOIN OITR H
            ON H."ReconNum" = R."ReconNum"
           AND H."Canceled" = 'N'
        INNER JOIN OACT A
            ON A."AcctCode" = R."Account"
           AND A."FatherNum" = '150110'
        WHERE R."IsCredit" = 'C'
    ) C
    GROUP BY C."ReconNum"
) RA
    ON RA."ReconNum" = RL."ReconNum"
-- Cuentas debitadas por esos asientos de cierre; 1501xxxx = activo fijo
LEFT JOIN (
    SELECT
        D."ReconNum",
        STRING_AGG(D."Account" || ' ' || COALESCE(DA."AcctName", ''), ' | ') AS "Ctas_Destino",
        MAX(CASE WHEN LEFT(D."Account", 4) = '1501' THEN 1 ELSE 0 END)   AS "Destino_Activo"
    FROM (
        SELECT DISTINCT C."ReconNum", K."Account"
        FROM (
            SELECT DISTINCT R."ReconNum", R."TransId"
            FROM ITR1 R
            INNER JOIN OITR H
                ON H."ReconNum" = R."ReconNum"
               AND H."Canceled" = 'N'
            INNER JOIN OACT A
                ON A."AcctCode" = R."Account"
               AND A."FatherNum" = '150110'
            WHERE R."IsCredit" = 'C'
        ) C
        INNER JOIN JDT1 K
            ON K."TransId" = C."TransId"
           AND K."Debit" > 0
        LEFT JOIN OACT KA
            ON KA."AcctCode" = K."Account"
        WHERE COALESCE(KA."FatherNum", '') <> '150110'
    ) D
    LEFT JOIN OACT DA
        ON DA."AcctCode" = D."Account"
    GROUP BY D."ReconNum"
) RD
    ON RD."ReconNum" = RL."ReconNum";
