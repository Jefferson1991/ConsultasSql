/* =========================================================================
   SB1_VIEW_ORDENES_COMPRA  --  Órdenes de Compra de SAP B1 (OPOR / POR1)
   Esquema: EMPAQPLAST_PROD   |   Motor: SAP HANA

   Granularidad: UNA FILA POR LÍNEA DE OC (cabecera repetida en cada línea),
   igual que SB1_VIEW_OC pero con estado, montos, pendientes y trazabilidad.

   ALCANCE (ambos filtros en el WHERE al pie, y aplican a todo lo que cuelga
   de esta vista: la vista de AlertasB1 y la alerta en Python):

     1. SÓLO SERIE 'OCNAC' (compras nacionales). Series en OPOR al 2026-08-06:
            OCNAC -> 23.577 OC   <- la que trae esta vista
            OCINT ->  1.680 OC   <- EXCLUIDA (importaciones)
            'Manual' aparece en el desplegable de B1 pero no tiene documentos.
        Para cambiar de serie basta el literal del WHERE.

     2. SÓLO ABIERTAS, y en los dos niveles del documento:
            OPOR."DocStatus" = 'O'  -> la OC no está cerrada
            OPOR."CANCELED"  = 'N'  -> la OC no está anulada
            POR1."LineStatus"= 'O'  -> la línea no está cerrada
        El tercero es el que importa en las OC parciales: una OC abierta puede
        tener líneas ya recibidas por completo (cerradas), y esas no deben
        constar. Sin ese filtro se cuelan renglones sin nada que recibir.

   Para traer el histórico completo: quitar el WHERE y devolver el JOIN con
   NNM1 a LEFT JOIN.

   Consumo: vía linked server HANAODBC desde AlertasB1 (OPENQUERY). Por eso
   los campos de texto libre (Nombre_Proveedor, Ref_Proveedor, Descripcion,
   Comentarios) se limpian de CR (CHAR(13)), LF (CHAR(10)) y del separador
   '~': OPOR."Comments" trae saltos de línea reales y rompen el parseo de
   sqlcmd -s ~ (una fila se parte en varias líneas de salida).

   Fechas expuestas como DATE (no TIMESTAMP): probado por OPENQUERY, llega a
   SQL Server como 'date' y sqlcmd la imprime 'YYYY-MM-DD' sin hora.

   OJO CON EL CAST DE LOS TEXTOS: el REPLACE anidado devuelve en HANA un
   string de longitud indefinida y MSDASQL lo mapea a NTEXT en SQL Server.
   Sobre NTEXT fallan LEFT(), SUBSTRING() y las comparaciones:
       "Argument data type ntext is invalid for argument 1 of left function"
   Por eso cada REPLACE va envuelto en CAST(... AS NVARCHAR(n)) con la
   longitud real del campo en B1 (CardName/NumAtCard/Dscription 200,
   Comments 254). Así llegan como NVARCHAR y se pueden recortar y filtrar.

   Notas de campos, verificadas contra producción (2026-08-06):
     · Estado_OC     : CANCELED='Y' -> Cancelada; DocStatus 'C'/'O'.
     · Cantidad_Recibida = Quantity - OpenQty (POR1 no guarda el recibido).
     · Documento_Base: POR1."BaseType" 1470000113 = Solicitud de Compra (OPRQ),
                       540000006 = Oferta de Compra (OPQT). Únicos valores
                       presentes junto con -1.
     · Documento_Destino: POR1."TargetType" 20 = Entrada de Mercancías (OPDN),
                       18 = Factura de Proveedores (OPCH). Únicos presentes.
     · Comprador     : OPOR."SlpCode" está en -1 en el 100% de las OC abiertas
                       (no se usa el empleado de compras); se mapea a
                       'Sin asignar'. El dato útil de persona es Creado_Por
                       (OUSR."U_NAME", el usuario que registró la OC).
     · Dias_Atraso   : líneas cuya ShipDate ya pasó. 0 en el resto (no se
                       usan negativos).

   NO se filtra por "Cantidad_Pendiente" > 0 porque es redundante: verificado
   en producción, las 376 líneas abiertas tienen saldo, con OpenQty mínimo 1.
   B1 cierra la línea (LineStatus 'C') en cuanto se recibe todo.

   NO hay columnas "Estado_OC" ni "Estado_Linea": con el filtro de arriba
   valdrían 'Abierta' en todas las filas y serían ruido en el Excel.

   Tamaño resultante: ~376 líneas en ~197 OC (foto del 2026-08-06; el dato es
   vivo y se mueve en el día). Por ser un conjunto chico, del lado de
   AlertasB1 alcanza UNA sola vista: ver
   AlertasB1_ORDENES_COMPRA_linked_server.sql.
   ========================================================================= */

CREATE VIEW EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA AS
SELECT
    -- ---------- Identificación / cabecera ----------
    T0."DocEntry"                                        AS "DocEntry",
    IFNULL(T9."SeriesName", '')                          AS "Serie",
    T0."DocNum"                                          AS "Numero_OC",
    CAST(T0."DocDate"    AS DATE)                        AS "Fecha_Contabilizacion",
    CAST(T0."TaxDate"    AS DATE)                        AS "Fecha_Documento",
    CAST(T0."DocDueDate" AS DATE)                        AS "Fecha_Entrega",

    -- ---------- Proveedor y condiciones ----------
    T0."CardCode"                                        AS "Codigo_Proveedor",
    CAST(REPLACE(REPLACE(REPLACE(T0."CardName",
        CHAR(13), ' '), CHAR(10), ' '), '~', ' ')
        AS NVARCHAR(200))                                AS "Nombre_Proveedor",
    CAST(REPLACE(REPLACE(REPLACE(IFNULL(T0."NumAtCard", ''),
        CHAR(13), ' '), CHAR(10), ' '), '~', ' ')
        AS NVARCHAR(200))                                AS "Ref_Proveedor",
    IFNULL(T5."PymntGroup", '')                          AS "Condicion_Pago",
    CASE
        WHEN IFNULL(T0."SlpCode", -1) <= 0 THEN 'Sin asignar'
        ELSE IFNULL(T8."SlpName", 'Sin asignar')
    END                                                  AS "Comprador",
    IFNULL(T7."U_NAME", '')                              AS "Creado_Por",
    T0."DocCur"                                          AS "Moneda",
    CAST(T0."DocRate"  AS DECIMAL(19,6))                 AS "Tasa_Cambio",
    CAST(T0."DocTotal" AS DECIMAL(19,2))                 AS "Total_OC",

    -- ---------- Línea del artículo ----------
    T1."LineNum" + 1                                     AS "Linea",
    T1."ItemCode"                                        AS "Codigo_Articulo",
    CAST(REPLACE(REPLACE(REPLACE(T1."Dscription",
        CHAR(13), ' '), CHAR(10), ' '), '~', ' ')
        AS NVARCHAR(200))                                AS "Descripcion",
    IFNULL(T1."unitMsr", '')                             AS "Unidad",
    T1."WhsCode"                                         AS "Bodega",
    CAST(T1."Quantity" AS DECIMAL(19,4))                 AS "Cantidad_Pedida",
    CAST(T1."Quantity" - T1."OpenQty" AS DECIMAL(19,4))  AS "Cantidad_Recibida",
    CAST(T1."OpenQty"  AS DECIMAL(19,4))                 AS "Cantidad_Pendiente",
    CAST(T1."Price"    AS DECIMAL(19,4))                 AS "Precio_Unitario",
    CAST(T1."LineTotal" AS DECIMAL(19,2))                AS "Total_Linea",
    CAST(T1."OpenSum"   AS DECIMAL(19,2))                AS "Valor_Pendiente",
    CAST(T1."ShipDate" AS DATE)                          AS "Fecha_Entrega_Linea",
    CASE
        WHEN T1."ShipDate" < CURRENT_DATE
        THEN DAYS_BETWEEN(T1."ShipDate", CURRENT_DATE)
        ELSE 0
    END                                                  AS "Dias_Atraso",

    -- ---------- Trazabilidad del documento ----------
    CASE T1."BaseType"
        WHEN 1470000113 THEN 'Solicitud de Compra'
        WHEN 540000006  THEN 'Oferta de Compra'
        ELSE 'Sin documento base'
    END                                                  AS "Documento_Base",
    CASE T1."TargetType"
        WHEN 20 THEN 'Entrada de Mercancias'
        WHEN 18 THEN 'Factura de Proveedores'
        ELSE 'Pendiente'
    END                                                  AS "Documento_Destino",
    CAST(REPLACE(REPLACE(REPLACE(IFNULL(T0."Comments", ''),
        CHAR(13), ' '), CHAR(10), ' '), '~', ' ')
        AS NVARCHAR(254))                                AS "Comentarios"

FROM EMPAQPLAST_PROD.OPOR T0
INNER JOIN EMPAQPLAST_PROD.POR1 T1 ON T1."DocEntry" = T0."DocEntry"
INNER JOIN EMPAQPLAST_PROD.NNM1 T9 ON T9."Series"   = T0."Series"
LEFT  JOIN EMPAQPLAST_PROD.OCTG T5 ON T5."GroupNum" = T0."GroupNum"
LEFT  JOIN EMPAQPLAST_PROD.OSLP T8 ON T8."SlpCode"  = T0."SlpCode"
LEFT  JOIN EMPAQPLAST_PROD.OUSR T7 ON T7."USERID"   = T0."UserSign"
WHERE T9."SeriesName"  = 'OCNAC'     -- sólo compras nacionales
  AND T0."DocStatus"   = 'O'         -- OC no cerrada
  AND T0."CANCELED"    = 'N'         -- OC no anulada
  AND T1."LineStatus"  = 'O';        -- línea no cerrada (clave en OC parciales)


/* -------------------------------------------------------------------------
   Verificación rápida después de crear la vista
   ------------------------------------------------------------------------- */
-- SELECT COUNT(*) FROM EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA;   -- ~376 líneas
-- Debe devolver una sola fila, 'OCNAC':
-- SELECT DISTINCT "Serie" FROM EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA;
-- Ninguna línea debe venir sin saldo por recibir (debe dar 0):
-- SELECT COUNT(*) FROM EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA
--  WHERE "Cantidad_Pendiente" <= 0;
-- SELECT * FROM EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA
--  ORDER BY "Dias_Atraso" DESC, "Numero_OC" DESC;

/* -------------------------------------------------------------------------
   Permiso para el usuario del linked server (ejecutar como propietario del
   esquema si el usuario ODBC no es el mismo que crea la vista):
   ------------------------------------------------------------------------- */
-- GRANT SELECT ON EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA TO EMPAQPLAST;
