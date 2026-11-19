# Ausentismo — lo que hay que usar

Solo estos dos scripts. Todo lo demás en `sqlserver/rrhh/` es apoyo o versiones
anteriores.

## Orden de ejecución

| # | Qué | Servidor | Base |
|---|-----|----------|------|
| 1 | `ausentismo_1_vistas_en_tcontrol.sql` | `SRV-BIOM-001\SQLEXPRESS2008R2` | **TCONTROL** |
| 2 | `ausentismo_2_consumo_en_th.sql` | `SRV-APP\SQLEXPRESS` (192.168.20.15) | **TH** |
| 3 | `EXEC dbo.sp_th_cargar_ausentismo;` | `SRV-APP\SQLEXPRESS` | **TH** |

Primero el 1, siempre. El 2 falla si el 1 no corrió.

**El paso 3 hay que agendarlo cada noche en SQL Agent.** Sin esa carga las
tablas quedan vacías y el tablero no muestra nada.

## Por qué la lógica está partida entre los dos servidores

`SRV-BIOM-001` es SQL Server 2008 R2 **Express**, con tope de 1 GB de memoria.
Medido en ese servidor:

| Consulta | Resultado |
|---|---|
| `vw_th_novedades` completa | 23.525 filas · 0,25 s |
| `vw_th_timbradas` completa | 734.234 filas · 9,0 s |
| Cruzar las dos a grano de día | **expira** |

Entrega cada vista rápido, pero no las cruza. Así que cada servidor hace lo
que puede hacer bien: TCONTROL resuelve la lógica de negocio y entrega dos
flujos planos; TH los guarda, les pone índices y hace el cruce en local.

El mismo cruce que expiraba allá, aquí tarda **1,75 s sobre 747.632 filas**.

Como efecto secundario esto **congela el historial**: al guardar la foto cada
noche, un periodo cerrado deja de moverse cuando alguien edita una marcación
vieja. Era el único problema que la arquitectura de solo vistas no resolvía.

**Sin separadores `GO`.** Cada sentencia termina en `;` y el cliente las manda
una por una. En DBeaver: **Ejecutar script (Alt+X)**, no Ctrl+Enter.

Si el paso 1 falla al crear, es permisos: `ocaccess` puede no tener CREATE VIEW
en TCONTROL. Lo ejecuta el administrador de OnlyControl y luego se corren los
cinco `GRANT SELECT` del final de ese archivo.

## Qué queda creado

**En TCONTROL** — aquí vive toda la lógica, para que los joins se resuelvan en
el servidor de origen y no viajen las tablas por el linked server:

**En TCONTROL** — cinco vistas, toda la lógica de negocio, sin una sola tabla
nueva:

| Vista | Qué es |
|-------|--------|
| `vw_th_novedades` | Permisos y ausencias declaradas. Una fila por novedad. |
| `vw_th_timbradas` | Asistencia diaria y cumplimiento. Una fila por día. |
| `vw_th_jornada_modalidad` | Jornada real de cada modalidad por día de la semana. |
| `vw_th_catalogo_novedad` | El Catálogo de Novedades tal cual. |
| `vw_th_empleado` | La nómina completa, sin el filtro que borra el historial. |

**En TH** — la foto local y el cruce:

| Objeto | Qué es |
|--------|--------|
| **`vw_th_ausentismo`** | **La que consume Power BI.** Una fila por empleado y día, con un solo número de horas. Reemplaza a `fact_ausentismo`. |
| `stg_th_novedades` · `stg_th_timbradas` | La foto del origen. Se recargan enteras cada noche. |
| `stg_th_nomina` | Una fila por persona y periodo en que cobró rol, con los conceptos 01, 41, 81 y 85: los mismos del denominador. Alimenta `En_Nomina`. Se agrega en MySQL con `OPENQUERY`. |
| `sp_th_cargar_ausentismo` | La carga. Va en SQL Agent. |
| `vw_th_novedades` · `vw_th_timbradas` | El detalle, ya sobre la foto local. |
| `vw_th_catalogo_novedad` · `vw_th_jornada_modalidad` | Siguen leyendo **en vivo** del origen: son chicos y deben reflejar de inmediato lo que TH cambie en Time Control. |

Las dos tablas no duplican ningún catálogo: son la foto de los hechos, que es
lo que Power BI necesita.

## Power BI apunta a `vw_th_ausentismo`, no a las otras dos

`vw_th_novedades` y `vw_th_timbradas` **no se pueden unir**: tienen grano
distinto. Medido sobre agosto 2026, novedades trae 212 filas que representan
1.140 días (un permiso llega a 28 días en una sola fila) mientras timbradas
trae 4.662 filas de un día cada una. Y los días de permiso ya aparecen en
timbradas con `Estado_Dia = 'Permiso'`: unirlas sería doble conteo. Ese era
exactamente el defecto del `fact_ausentismo` original.

Tampoco basta un LEFT JOIN desde timbradas: la mitad de los días de permiso no
generan marcación. En agosto 2026, de 1.082 días de vacaciones 548 no tienen
fila, y de 25 días de licencia por enfermedad, 20 tampoco.

`vw_th_ausentismo` resuelve las dos cosas con un FULL OUTER JOIN a grano de
día. Todo el historial son **747.632 filas en 1,75 s**: 56.741 con marcación y
novedad, 677.493 solo marcación y 13.398 solo novedad — estas últimas son las
que un LEFT JOIN habría perdido.

Verificado sobre agosto 2026 (2,49 s):

| Clasificación | Origen | Días | Horas |
|---|---|---|---|
| Justificado - pagado | Marcación y novedad | 652 | 6.182,11 |
| Justificado - pagado | Solo novedad | 596 | 5.679,16 |
| **Ausentismo - sin respaldo** | Solo marcación | 482 | **2.753,75** |
| Sin novedad | Solo marcación | 3.367 | 341,35 |
| Ausentismo - no pagado | Marcación y novedad | 22 | 76,50 |
| Ausentismo - no pagado | Solo novedad | 17 | 49,00 |
| Justificado - marcación | Solo marcación | 139 | 14,05 |

Las otras dos vistas quedan para **auditar el detalle**, no para sumar. La
consulta C5 del script 2 hace el cruce fila a fila.

### Las dos medidas del fact

| Quieres | Medida |
|---|---|
| Ausentismo no cubierto | `SUM(Horas_Perdidas)` filtrando `Es_Ausentismo = 1` |
| Horas-hombre perdidas | `SUM(Horas_Perdidas)` sin filtrar |

`Horas_Perdidas` son horas perdidas, pagadas o no — por eso no se llama
`Horas_Ausentismo`. `Origen_Fila` dice si el día vino de la marcación, de la
novedad o de las dos, para auditar sin adivinar.

Si un día tuviera dos novedades se conserva una sola, y gana la **no pagada**:
el ausentismo no se disimula detrás de un permiso pagado.

### `En_Nomina`: numerador y denominador, una sola población

`D-H` sale de los roles de pago. Las horas perdidas salen del biométrico. Son
dos sistemas distintos, y quien está en uno pero no en el otro rompe la
división: suma al numerador sin aportar denominador.

Son dos casos, y la marca cubre los dos.

**1 · Candidatos enrolados antes de entrar.** Talento Humano lo confirmó: *"no
son activos ni pasivos, son por entrar"*. El horario les genera el día
programado y cada día programado sin marcación se vuelve falta injustificada.

| Cédula | Quién | Horas | Qué es |
|---|---|---|---|
| 1726914268 | PACHACAMA TOPON KLEVER | 288 | Marcó 2 días de 47. **44 seguidos sin marcar.** |
| 1755683420 | BENALCAZAR CARRANZA TOMAS | 179 | Marcó 3 días de 31. **28 seguidos sin marcar.** |
| 1725895922 | SUNTAXI PACHACAMA ALEX | 9 | Un solo día, en 2022. |

**2 · Gente que se fue y nadie desactivó en OnlyControl.** Mientras siga
activa con horario, TimeControl le genera una falta por día. Un grupo de GYE
retirado entre dic-2022 y oct-2023 siguió acumulando faltas **hasta
feb-2025**: 1.890 h por persona. SALAZAR PULUPA salió el 24-abr-2026 y generó
faltas hasta el 20-jul.

Sobre todo el historial quedan fuera **54.509 h de 267.926 (20 %)**, y el
**95,5 %** son faltas sin marcación de gente que ese periodo no estaba en
nómina. El grueso cae en 2023 (14.284 h) y 2024 (26.982 h): **los índices de
esos años estaban inflados por fantasmas**. En el periodo actual solo sale
BENALCAZAR (179 h): I-A 1,69 % → 1,44 %.

(JIMENEZ OSPINA era otro caso: un duplicado real en OnlyControl con la cédula
de 11 dígitos. Se fusionó en el registro `004988`, que conserva 3.275
marcaciones de acceso y 15 novedades. Resuelto.)

### La regla: la misma población del denominador, periodo por periodo

Una fila cuenta si esa persona **cobró rol en ese periodo de nómina**, con los
mismos cuatro conceptos que usa `[N° de Colaboradores por Mes]`: 01 Sueldo,
41 IESS personal, 81 IESS patronal, 85 Vacación. Cada `Fecha_Rol` se asigna a
su periodo 21→20 igual que el `Calendario Nomina`. Quien no está entre los 347
colaboradores del periodo 21-jul → 20-ago no aporta horas a ese periodo.

Se probaron y descartaron las alternativas:

| Alternativa | Por qué no |
|---|---|
| `rp01fechaingreso` | Se sobrescribe en migraciones y cambios de contrato. 62 personas marcan antes de su supuesto ingreso, con 3.595 h reales; ocho comparten la fecha inventada `2024-12-01`. |
| Solo el primer rol | Cubre a los candidatos pero no a quien se va. Dejaba pasar las 54.509 h de arriba. |
| Rol de cualquier concepto | En abril cobran utilidades los ex empleados: 430 personas con rol contra ~350 el resto del año. |
| Rol del mes siguiente | Desfasado un mes del denominador: el modelo empareja 21-jul → 20-ago con el rol del 31-jul (347), no con el de agosto (350). |

`En_Nomina` **no borra nada**: etiqueta. La fila sigue en el fact para poder
auditarla; son las medidas las que deciden si la cuentan.

Las consultas **C7 a C10** del script 2 lo auditan. **C10 es la operativa**:
lista a quién hay que desactivar hoy en OnlyControl.

## Columnas clave

| Columna | Dónde | Para qué |
|---------|-------|----------|
| `Codigo_Novedad` | novedades | Es `CD_ID` del catálogo, tal cual. Único **dentro de su categoría**: `PE` es CITA MEDICA en la 13 y PERMISO SALIDA en la 2. Agrupar siempre junto a `Categoria_Id`. |
| `Es_Pagado` | novedades | Es `CD_PAGADO`, el check de la pantalla. |
| `Es_Ausentismo` | ambas | Pagado = justificado, no pagado = ausentismo. Se cambia desde Time Control, no desde SQL. |
| `Es_Justificado` | timbradas | Equivalente del lado de marcaciones: categorías 9 y 11 del catálogo. |
| `Horas_Programadas` / `Tipo_Jornada` | timbradas | 8 h o 12 h reales, del horario de ese día. |
| `Horas_No_Trabajadas` | timbradas | Sale de `No_Laborado`, que Time Control ya calcula contra el horario. |
| `Saldo_Horas_Semana` / `Cumplimiento_Semana` | timbradas | Si completó su jornada semanal. Un rotativo 4x2 se evalúa contra las horas que le tocaban, no contra 40 fijas. |

## Antes de publicar en Power BI

1. **Correr C3.** Solo 36 de los 75 horarios están bien configurados: 26 sin
   tramo al 100 %, 6 con horas ordinarias mayores que la jornada, 4 franjas
   abiertas y 3 con tramos absurdos. Se corrigen en Time Control, en
   *Definición de Horarios* — no en SQL.

2. **Decidir el criterio del índice.** El del flag pagado y el del Excel
   histórico dan números muy distintos. Sobre 21-jul a 20-ago 2025 en Quito:

   | Criterio | Horas |
   |---|---|
   | No pagado (solo `SP` permiso sin paga) | 119,62 |
   | Excel histórico de TH | 2.658,64 |

   La diferencia son `LM` lactancia, `LE` enfermedad, `CD` calamidad y `PE`
   cita médica: pagadas, justificadas bajo el criterio nuevo, contadas por el
   Excel. Uno mide *ausentismo no cubierto*, el otro *horas-hombre perdidas*.
   Las vistas soportan los dos. La consulta **C7** los muestra lado a lado.

3. **Definir si `PS` PERMISO CON SUELDO entra al índice.** El código viejo lo
   excluía por texto sin que nadie lo decidiera.

4. **Correr C10 en cada cierre.** Lista a quien tiene días generados en el
   último periodo sin estar en nómina. Hay que desactivarlo en OnlyControl, o
   registrarlo en nómina si ya entró; no se corrige en SQL. `En_Nomina`
   protege el indicador, pero mientras la persona siga activa con horario,
   TimeControl le genera una falta por día: es lo que pasó con GYE entre 2023
   y 2025. `TBL_ASISTENCIA` se genera por periodo cerrado (21→20), así que
   conviene hacerlo antes del siguiente cierre.

## Operación

La carga nocturna es lo único que hay que mantener. Si un día no corre, el
tablero muestra datos viejos sin avisar. Vale la pena que el job de SQL Agent
notifique al fallar.

`sp_th_cargar_ausentismo` recarga las dos tablas enteras dentro de una
transacción: o queda todo o no queda nada. No hay carga incremental a
propósito — con 734 mil filas en 9 s no vale la pena la complejidad, y una
recarga completa nunca deja huecos.

Si algún día cambian las columnas de una vista del origen, hay que borrar la
tabla `stg_*` correspondiente y volver a correr el script 2: el esquema se
deriva solo con `SELECT * INTO ... WHERE 1=0`.
