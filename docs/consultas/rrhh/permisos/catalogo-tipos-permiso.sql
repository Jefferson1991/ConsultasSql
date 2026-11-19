SELECT
    m.C_NOM      AS categoria,
    d.CD_ID      AS codigo,
    d.CD_NOM     AS tipo_permiso,
    d.CD_PAGADO  AS pagado   -- 0 = sin paga, 1 = con paga
FROM dbo.TBL_CAT_MAESTRO m
INNER JOIN dbo.TBL_CAT_DETALLE d
    ON d.CD_CAT = m.C_ID
WHERE m.C_ID = 13
ORDER BY d.CD_NOM;


SELECT
    m.C_ID                          AS id_categoria,
    m.C_NOM                         AS categoria,
    m.C_FLAG                        AS categoria_activa,
    d.CD_ID                         AS codigo_tipo,
    d.CD_NOM                        AS nombre_tipo,
    d.CD_CAT                        AS id_categoria_detalle,
    d.CD_FLAG,
    d.CD_FDES,
    d.CD_VDES,
    d.CD_VTIEMPO,
    d.CD_PAGADO,                    -- 0 = sin paga, 1 = con paga
    d.CD_TMAX,
    d.CD_TPER
FROM dbo.TBL_CAT_MAESTRO m
INNER JOIN dbo.TBL_CAT_DETALLE d
    ON d.CD_CAT = m.C_ID
ORDER BY m.C_ID, d.CD_ID;



SELECT
    m.C_NOM                              AS categoria,
    cd.CD_ID                             AS codigo_tipo,
    cd.CD_NOM                            AS nombre_catalogo,      -- "PERMISO SIN PAGA"
    cd.CD_PAGADO                         AS catalogo_pagado,      -- 0 o 1 (proveedor)
    p.E_EMPID,
    p.E_FINICIO,
    p.E_FPAG                             AS permiso_paga,         -- 0 o 1 (Time)
    CASE p.E_FPAG
        WHEN 1 THEN 'CON PAGA'
        ELSE 'SIN PAGA (Permiso No Pagado)'
    END                                  AS texto_pantalla_time,
    CASE
        WHEN cd.CD_PAGADO = p.E_FPAG THEN 'OK - COINCIDEN'
        ELSE 'ERROR - NO COINCIDEN'
    END                                  AS validacion
FROM dbo.TBL_PERM_AUS p
INNER JOIN dbo.TBL_CAT_DETALLE cd
    ON cd.CD_ID = p.E_TIPOP AND cd.CD_CAT = p.E_TIPOM
INNER JOIN dbo.TBL_CAT_MAESTRO m
    ON m.C_ID = cd.CD_CAT
WHERE p.E_TIPOP = 'SP'
  AND p.E_TIPOM = 13
  AND p.E_FINICIO >= '2026-01-01'
ORDER BY validacion DESC, p.E_FINICIO DESC;