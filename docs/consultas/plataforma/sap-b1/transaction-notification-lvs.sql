ALTER PROCEDURE SBO_SP_TransactionNotification_LVS

(

	in object_type nvarchar(30), 				-- SBO Object Type
	in transaction_type nchar(1),			-- "A]dd, "U]pdate, "D]elete, "C]ancel, C"L]ose
	in num_of_cols_in_key int,
	in list_of_key_cols_tab_del nvarchar(255),
	in list_of_cols_val_tab_del nvarchar(255), 
	-- Return values
	inout error int, -- Result (0 for no error)
	inout error_message nvarchar (200) -- Error string to be displayed
	
)
LANGUAGE SQLSCRIPT
AS
---- Custom Variables
VAUX nvarchar(250);
VP_valor     				INTEGER;
VP_dig_verif  				INTEGER;
VP_TIPO_ID					VARCHAR(50);
VP_CARDTYPE 				VARCHAR(100);
VP_LD_RUC     				VARCHAR(50); 
VP_usuarioupd 			    VARCHAR(100);
VP_num_record  				INTEGER;
VP_id         				VARCHAR(50); 
	 VP_CONTA				VARCHAR(50);
	 VP_TIPO				VARCHAR(50);
	 VP_SERIE				VARCHAR(50);
	 VP_PTO					VARCHAR(50);
	 VP_AUT					VARCHAR(50);
	 VP_FEC_AUT				DATE;
	 VP_TIPO_EMI			VARCHAR(50);

BEGIN


--=======================================================================================
-- STORE PROCEDURE PARA QUE EL AREA DE TI DE LA EMPRESA AGREGUE SUS PROPIAS VALIDACIONES
--=======================================================================================


--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Guia-Datos Guia
--autor			:		DAVID CÁRDENAS
--creado el		:		12-13-2022
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='15' AND (:transaction_type = 'A' or :transaction_type = 'U') 
THEN
    DECLARE VAR1 INT;
     (select COUNT(*)
	    into VAR1
		                       FROM ODLN T0  INNER JOIN 
		                       NNM1 T1 ON T0."Series" = T1."Series" INNER JOIN 
		                       "@SERIES"  T2 ON  T1."Series"=T2."U_SERIE"

                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               T2."U_XML"='Y' AND 
                               (
                               
                               T0."U_SYP_MDTD" is null or 
                               T0."U_SYP_MDRT" is null or  
                               T0."U_SYP_MDNT" is null or 
                               T0."U_SYP_MDVC" is null or  
                               T0."U_SYP_MDPP" is null or  
                               T0."U_SYP_MDPLL" is null or  
                               T0."U_SYP_FECH_INI_TRNS" is null or  
                               T0."U_SYP_FECH_FIN_TRNS" is null or  
                               T0."U_SYP_MOT_TRAS" is null 
                               
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -899;
		error_message := 'SP: Guia Electronica, coloque los datos de la guia';
	END IF;
END IF;

--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Guia-Datos Guia
--autor			:		DAVID CÁRDENAS
--creado el		:		12-13-2022
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='67' AND (:transaction_type = 'A' or :transaction_type = 'U') 
THEN
    DECLARE VAR1 INT;
     (select COUNT(*)
	    into VAR1
		                       FROM OWTR T0  INNER JOIN 
		                       NNM1 T1 ON T0."Series" = T1."Series" INNER JOIN 
		                       "@SERIES"  T2 ON  T1."Series"=T2."U_SERIE"

                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               T2."U_XML"='Y' AND 
                               (
                               
                               T0."U_SYP_MDTD" is null or 
                               T0."U_SYP_MDRT" is null or  
                               T0."U_SYP_MDNT" is null or 
                               T0."U_SYP_MDVC" is null or  
                               T0."U_SYP_MDPP" is null or  
                               T0."U_SYP_MDPLL" is null or  
                               T0."U_SYP_FECH_INI_TRNS" is null or  
                               T0."U_SYP_FECH_FIN_TRNS" is null or  
                               T0."U_SYP_MOT_TRAS" is null 
                               
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -899;
		error_message := 'SP: Guia Electronica, coloque los datos de la guia';
	END IF;
END IF;



--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Procesado Vacío
--autor			:		DAVID CÁRDENAS
--creado el		:		12-13-2022
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='13' AND (:transaction_type = 'A' ) 
THEN
    DECLARE VAR1 INT;
     (select COUNT(*)
	    into VAR1
		                       FROM OINV T0  INNER JOIN 
		                       NNM1 T1 ON T0."Series" = T1."Series" INNER JOIN 
		                       "@SERIES"  T2 ON  T1."Series"=T2."U_SERIE"

                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               T2."U_XML"='Y' AND 
                               (
                               
                               T0."U_SYP_PROCESADO" is NOT null or T0."U_SYP_PROCESADO" !=''
 
                               
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -899;
		error_message := 'SP: El campo procesado debe estar vacío';
	END IF;
END IF;
--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Procesado Vacío
--autor			:		DAVID CÁRDENAS
--creado el		:		12-13-2022
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='18' AND (:transaction_type = 'A' ) 
THEN
    DECLARE VAR1 INT;
     (select COUNT(*)
	    into VAR1
		                       FROM OPCH T0  INNER JOIN 
		                       NNM1 T1 ON T0."Series" = T1."Series" INNER JOIN 
		                       "@SERIES"  T2 ON  T1."Series"=T2."U_SERIE"

                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               T2."U_XML"='Y' AND 
                               (
                               
                               T0."U_SYP_PROCESADO" is NOT null or T0."U_SYP_PROCESADO" !=''
 
                               
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -899;
		error_message := 'SP: El campo procesado debe estar vacío';
	END IF;
END IF;


--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Procesado Vacío
--autor			:		DAVID CÁRDENAS
--creado el		:		12-13-2022
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='14' AND (:transaction_type = 'A' ) 
THEN
    DECLARE VAR1 INT;
     (select COUNT(*)
	    into VAR1
		                       FROM ORIN T0  INNER JOIN 
		                       NNM1 T1 ON T0."Series" = T1."Series" INNER JOIN 
		                       "@SERIES"  T2 ON  T1."Series"=T2."U_SERIE"

                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               T2."U_XML"='Y' AND 
                               (
                               
                               T0."U_SYP_PROCESADO" is NOT null or T0."U_SYP_PROCESADO" !=''
 
                               
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -899;
		error_message := 'SP: El campo procesado debe estar vacío';
	END IF;
END IF;


--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Transferencia de diferente sucursal que la asignada al usuario
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='67' AND (:transaction_type = 'A' /*OR :transaction_type = 'U'*/ ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OWTR T0 INNER JOIN
		                       WTR1 T1 ON T0."DocEntry"=T1."DocEntry" LEFT JOIN 
		                       OWHS T2 ON T1."FromWhsCod"= T2."WhsCode" LEFT JOIN
		                       OUSR T3 ON T0."UserSign" = T3."USERID" LEFT JOIN
		                       OUBR T4 ON T3."Branch" = T4."Code"
		                       

                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               IFNULL(T4."Remarks",'')!='' AND
                               
                               (
                               T4."Name" != IFNULL(T2."Address2",left(T2."WhsCode",3))
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: No puede transferir de un almacen diferente al asignado a su sucursal';
	END IF;
END IF;


--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Tranferencia no permitida por que la solicitud es de consumo
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='67' AND (:transaction_type = 'A' /*OR :transaction_type = 'U'*/ ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OWTR T0 INNER JOIN
		                       WTR1 T1 ON T0."DocEntry"=T1."DocEntry" LEFT JOIN 
		                       (OWTQ T3 INNER JOIN WTQ1 t2 ON T3."DocEntry"=t2."DocEntry") on T1."BaseType"=T3."ObjType" and T1."BaseLine"=T2."LineNum"
								AND T1."BaseEntry"=T2."DocEntry"
                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               
                               (
                               T1."BaseType"= '1250000001' and T3."U_EMPA_T_C" = '2'
                               
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: No puede transferir por que la solicitud es de consumo';
	END IF;
END IF;

--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Obligatorio tipo de solicitud y tipo de formato
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='1250000001' AND (:transaction_type = 'A'  ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OWTQ T0 
                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               
                               (
                               IFNULL(T0."U_EMPA_T_C",'')= '' OR
                               IFNULL(T0."U_EMPA_TIPO",'')= ''
                               )
                               AND T0."U_beas_version" IS NULL -- AÑADIDO PARA EXCLUIR SOLICITUDES GENERADAS POR BEAS
                             
                               
        );
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: Seleccione tipo de traslado y tipo de formato';
	END IF;
END IF;

--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Obligatorio TIPO DE SALIDA
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
/*
IF :object_type ='60' AND (:transaction_type = 'A'  ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OIGE T0 INNER JOIN IGE1 T1 ON T0."DocEntry"=T1."DocEntry"
                               WHERE 
                               T1."BaseType"!='202' and 
                               T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               
                               (
                               IFNULL(T0."U_EMPA_T_S",'')= '' --OR
                               ---IFNULL(T0."U_EMPA_TIPO",'')= ''
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: Seleccione tipo de salida';
	END IF;
END IF;
*/
--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Control de cancelación
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='1250000001' AND (:transaction_type = 'C' ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OWTQ T0 LEFT JOIN
		                       WTQ1 T1 ON T0."DocEntry"=T1."DocEntry"
		                       LEFT JOIN "EMP_CONSUMOS_REALIZADOS" t2 ON 
		                       T0."DocNum"=T2."U_EMPA_S_T"
		                       
                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               
                               (
                               IFNULL(T2."U_EMPA_S_T",'')!= '' 

                               )
                               
        );
        
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: No puede cancelar si ya se realizo el consumo';
	END IF;
END IF;


--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Campos Obligatorios/Solicitud Normal
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='1250000001' AND (:transaction_type = 'A' OR :transaction_type = 'U') 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OWTQ T0 
		                       
                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               T0."U_EMPA_TIPO"='2'
                               and
                               (
                               IFNULL(T0."U_EMPA_EMPL",'')= '' or 
                               IFNULL(T0."U_EMPA_N_SE",'')= '' or
                               IFNULL(T0."U_EMPA_HORA",0)= 0 

                               )
                               
        );
        
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: Solicitud Extraordinaria: Llene Hora,No Servicio,solicitante ';
	END IF;
END IF;


--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Obligatorio No Solicitud
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
/*
IF :object_type ='60' AND (:transaction_type = 'A'  ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OIGE T0 
		                       inner join IGE1 T1 ON T0."DocEntry" = T1."DocEntry"
		                       left join owtq T2 ON T0."U_EMPA_S_T"=T2."DocNum"
                               WHERE 
                               
                               T1."BaseType"!='202' and 
                               T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               
                               (
                               IFNULL(T2."DocNum",0)= 0 --OR
                               ---IFNULL(T0."U_EMPA_TIPO",'')= ''
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: Obligatorio Seleccionar numero de solicitud';
	END IF;
END IF;
*/
--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Consumos de ordenes abiertas
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------

IF :object_type ='60' AND (:transaction_type = 'A' /*OR :transaction_type = 'U'*/ ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OIGE T0 
		                       inner join IGE1 T1 ON T0."DocEntry" = T1."DocEntry"
		                       ---left join owtq T2 ON T1."U_EMPA_S_T"=T0."DocNum"
								left join "EMP_SOLICITUDES_REALIZADAS" T2 
								ON T1."U_EMPA_S_T"= T2."DocNum" and
								T2."ItemCode"= T1."ItemCode" and
								T2."WhsCode"= T1."WhsCode"
								/*T2."OcrCode", 
								T2."OcrCode2", 
								T2."OcrCode3", 
								T2."OcrCode4", 
								T2."OcrCode5" */
								left join "EMP_CONSUMOS_REALIZADOS" T3 
								ON T3."U_EMPA_S_T"= T2."DocNum" and
								T3."ItemCode"=T2."ItemCode" and
								T3."WhsCode"=T2."WhsCode"
								/* 
								T3."OcrCode", 
								T3."OcrCode2", 
								T3."OcrCode3", 
								T3."OcrCode4", 
								T3."OcrCode5" 
								*/
                               WHERE T1."BaseType"!='202' and T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               
                               (
                               ifnull(T2."Quantity",0)-ifnull(T3."Quantity",0)>0
                               )
                               
        );
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: El consumo debe estar enlazado a una orden abierta';
	END IF;
END IF;





--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Control de cancelación
--autor			:		DAVID CÁRDENAS
--creado el		:		16-03-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
/*
IF :object_type ='1250000001' AND (:transaction_type = 'C' ) 
THEN
    DECLARE VAR1 INT;
    
     (select COUNT(*)
	    into VAR1
		                       FROM OWTQ T0 LEFT JOIN
		                       WTQ1 T1 ON T0."DocEntry"=T1."DocEntry"
		                       INNER JOIN "EMP_CONSUMOS_REALIZADOS" t2 ON 
		                       T0."DocNum"=T1."U_EMPA_S_T"
		                       T1."ItemCode" = T2."ItemCode"
								T1."FromWhsCod"=T2."WhsCode"
								T1."OcrCode" = T2."OcrCode"
								T1."OcrCode2"=T2."OcrCode2"
								T1."OcrCode3"=T2."OcrCode3" 
								T1."OcrCode4" =T2."OcrCode4" 
								T1."OcrCode5" = T2."OcrCode5" 
                               WHERE T0."DocEntry" = :list_of_cols_val_tab_del AND 
                               
                               (
                               IFNULL(T0."U_EMPA_T_C",'')= '2' OR
                               
                   				and ifnull(t2."Quantity",0) <ifnull(t1."Quantity",0)
                               )
                               
        );
        
		IF VAR1 > 0
		THEN 
		error := -900;
		error_message := 'SP: No puede cancelar si ya se realizo el consumo';
	END IF;
END IF;
*/

--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		VALIDACIÓN CH POSFECHADO
--autor			:		DAVID CÁRDENAS
--creado el		:		15-11-2019
---modificado por:		
---modificado el:		
--------------------------------------------------------------------------------------------------------------------------------


IF :object_type ='24' AND (:transaction_type = 'A' ) 
THEN
    DECLARE VAR1 INT;
   
     (

select COUNT(*)
	    
	    into VAR1
		
		FROM ORCT T0  --INNER JOIN RCT1 T1 ON T0."DocEntry" = T1."DocNum"
		WHERE 		
		T0."DocEntry"= :list_of_cols_val_tab_del 
		AND TO_DATE(T0."DocDate")> CURRENT_DATE

	);
		
		IF VAR1 > 0
		
		THEN 
		error := -76;
		error_message := 'SP: La fecha difiere a la fecha del registro, guarde como preliminar';
	END IF;
END IF;



--------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Cheques sin SALDO
--autor			:		DAVID CÁRDENAS
--creado el		:		15-02-2022
--modificado por:		
--modificado el:		
--------------------------------------------------------------------------------------------------------------------------------

IF :object_type ='140' AND (:transaction_type = 'A' OR :transaction_type = 'U') 
THEN
    DECLARE VAR1 INT;
     (select COUNT(*)
	    into VAR1
		FROM OPDF T1 
		INNER JOIN PDF2 T2 ON T2."DocNum" = T1."DocEntry"
		LEFT JOIN (SELECT * FROM "LS::CARTERA_TRANSID" (CURRENT_DATE))T3 ON T3."DocEntryFactura"=t2."DocEntry" and T3."NoCuota"=t2."InstId" 
		WHERE T1."DocEntry"= :list_of_cols_val_tab_del AND T1."Canceled" = 'N' and T3."Saldo Con Posfechados"<-0.05);
		IF VAR1 > 0
		THEN 
		error := -4;
		error_message := 'SP: Una de las facturas ya tiene cheques posfechados';
	END IF;
END IF;
 --------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Restriccion Precio en 0 Orden de Venta
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		7-09-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
IF :object_type = '17' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;

    SELECT COUNT(*) INTO VAR1 FROM "ORDR" T0
    INNER JOIN "RDR1" T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE (T1."Price" = 0 OR T1."Price" IS NULL) AND T0."DocEntry" = :list_of_cols_val_tab_del;

    IF VAR1 > 0 THEN
        error := 1;
        error_message := 'SP: El precio debe ser mayor a 0';
    END IF;
END IF;

  --------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Restriccion Precio en 0 Factura
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		7-09-2023
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
IF :object_type = '13' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;

    SELECT COUNT(*) INTO VAR1 FROM "OINV" T0
    INNER JOIN "INV1" T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE (T1."Price" = 0 OR T1."Price" IS NULL) AND T0."DocEntry" = :list_of_cols_val_tab_del;

    IF VAR1 > 0 THEN
        error := 1;
        error_message := 'SP: El precio debe ser mayor a 0';
    END IF;
END IF;

  --------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Campo Obligatorio Proveedor Predeterminado
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		17-01-2024
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;

   SELECT COUNT (T0."ItemCode") INTO VAR1 FROM "OITM" T0
		WHERE T0."ItemType"!='F' AND T0."ItemCode" = list_of_cols_val_tab_del 
   	AND (T0."CardCode" = ''  OR T0."CardCode"  IS NULL) AND T0."ItmsGrpCod" IN (101,104);
		
		IF VAR1 > 0 THEN
		    error := -10000;
		    error_message := 'SP: Por favor ingrese el proveedor predeterminado debe asignarse en la pestana Compras';
		END IF;
END IF;
  --------------------------------------------------------------------------------------------------------------------------------
--id error		:		
--nombre		:		Campo Obligatorio Unidad de medida predeterminada
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		17-01-2024
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;

   SELECT COUNT (T0."ItemCode") INTO VAR1 FROM "OITM" T0
		WHERE T0."ItemType"!='F' AND T0."ItemCode" = list_of_cols_val_tab_del AND (T0."BuyUnitMsr" = ''  OR T0."BuyUnitMsr"  IS NULL) AND T0."ItmsGrpCod" IN (101,104);
		
		IF VAR1 > 0 THEN
		    error := -10001;
		    error_message := 'SP: Por favor ingrese la medida predeterminada en la pestaña compras';
		END IF;
END IF;

----------------------------------------------------------------------------------------------------------------------------------------
--LOVERSOFT 
--id error		:		
--nombre		:		Control que valida la CONDICIÓN (SI,NO) relacionado al proyecto en PEDIDO de compra
--autor			:	    MATEO ARMIJO
--creado el		:		04-12-2023
--modificado por:		Jefferson Vasconez
--modificado el:		4/3/2024
----------------------------------------------------------------------------------------------------------------------------------------
IF :object_type = '22' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;
    DECLARE VAR2 INT;
    
    SELECT 
        COUNT(CASE WHEN T0."U_EMPA_REL_PROYEC" = 'Y' AND (T1."Project" IS NULL OR T1."Project" = '') THEN 1 END) INTO VAR1
    FROM OPOR T0
    INNER JOIN POR1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del;
    
    SELECT 
        COUNT(CASE WHEN T0."U_EMPA_REL_PROYEC" = 'N' AND (T1."Project" IS NOT NULL AND T1."Project" != '') THEN 1 END) INTO VAR2
    FROM OPOR T0
    INNER JOIN POR1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del;
    
    IF VAR1 > 0 THEN 
        error := -203;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES SI, EL CAMPO PROYECTO DEBE SER RELLENADO OBLIGATORIAMENTE';
    END IF;

    IF VAR2 > 0 THEN 
        error := -204;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES NO, EL CAMPO PROYECTO DEBE ESTAR VACÍO';
    END IF;
END IF;
--------------------------------------------------------------------------------------------------------------------------------
--LOVERSOFT 
--id error		:		
--nombre		:		Control que valida la CONDICIÓN (SI,NO) relacionado al proyecto en la SOLICITUD DE COMPRA
--autor			:	    MATEO ARMIJO
--creado el		:		04-12-2023
--modificado por:		Jefferson Vasconez
--modificado el:		11-3-2024
--------------------------------------------------------------------------------------------------------------------------------
IF :object_type = '1470000113' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR2 INT;
    
    SELECT COUNT(*) INTO VAR2
    FROM OPRQ T0
    INNER JOIN PRQ1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
    AND T0."U_EMPA_REL_PROYEC" = 'Y'
    AND COALESCE(T1."Project", '') = '';

    IF VAR2 > 0 THEN 
        error := -200;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES SI, EL CAMPO PROYECTO DEBE SER RELLENADO OBLIGATORIAMENTE';
    END IF;
END IF;
--
IF :object_type = '1470000113' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;
    
    SELECT COUNT(*) INTO VAR1
    FROM OPRQ T0
    INNER JOIN PRQ1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
    AND T0."U_EMPA_REL_PROYEC" = 'N'
    AND (T1."Project" IS NOT NULL AND T1."Project" != '');

    IF VAR1 > 0 THEN 
        error := -201;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES NO, EL CAMPO PROYECTO DEBE ESTAR VACÍO';
    END IF;
END IF;
----------------------------------------------------------------------------------------------------------------------------------------
--LOVERSOFT 
--id error		:		
--nombre		:		Control que valida la CONDICIÓN (SI,NO) relacionado al proyecto en OFERTA DE COMPRA
--autor			:	    MATEO ARMIJO
--creado el		:		04-12-2023
--modificado por:		Jefferson Vásconez
--modificado el:		11-3-2024
----------------------------------------------------------------------------------------------------------------------------------------
IF :object_type = '540000006' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;
    DECLARE VAR2 INT;
    
    SELECT 
        COUNT(CASE WHEN T0."U_EMPA_REL_PROYEC" = 'Y' AND (T1."Project" IS NULL OR T1."Project" = '') THEN 1 END) INTO VAR1
    FROM OPQT T0
    INNER JOIN PQT1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del;
    
    SELECT 
        COUNT(CASE WHEN T0."U_EMPA_REL_PROYEC" = 'N' AND (T1."Project" IS NOT NULL AND T1."Project" != '') THEN 1 END) INTO VAR2
    FROM OPQT T0
    INNER JOIN PQT1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del;
    
    IF VAR1 > 0 THEN 
        error := -205;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES SI, EL CAMPO PROYECTO DEBE SER RELLENADO OBLIGATORIAMENTE';
    END IF;

    IF VAR2 > 0 THEN 
        error := -206;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES NO, EL CAMPO PROYECTO DEBE ESTAR VACÍO';
    END IF;
END IF;
----------------------------------------------------------------------------------------------------------------------------------------
--LOVERSOFT 
--id error		:		
--nombre		:		Control que valida la CONDICIÓN (SI,NO) relacionado al proyecto en FACTURA DE PROVEEDORES
--autor			:	    MATEO ARMIJO
--creado el		:		04-12-2023
--modificado por:		Jefferson Vásconez
--modificado el:		11/3/2024
----------------------------------------------------------------------------------------------------------------------------------------
IF :object_type = '18' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;
    DECLARE VAR2 INT;
    
    SELECT 
        COUNT(CASE WHEN T0."U_EMPA_REL_PROYEC" = 'Y' AND (T1."Project" IS NULL OR T1."Project" = '') THEN 1 END) INTO VAR1
    FROM OPCH T0
    INNER JOIN PCH1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del;
    
    SELECT 
        COUNT(CASE WHEN T0."U_EMPA_REL_PROYEC" = 'N' AND (T1."Project" IS NOT NULL AND T1."Project" != '') THEN 1 END) INTO VAR2
    FROM OPCH T0
    INNER JOIN PCH1 T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del;
    
    IF VAR1 > 0 THEN 
        error := -207;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES SI, EL CAMPO PROYECTO DEBE SER RELLENADO OBLIGATORIAMENTE';
    END IF;

    IF VAR2 > 0 THEN 
        error := -208;
        error_message := 'SP: SI EL CAMPO RELACIONADO AL PROYECTO ES NO, EL CAMPO PROYECTO DEBE ESTAR VACÍO';
    END IF;
END IF;


--===================================================================================================================================
  --------------------------------------------------------------------------------------------------------------------------------
--id error		:		-209
--nombre		:		Campo Obligatorio Provincia-Canton-Parroquia 
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		4-05-2024
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
IF :object_type = '2' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;

    -- Contar registros donde los campos obligatorios estén vacíos o la dirección no sea 'PRINCIPAL'
    SELECT COUNT(*) INTO VAR1 FROM "OCRD" T0
        INNER JOIN "CRD1" T1 ON T0."CardCode" = T1."CardCode" 
        WHERE T0."CardCode" = :list_of_cols_val_tab_del 
		        AND T0."CardType" = 'C'
			       AND (
	                  T1."Address" IS NULL OR T1."Address" = '' 
	                  OR T1."Street" IS NULL OR T1."Street" = ''
	                  OR T1."Block" IS NULL OR T1."Block" = ''
	                  OR T1."City" IS NULL OR T1."City" = ''
	                  OR T1."State" IS NULL OR T1."State" = ''
	                  OR T1."Country" IS NULL OR T1."Country" = '' OR T1."Country" = '-No Country-'
	              );
		       

    IF VAR1 > 0 THEN
        error := -209;
        error_message := 'SP: Todos los campos de dirección (Calle / Numero, Parroquia, Canton, Estado) son obligatorios y no deben estar vacíos. Además, Verifica en PRINCIPAL & ENTREGA.';
    END IF;
END IF;
  ----------------------------------------------------------------------------------------
--id error		:		-210
--nombre		:		Campo PRINCIPAL & ENTREGA OBLIGATORIO
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		4-05-2024
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------
IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE VAR1 INT;

    -- Contar registros donde la dirección NO sea 'PRINCIPAL' ni 'ENTREGA'
    SELECT COUNT(*) INTO VAR1 FROM "OCRD" T0
        INNER JOIN "CRD1" T1 ON T0."CardCode" = T1."CardCode" 
        WHERE T0."CardCode" = :list_of_cols_val_tab_del 
              AND T0."CardType" = 'C'
              AND NOT (T1."Address" = 'PRINCIPAL' OR T1."Address" = 'ENTREGA');
			      
    IF VAR1 > 0 THEN
        error := -210;
        error_message := 'SP: Verifica que el campo de Destinatario de factura sea PRINCIPAL & Destino sea ENTREGA';
    END IF;
END IF;
  ----------------------------------------------------------------------------------------
--id error		:		-211
--nombre		:		Control de descripción de articulo
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		21-06-2024
--modificado por:		
--modificado el:		
IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;

    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
        SELECT COUNT(*) INTO VAR0 
        FROM "OITM" T0
        WHERE T0."ItemCode" = :list_of_cols_val_tab_del 
          AND (T0."ItemName" IS NULL OR T0."ItemName" = '');

        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -211;
            error_message := 'SP: ¡Por favor llene la descripción del Item!';
        END IF;
    END;
END IF;
  ----------------------------------------------------------------------------------------
--id error		:		-212
--nombre		:		Control grupo de articulos
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		21-06-2024
--modificado por:		
--modificado el:		
IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
        SELECT COUNT(*) INTO VAR0 
        FROM "OITM" T0
        WHERE T0."ItemCode" = :list_of_cols_val_tab_del 
          AND (T0."ItmsGrpCod" = 115);
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -212;
            error_message := 'SP: ¡Por favor seleccione un GRUPO DE ARTICULO VALIDO DIFERENTE A *!';
        END IF;
    END;
END IF;
  ----------------------------------------------------------------------------------------
--id error		:		-213
--nombre		:		Control de Grupo Unidad de Medida
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		21-06-2024
--modificado por:		
--modificado el:		
IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
        SELECT COUNT(*) INTO VAR0 
        FROM "OITM" T0
        WHERE T0."ItemCode" = :list_of_cols_val_tab_del 
          AND (T0."UgpEntry" = -1) AND T0."ItmsGrpCod" IN (102,103);
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -213;
            error_message := 'SP: ¡Por favor seleccione la UNIDAD DE MEDIDA diferente a MANUAL!';
        END IF;
    END;
END IF;
----------------------------------------------------------------------------------------
--id error		:		-214
--nombre		:		Control de fechas en certificado de calidad
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		9-07-2024
--modificado por:		Jefferson Vásconez TI EMPAQPLAST
--modificado el:		10-7-2024
-----------------------------------------------------------------------------------------	
IF :object_type = '15' AND (:transaction_type = 'A') THEN
    DECLARE
        VAR0 INT;

    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
         SELECT COUNT(*) INTO VAR0 
        FROM ODLN T0
        INNER JOIN DLN1 T1 ON T1."DocEntry" = T0."DocEntry" AND T0."Series" NOT IN (172,931,121)
      WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
      AND (T1."U_PLG_BATCH_DATE_START" IS NULL 
           OR T1."U_PLG_BATCH_DATE_START" = '') 
      AND (T1."U_PLG_BATCH_DATE_END" IS NULL 
           OR T1."U_PLG_BATCH_DATE_END" = '');
	
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -214;
            error_message := 'SP: ¡Por favor llene los campos de fecha lote Inicio/Fin para el Certificado de Calidad!';
        END IF;
    END;
END IF;
----------------------------------------------------------------------------------------
--id error		:		-214
--nombre		:		Control OBLIGATORIO FORMA DE PAGO
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		31-07-2024
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------	
IF :object_type = '18' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;

    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
         SELECT COUNT(*) INTO VAR0 
        FROM OPCH T0
      WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
      AND (T0."PeyMethod" IS NULL 
           OR T0."PeyMethod" = '');
	
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -215;
            error_message := 'SP: ¡Por favor seleccione un metodo de pago en la pestaña Finanzas¡';
        END IF;
    END;
END IF;
 ----------------------------------------------------------------------------------------
--id error		:		-216
--nombre		:		Control Peso vacio
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		13-09-2024
--modificado por:		
--modificado el:		
/*IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;

    BEGIN
        -- Contar registros
        SELECT COUNT(*) INTO VAR0 
        FROM "OITM" T0
        WHERE T0."ItemCode" = :list_of_cols_val_tab_del 
          AND (T0."IWeight1" IS NULL OR T0."IWeight1" <= 0)
          AND T0."ItmsGrpCod" IN (102,103);

        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -216;
            error_message := 'SP: ¡Por favor llene el peso del articulo en la pestaña inventario!';
        END IF;
    END;
END IF;*/
 ----------------------------------------------------------------------------------------
--id error		:		-217
--nombre		:		Medidas OEE Extrusion
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		3-12-2024
--modificado por:		
--modificado el:		
/*IF :object_type = '4' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;

    BEGIN
        -- Contar registros
        SELECT COUNT(*) INTO VAR0 
        FROM "OITM" T0
        WHERE T0."ItemCode" = :list_of_cols_val_tab_del 
          AND (T0.U_EMPA_ANCHO IS NULL OR T0.U_EMPA_ESPESOR IS NULL OR U_EMPA_DESIDAD IS NULL)
          AND T0."U_ProcesoProductivo" IN (01) AND T0."ItmsGrpCod" IN (102,103);

        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -217;
            error_message := 'SP: ¡Por favor llene los datos para los indicadores OEE! (Ancho/Espesor/Densidad)';
        END IF;
    END;
END IF;*/
 ----------------------------------------------------------------------------------------
--id error		:		-218
--nombre		:		Control de RUTA PARA PRECIO TRANSPORTE EN GUIA
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		16-04-2025
--modificado por:		Jefferson V.
--modificado el:		12-5-2025
IF :object_type = '15' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
        SELECT COUNT(*) INTO VAR0 
        FROM "ODLN" T0
        WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
         AND (
		    (T0."U_EMPA_RUTA" IS NULL OR T0."U_EMPA_RUTA" = '')
		    OR 
		    (T0."U_EMPA_PRECIO_RUTA" IS NULL)
		  );
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -218;
            error_message := 'SP: ¡Por favor seleccione una Ruta y el precio del transporte!';
        END IF;
    END;
END IF;
 ----------------------------------------------------------------------------------------
--id error		:		-219
--nombre		:		Control de RUTA PARA PRECIO TRANSPORTE EN TRANSFERENCIA
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		16-04-2025
--modificado por:		Jefferson V.
--modificado el:		12-5-2025
IF :object_type = '67' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
        SELECT COUNT(*) INTO VAR0 
        FROM "OWTR" T0
       	WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
		  AND (
		    (T0."U_EMPA_RUTA" IS NULL OR T0."U_EMPA_RUTA" = '')
		    OR 
		    (T0."U_EMPA_PRECIO_RUTA" IS NULL)
		  )
		  AND T0."Series" IN (110,27);
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -219;
            error_message := 'SP: ¡Por favor seleccione una Ruta con TRANSGYE / TRANSUIO! o el precio correspondiente';
        END IF;
    END;
END IF;
 ----------------------------------------------------------------------------------------
--id error		:		-220
--nombre		:		Control de Socio Negocios Email General / Contacto
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		16-04-2025
--modificado por:		
--modificado el:		
IF :object_type = '2' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
        SELECT COUNT(*) INTO VAR0 
        FROM "OCRD" T0
        WHERE T0."CardCode" = :list_of_cols_val_tab_del 
         AND (T0."E_Mail" IS NULL OR T0."E_Mail" = '');
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -220;
            error_message := 'SP: ¡Por favor registre email en General / Persona Contacto!';
        END IF;
    END;
END IF;

 ----------------------------------------------------------------------------------------
--id error		:		-221
--nombre		:		Control de Socio Negocios Banco Proveedor para 
--						Pagos en el Asistente Pagos
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		16-04-2025
--modificado por:		
--modificado el:		
IF :object_type = '2' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        SELECT COUNT(*) INTO VAR0
        FROM "OCRD" T0
        LEFT JOIN "OCRB" T1 ON T1."CardCode" = T0."CardCode"
        WHERE T0."CardCode" = :list_of_cols_val_tab_del
          AND T0."CardType" = 'S'
          AND (T1."BankCode" IS NULL OR T1."BankCode" = '')
          AND (T1."Account" IS NULL OR T1."Account" = '');
          
        IF VAR0 > 0 THEN
            error := -221;
            error_message := 'SP: ¡Por favor llene los campos de Banco de Socio de Negocios de Proveedor!';
        END IF;
    END;
END IF;
 ----------------------------------------------------------------------------------------
--id error		:		-222
--nombre		:		Control de PLACA DEL VEHICULO
--autor			:		JEFFERSON VÁSCONEZ IT EMPAQPLAST
--creado el		:		12-05-2025
--modificado por:		
--modificado el:		
IF :object_type = '15' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
        SELECT COUNT(*) INTO VAR0 
        FROM "ODLN" T0
        WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
         AND (T0."U_SYP_MDVC" IS NULL OR T0."U_SYP_MDVC" = '');
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -222;
            error_message := 'SP: ¡Por favor llene la placa del vehiculo!';
        END IF;
    END;
END IF;

----------------------------------------------------------------------------------------
--id error		:		-223
--nombre		:		Control campo bloqueado mayor a 0
--autor			:		CHRISTIAN MURILLO
--creado el		:		23-12-2025
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------	
IF :object_type = '17' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;

    BEGIN
        -- Contar registros donde ItemCode coincide y ItemName es nulo o vacío
         SELECT COUNT(*) INTO VAR0 
        FROM ORDR T0
      INNER JOIN RDR1 T1 ON T0."DocEntry" = T1."DocEntry"
      WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
      AND T1."DiscPrcnt" > 0;
	
        -- Si se encuentran registros, establecer el error
        IF VAR0 > 0 THEN
            error := -223;
            error_message := 'SP: ¡No se puede agregar un descuento a nivel del detalle en este documento¡';
        END IF;
    END;
END IF;

----------------------------------------------------------------------------------------
--id error		:		-224
--nombre		:		Control de fecha en retencion
--autor			:		JEFFERSON VÁSCONEZ 
--creado el		:		12-01-2026
--modificado por:		
--modificado el:		
-----------------------------------------------------------------------------------------	
-- OBJETO: 18 (Factura de Proveedores)
IF :object_type = '18' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE cnt INT;
    SELECT COUNT(*) INTO cnt
    FROM OPCH T0
    WHERE T0."DocEntry" = :list_of_cols_val_tab_del
      -- 1. Condición disparadora: Solo si el usuario marcó "SI" en Aplicar Retención
      AND IFNULL(T0."U_A_APLICARR", 'NO') = 'SI'
      -- 2. Validación de Campos (Cualquiera de los dos que falle, dispara el error)
      AND (
            -- A) Validación Fecha de Retención: Debe ser igual a la Fecha de Creación
            (T0."U_F_RETENCION" IS NULL OR T0."U_F_RETENCION" <> T0."CreateDate")
            
            OR            
            -- B) Validación Fecha de Caducidad: Debe ser igual a la Fecha de Creación
            (T0."U_F_CADUCIDAD" IS NULL OR T0."U_F_CADUCIDAD" <> T0."CreateDate")
      );
    IF :cnt > 0 THEN
        error := -224;
        error_message := 'SP: Las fechas de Retención y Caducidad son obligatorias, deben ser la FECHA ACTUAL y NO pueden modificarse después.';
    END IF;
END IF;

-----------------------------------------------------------------------------------------
--id error      :   -225
--nombre        :   Control de selección tipo de transporte
--autor         :   CHRISTIAN MURILLO
--creado el     :   16-04-2026
--modificado por:   Jefferson Vásconez
--modificado el :   09-05-2026
-----------------------------------------------------------------------------------------
-- OBJETO: 15 (Guia de Entrega)
IF :object_type = '15' AND (:transaction_type = 'A' OR :transaction_type = 'U') THEN
    DECLARE
        VAR0 INT;
    BEGIN
        SELECT COUNT(*) INTO VAR0 
        FROM "ODLN" T0
        WHERE T0."DocEntry" = :list_of_cols_val_tab_del 
         AND (T0."U_EMPA_TIPO_TRANSPORTE" IS NULL OR T0."U_EMPA_TIPO_TRANSPORTE" = '');
        
        IF VAR0 > 0 THEN
            error := -225;
            error_message := 'SP: ¡Por favor seleccione el tipo de transporte!';
        END IF;
    END;
END IF;

-- ============================================================
-- Objeto 17 = ORDR | Evento A = Add
-- DocDueDate ya incluye el crédito (GroupNum, ej. 90 DIAS)
-- AvrageLate (SMALLINT)   = excedente en días | OCRD estándar
-- U_EMPA_BLOQ_CARTER (NVARCHAR 1) = check de bloqueo, 'Y'/'N'
-- Exige saldo real pendiente: (DocTotal - PaidToDate) > 0
--id error		:		-226
--nombre		:		Bloqueo de PEDIDOS por cartera vencida + excedente
--autor			:		JEFFERSON VÁSCONEZ
--creado el		:		30-06-2026
--modificado por:		
--modificado el:	
-- ============================================================
   IF :object_type = '17' AND :transaction_type = 'A' THEN

      DECLARE v_CardCode NVARCHAR(15);
      DECLARE v_Bloqueo  NVARCHAR(1);
      DECLARE v_Exced    SMALLINT;
      DECLARE v_Vencidas INT;
      DECLARE v_Saldo    DECIMAL(19,2);
      DECLARE v_DocNum   INT;
      DECLARE v_DiasVenc INT;

      SELECT "CardCode"
        INTO v_CardCode
        FROM ORDR
       WHERE "DocEntry" = CAST(:list_of_cols_val_tab_del AS INTEGER);

      SELECT IFNULL("U_EMPA_BLOQ_CARTER", 'N'),
             IFNULL("AvrageLate", 0)
        INTO v_Bloqueo, v_Exced
        FROM OCRD
       WHERE "CardCode" = :v_CardCode;

      IF :v_Bloqueo = 'Y' THEN

         -- Resumen: cuántas facturas vencidas y saldo total vencido
         SELECT COUNT(*),
                IFNULL(SUM(T0."DocTotal" - T0."PaidToDate"), 0)
           INTO v_Vencidas, v_Saldo
           FROM OINV T0
          WHERE T0."CardCode"  = :v_CardCode
            AND T0."DocStatus" = 'O'
            AND (T0."DocTotal" - T0."PaidToDate") > 0
            AND CURRENT_DATE > ADD_DAYS(T0."DocDueDate", :v_Exced);

         IF :v_Vencidas > 0 THEN

            -- Factura más antigua: número y días de vencimiento
            SELECT TOP 1
                   T0."DocNum",
                   DAYS_BETWEEN(ADD_DAYS(T0."DocDueDate", :v_Exced), CURRENT_DATE)
              INTO v_DocNum, v_DiasVenc
              FROM OINV T0
             WHERE T0."CardCode"  = :v_CardCode
               AND T0."DocStatus" = 'O'
               AND (T0."DocTotal" - T0."PaidToDate") > 0
               AND CURRENT_DATE > ADD_DAYS(T0."DocDueDate", :v_Exced)
             ORDER BY T0."DocDueDate" ASC;

            error := -216;
            error_message := N'Cartera vencida. Facturas vencidas: ' || :v_Vencidas
                          || N' | Saldo pendiente: ' || TO_DECIMAL(:v_Saldo, 19, 2)
                          || N' | Fact. mas antigua: ' || :v_DocNum
                          || N' (' || :v_DiasVenc || N' dias vencida). No se permite el pedido.';
         END IF;
      END IF;
   END IF;
-- Objeto 15 = ODLN (Entrega)  | Objeto 67 = OWTR (Transferencia stock)
-- Evento A = Add  |  Evento U = Update
-- UDFs: U_PalletProcesado, U_PalletCantidad, U_ClienteCod, U_TipoMov, U_EntregaRef
-- U_PalletProcesado: N=Pendiente | P=En proceso | Y=Completado | E=Error | A=Anulado | X=Exonerado
-- Alta entrega (A): solo N o X. Update: bloquea UDF si estado anterior Y o A (excepciones n8n).
-- id error    : -217 (ODLN add) | -218 (ODLN update) | -219 (OWTR update)
-- nombre       : Control UDF Pallets — TransferenciasAutomaticas
-- autor        : JEFFERSON VÁSCONEZ
-- creado el    : 22-06-2026
-- modificado por: Jefferson Vásconez
-- modificado el: 05-07-2026
-- ============================================================
-- ------------------------------------------------------------
-- Objeto 15 = ODLN | Evento A = Add
-- Al crear entrega: U_PalletProcesado solo Pendiente (N) o Exonerado (X)
-- id error: -217
-- ------------------------------------------------------------
IF :object_type = '15' AND :transaction_type = 'A' THEN
    DECLARE
        VAR0 INT;
        SELECT COUNT(*) INTO VAR0
        FROM ODLN T0
        WHERE T0."DocEntry" = :list_of_cols_val_tab_del
          AND COALESCE(T0."U_PalletProcesado", '') NOT IN ('N', 'X');

        IF VAR0 > 0 THEN
            error := -217;
            error_message := 'SP: Al crear la entrega seleccione Estado Trans. Pallet Pendiente (N) o Exonerado (X). El campo es obligatorio.';
        END IF;
END IF;

-- ------------------------------------------------------------
-- Objeto 15 = ODLN | Evento U = Update
-- No modificar UDF de pallets si estado anterior es Completado (Y) o Anulado (A)
-- id error: -218
-- ------------------------------------------------------------
IF :object_type = '15' AND :transaction_type = 'U' THEN
    DECLARE
        VAR0 INT;
        SELECT COUNT(*) INTO VAR0
        FROM ODLN T0
        INNER JOIN ADOC T1
            ON  T1."ObjType"   = 15
            AND T1."DocEntry"  = T0."DocEntry"
            AND T1."LogInstanc" = (
                SELECT MAX(T2."LogInstanc")
                FROM ADOC T2
                WHERE T2."ObjType"  = 15
                  AND T2."DocEntry" = T0."DocEntry"
            )
        WHERE T0."DocEntry" = :list_of_cols_val_tab_del
          AND COALESCE(T1."U_PalletProcesado", 'N') IN ('Y', 'A')
          AND (
                 COALESCE(T0."U_PalletProcesado", 'N') <> COALESCE(T1."U_PalletProcesado", 'N')
              OR COALESCE(T0."U_PalletCantidad", 0)  <> COALESCE(T1."U_PalletCantidad", 0)
              OR COALESCE(T0."U_ClienteCod", '')     <> COALESCE(T1."U_ClienteCod", '')
              OR COALESCE(T0."U_TipoMov", '')        <> COALESCE(T1."U_TipoMov", '')
              OR COALESCE(T0."U_EntregaRef", '')     <> COALESCE(T1."U_EntregaRef", '')
          )
          -- Excepción 1: anulación posterior a completado (Y -> A, resetea cantidad)
          AND NOT (
                 COALESCE(T1."U_PalletProcesado", 'N') = 'Y'
             AND COALESCE(T0."U_PalletProcesado", 'N') = 'A'
             AND COALESCE(T0."U_PalletCantidad", 0) = 0
             AND COALESCE(T0."U_ClienteCod", '')     = COALESCE(T1."U_ClienteCod", '')
             AND COALESCE(T0."U_TipoMov", '')        = COALESCE(T1."U_TipoMov", '')
          )
          -- Excepción 2: cancelación de documento posterior a completado (Y -> P, CANCELED = Y)
          AND NOT (
                 COALESCE(T1."U_PalletProcesado", 'N') = 'Y'
             AND COALESCE(T0."U_PalletProcesado", 'N') = 'P'
             AND T0."CANCELED" = 'Y'
             AND COALESCE(T0."U_PalletCantidad", 0)  = COALESCE(T1."U_PalletCantidad", 0)
             AND COALESCE(T0."U_ClienteCod", '')     = COALESCE(T1."U_ClienteCod", '')
             AND COALESCE(T0."U_TipoMov", '')        = COALESCE(T1."U_TipoMov", '')
             AND COALESCE(T0."U_EntregaRef", '')     = COALESCE(T1."U_EntregaRef", '')
          );
          -- Confirmado: no existe excepción para transicionar hacia Exonerado (X)
          -- ni ningún otro estado cuando el anterior es Y o A. Regla de negocio:
          -- una vez Completado o Anulado, no se permite ningún cambio de UDF
          -- de pallets salvo las excepciones explícitas anteriores (Y->A y
          -- cancelación Y->P).

        IF VAR0 > 0 THEN
            error := -218;
            error_message := 'SP: En Completado (Y) o Anulado (A) no puede modificar para el estado de Pallets.';
        END IF;
END IF;

-- ------------------------------------------------------------
-- Objeto 67 = OWTR | Evento U = Update
-- No modificar UDF de pallets si estado anterior es Completado (Y) o Anulado (A)
-- id error: -219
-- ------------------------------------------------------------
IF :object_type = '67' AND :transaction_type = 'U' THEN
    DECLARE
        VAR0 INT;
        SELECT COUNT(*) INTO VAR0
        FROM OWTR T0
        INNER JOIN ADOC T1
            ON  T1."ObjType"   = 67
            AND T1."DocEntry"  = T0."DocEntry"
            AND T1."LogInstanc" = (
                SELECT MAX(T2."LogInstanc")
                FROM ADOC T2
                WHERE T2."ObjType"  = 67
                  AND T2."DocEntry" = T0."DocEntry"
            )
        WHERE T0."DocEntry" = :list_of_cols_val_tab_del
          AND COALESCE(T1."U_PalletProcesado", 'N') IN ('Y', 'A')
          AND (
                 COALESCE(T0."U_PalletProcesado", 'N') <> COALESCE(T1."U_PalletProcesado", 'N')
              OR COALESCE(T0."U_PalletCantidad", 0)  <> COALESCE(T1."U_PalletCantidad", 0)
              OR COALESCE(T0."U_ClienteCod", '')     <> COALESCE(T1."U_ClienteCod", '')
              OR COALESCE(T0."U_TipoMov", '')        <> COALESCE(T1."U_TipoMov", '')
              OR COALESCE(T0."U_EntregaRef", '')     <> COALESCE(T1."U_EntregaRef", '')
          )
          AND NOT (
                 COALESCE(T1."U_PalletProcesado", 'N') = 'Y'
             AND COALESCE(T0."U_PalletProcesado", 'N') = 'P'
             AND COALESCE(T0."U_PalletCantidad", 0)  = COALESCE(T1."U_PalletCantidad", 0)
             AND COALESCE(T0."U_ClienteCod", '')     = COALESCE(T1."U_ClienteCod", '')
             AND COALESCE(T0."U_TipoMov", '')        = COALESCE(T1."U_TipoMov", '')
             AND COALESCE(T0."U_EntregaRef", '')     = COALESCE(T1."U_EntregaRef", '')
          );

        IF VAR0 > 0 THEN
            error := -219;
            error_message := 'SP: En Completado (Y) o Anulado (A) no puede modificar para el estado de Pallets.';
        END IF;
END IF;
--===FIN======================================================
--============================================================
END;


