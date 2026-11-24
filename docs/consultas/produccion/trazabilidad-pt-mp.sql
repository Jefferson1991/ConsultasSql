/* =========================================================================
   Reporte_Trazabilidad_PT_MP (corregido)
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA / Beas
   Propósito: Trazabilidad PT → MP con lote y marca realmente consumidos
   Bug original: Marca_MP/Lote_MP salían de MAX(OBTN.AbsEntry) por ítem
                 (último lote creado), no del lote de la salida de mercancías.
   Corrección: IGE1 → OITL → ITL1 → OBTN (DocType 60)
   Validado: OT 11040 / MPRPFR00001 → WANKAI (no RAMAPET 762675)
   Despliegue: reemplazar query OUQR "Reporte_Trazabilidad_PT_MP"
   ========================================================================= */

SELECT DISTINCT
	T0."ENDZEIT" AS "Fecha_Prod",
	T0."BELNR_ID" AS "Lote_PT",
	T0."ItemCode" AS "Codigo_PT",
	T0."ItemName" AS "Nombre_PT",
	T0."MENGE_VERBRAUCH" AS "Cant_Planificada",
	T0."GEL_MENGE" AS "Cant_Producida",
	T2."ItemCode" AS "Codigo_MP",
	T2."Dscription" AS "Nombre_MP",
	B."DistNumber" AS "Lote_MP",
	B."SysNumber",
	B."MnfSerial" AS "Marca_MP",
	T2."Quantity" AS "Cantidad_MP_Consumida"
FROM BEAS_FTPOS T0
INNER JOIN IGE1 T2
	ON T0."BELNR_ID" = T2."U_beas_belnrid"
	AND T2."U_beas_belposid" = T0."BELPOS_ID"
INNER JOIN OITM T3
	ON T2."ItemCode" = T3."ItemCode"
INNER JOIN OITL I
	ON I."DocEntry" = T2."DocEntry"
	AND I."DocLine" = T2."LineNum"
	AND I."DocType" = 60
INNER JOIN ITL1 L
	ON L."LogEntry" = I."LogEntry"
INNER JOIN OBTN B
	ON B."AbsEntry" = L."MdAbsEntry"
WHERE T3."ItmsGrpCod" IN (101, 102, 103)
ORDER BY
	T0."BELNR_ID" DESC,
	T2."ItemCode" ASC,
	B."DistNumber" ASC;
