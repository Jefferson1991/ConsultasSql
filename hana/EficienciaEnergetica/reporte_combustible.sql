CREATE VIEW SB1_VIEW_CONSUMO_COMBUSTIBLES_EFICIENCIA_ENERGETICA AS 
SELECT  
T1."DocDate",
T1."DocNum",
--T0."ItemCode",
T0."Dscription",	
T0."Quantity",	
T0."Price",	
T0."LineTotal",	
T0."WhsCode",
T0."OcrCode",
T0."OcrCode2",	
T0."OcrCode3",	
T0."OcrCode4",	
T0."UomCode"
FROM IGE1 T0 
INNER JOIN OIGE T1 ON T0."DocEntry" = T1."DocEntry" 
WHERE T0."AcctCode" IN ('51020501','62022004') AND T0."ItemCode" IN ('RLMAVV0009','RLMAVV0004') 



