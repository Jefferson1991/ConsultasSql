-- ============================================================
-- Objeto 17 = ORDR | Evento A = Add
-- DocDueDate ya incluye el crédito (GroupNum, ej. 90 DIAS)
-- AvrageLate (SMALLINT)   = excedente en días | OCRD estándar
-- U_EMPA_BLOQ_CARTER (NVARCHAR 1) = check de bloqueo, 'Y'/'N'
-- Exige saldo real pendiente: (DocTotal - PaidToDate) > 0
--id error		:		-226
--nombre		:		Bloqueo de PEDIDOS por cartera vencida + excedente
--autor			:		JEFFERSON VÁSCONEZ
--creado el		:		19-06-2026
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
