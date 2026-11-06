/* =========================================================================
   REPORTE_DATOS_MAESTROS_ARTICULOS
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
   Propósito: artículos activos, con grupo, unidad de medida, fecha y
              usuario de creación y fecha y usuario de actualización.
              Pedido de Diego Morales, 2026-11-06.
   Supuestos verificados (2026-11-06, producción):
     - Solo artículos activos: validFor = 'Y' y frozenFor = 'N'.
     - Sin activos fijos. AssetItem no se usa en esta base.
       Se excluye el tipo SAP 'F', los grupos 106 ACTIVOS FIJOS y
       107 ACTIVOS DE CONTROL, y los códigos AF%.
       Verificado: 10.502 filas, una por artículo.
     - UserSign crea y UserSign2 actualiza.
     - Unidad de medida: código oficial (OUOM). Si no tiene, el texto
       de inventario (InvntryUom).
   Despliegue: consulta de lectura. No crea vista.
   ========================================================================= */

SELECT
    T0."ItemCode"                AS "Codigo",
    T0."ItemName"                AS "Descripcion",
    G."ItmsGrpNam"               AS "GrupoArticulo",
    COALESCE(
        NULLIF(UI."UomCode", ''),
        NULLIF(T0."InvntryUom", '')
    )                            AS "UnidadMedida",
    CAST(T0."CreateDate" AS DATE) AS "FechaCreacion",
    CU."USER_CODE"               AS "UsuarioCreacion",
    CU."U_NAME"                  AS "NombreUsuarioCreacion",
    CAST(T0."UpdateDate" AS DATE) AS "FechaActualizacion",
    UU."USER_CODE"               AS "UsuarioActualizacion",
    UU."U_NAME"                  AS "NombreUsuarioActualizacion"
FROM OITM T0
INNER JOIN OITB G
    ON G."ItmsGrpCod" = T0."ItmsGrpCod"
LEFT JOIN OUOM UI
    ON UI."UomEntry" = T0."IUoMEntry"
LEFT JOIN OUSR CU
    ON CU."USERID" = T0."UserSign"
LEFT JOIN OUSR UU
    ON UU."USERID" = T0."UserSign2"
WHERE T0."validFor" = 'Y'
  AND T0."frozenFor" = 'N'
  AND T0."ItemType" <> 'F'
  AND T0."ItmsGrpCod" NOT IN (106, 107)
  AND T0."ItemCode" NOT LIKE 'AF%'
ORDER BY
    T0."ItemCode";
