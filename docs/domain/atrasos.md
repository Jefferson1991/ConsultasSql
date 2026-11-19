# 📊 DOCUMENTACIÓN COMPLETA DE vm_atrasos

## 🎯 **Propósito de la Vista**

La vista `vm_atrasos` es el **reporte principal de Talento Humano** para calcular atrasos y faltas injustificadas de empleados de EMPAQPLAST y LOGISTPLAST.

---

## 📁 **Archivos Creados**

| Archivo | Propósito |
|---------|-----------|
| `vm_atrasos_v2_mejorada.sql` | Versión 2.0 con soporte de festivos y mejoras |
| `create_festivos_ecuador_2026.sql` | Tabla de festivos de Ecuador 2026 |
| `powerbi_vm_atrasos_queries.sql` | 14 consultas Power BI para dashboards |
| `VM_ATRASOS_ANALISIS.md` | Este documento |

---

## 🔍 **ANÁLISIS COMPLETO DE vm_atrasos**

### **Estructura de Datos**

```
Fuentes:
├── [ONLYC].TCONTROL.DBO.VIEWEMPLEADOS (T0)  ← Datos maestros empleados
├── [ONLYC].TCONTROL.DBO.TBL_ASISTENCIA (T1)  ← Registros de asistencia
└── [ONLYC].TCONTROL.DBO.TBL_MODALIDAD (M_Asis)  ← Configuración de horarios
```

### **Filtros Principales**

```sql
T0.NOMINA_EMP IN ('7', '8')  -- Solo EMPAQPLAST (7) y LOGISTPLAST (8)
T1.FECHA_INGRESO >= '2018-01-01'  -- Desde 2018
-- Solo estos casos:
(T1.NOVEDAD_ENTRADA = 'FI' OR T1.NOVEDAD_SALIDA = 'FI')  ← Faltas Injustificadas
OR (T1.MIN_AT > 15)  ← Atrasos mayores a 15 minutos
```

### **Dos Casos de Negocio**

#### **CASO 1: CON Timbrada (Atraso Real)**
- El empleado llegó pero **tarde**
- `HORA_INGRESO IS NOT NULL AND HORA_SALIDA IS NOT NULL`
- Se excluye si es ADMINISTRATIVO en fin de semana

#### **CASO 2: SIN Timbrada (Falta Injustificada)**
- El empleado **NO se presentó**
- `HORA_INGRESO IS NULL AND HORA_SALIDA IS NULL`
- Se excluye según reglas de negocio por tipo de horario

---

## 📋 **CUADRO DE MANEJO DE HORARIOS**

La vista implementa **5 patrones de horario** con reglas específicas:

### **1. ADMINISTRATIVO HE** (`%ADMIN%`)
| Característica | Valor |
|----------------|-------|
| Horario | 8:00 - 17:00 (8 horas) |
| Trabaja Sábado | ❌ No |
| Trabaja Domingo | ❌ No |
| FI en FDS | Excluida siempre |
| Atraso en FDS | Excluido siempre |

**Ejemplos:** `ADMINISTRATIVO HE`, `%ADMIN%`

---

### **2. PRODUCCIÓN (MANANA/TARDE/VELADA)**
| Característica | Valor |
|----------------|-------|
| Horarios | 06-14, 14-22, 22-06 (8 horas) |
| Trabaja Sábado | ✅ Según M_6 de T-Control |
| Trabaja Domingo | ✅ Según M_7 de T-Control |
| FI en FDS | Válida si tiene turno asignado |
| Atraso en FDS | Válido si timbró |

**Ejemplos:** `PROD. MANANA`, `PROD. TARDE`, `PROD. VELADA`, `PROD. 06-18 SYD`

**Nota SYD:** Las variantes SYD (Sabado Y Domingo) tienen M_6=1, M_7=1 **correctamente configurado**.

---

### **3. PRUEBA ROTATIVO 3 (UIO - EMPAQPLAST)**
| Característica | Valor |
|----------------|-------|
| Patrón | Ciclo 4-2 rotativo |
| Turnos | 4 días 06:00-18:00, 2 libres<br>4 días 18:00-06:00, 2 libres |
| Trabaja Sábado | ✅ Sí (forzado a 1) |
| Trabaja Domingo | ✅ Sí (forzado a 1) |
| FI en FDS | Válida si HORARIO_INGRESO tiene hora |
| Atraso en FDS | Válido si timbró |
| Feriados | Cuenta como día hábil (PENDIENTE) |

**Ejemplos:** `PRUEBA_ROTATIVO_3`, `PRUEBA_ROTATIVO`, `PRUEBA_ROTATIVA2`, `HORARIO_ROT_GRUP_1/2/3`, `T_MOLDE_ROTATIVO`

**Regla Especial:** 
> "Si al colaborador le cae su 1ro, 2do, 3ro o 4to día en FDS o feriado, es como su lunes a viernes independientemente de qué día le caiga."

**Descansos posibles:** lun-mar, mar-mie, mie-jue, jue-vie, vie-sab, sab-dom, dom-lun

---

### **4. GYE (LOGISTPLAST)**
| Característica | Valor |
|----------------|-------|
| Patrón | Rotativo 4-2 igual que UIO |
| Trabaja Sábado | ❌ No (forzado a 0) |
| Trabaja Domingo | ❌ No (forzado a 0) |
| FI en FDS | Excluida siempre |
| Atraso en FDS | Válido si timbró (excepcional) |

**Ejemplos:** Mismas modalidades rotativas pero con `EMPE_NOM LIKE '%LOGISTPLAST%'`

**Nota:** "En Guayaquil, dependiendo de la programación, NO SUELEN TRABAJAR FINES DE SEMANA NI FERIADOS."

---

### **5. PERSONAL MOLINO UIO (EMPAQPLAST)**
| Característica | Valor |
|----------------|-------|
| Horario | 12 horas Lunes a Viernes |
| Trabaja Sábado | ❌ No (forzado a 0) |
| Trabaja Domingo | ❌ No (forzado a 0) |
| FI en FDS | Excluida |
| Atraso en FDS | Válido si timbró (excepcional) |

**Ejemplos:** `PLANTA 06 A 18:` (M_ID=209)

**Nota:** "M_6=1, M_7=1 en T-Control es **error de configuración**. De vez en cuando trabajan fines de semana."

---

## 🔧 **LÓGICA CRÍTICA IDENTIFICADA**

### **1. Cálculo de Horas Diarias del Turno**

```sql
CASE
    WHEN HORARIO_INGRESO IS NULL OR HORARIO_SALIDA IS NULL 
        THEN 8.00  -- Default
    WHEN HORARIO_SALIDA < HORARIO_INGRESO 
        THEN (DATEDIFF(MINUTE, entrada, salida) + 1440) / 60.0  -- Nocturno (+1 día)
    ELSE DATEDIFF(MINUTE, entrada, salida) / 60.0  -- Normal
END
```

**Explicación:** 
- Si salida < entrada, significa que cruza medianoche (ej: 22:00-06:00)
- Se suman 1440 minutos (24 horas) para cálculo correcto

---

### **2. Período de Nómina (21-20)**

```
Del 21 del mes anterior al 20 del mes actual
Ejemplo: 21-03-2026 al 20-04-2026
```

**Lógica:**
```sql
SI DIA(FECHA) >= 21:
    período = mes_actual al mes_siguiente
SINO:
    período = mes_anterior al mes_actual
```

---

### **3. Deduplicación Inteligente**

```sql
COUNT(HORA_INGRESO) OVER(PARTITION BY NOMINA_ID, FECHA_INGRESO) AS Conteo_Asistencia_Valida
```

**Propósito:** Evitar doble conteo de falta si hay al menos una timbrada válida ese día.

**Filtro final:**
```sql
WHERE (Hora_Inicio_Permiso IS NOT NULL)  -- Muestra atrasos
   OR (Conteo_Asistencia_Valida = 0)  -- Muestra faltas solo si NO hay timbradas
```

---

### **4. Override de Configuración T-Control**

La vista **corrige errores conocidos** de configuración:

| Modalidad | Configuración T-Control | Corrección en Vista | Razón |
|-----------|------------------------|---------------------|-------|
| `%ADMIN%` | M_6/M_7 pueden ser 1 | Forzar a 0 | Administrativo no trabaja FDS |
| `PLANTA 06 A 18:` | M_6=1, M_7=1 | Forzar a 0 | Molino UIO solo Lun-Vie |
| `PRUEBA_ROTATIV%` (UIO) | M_6=0, M_7=0 | Forzar a 1 | Rotativo UIO trabaja FDS |
| Rotativas + LOGISTPLAST | M_6/M_7 varios | Forzar a 0 | GYE no trabaja FDS |
| SYD variantes | M_6=1, M_7=1 | **NO TOCAR** | Configuración correcta |

---

## ⚠️ **PROBLEMAS IDENTIFICADOS EN VERSIÓN ORIGINAL**

### **Problema 1: Feriados NO Implementados**
```
PENDIENTE: No existe tabla de festivos en BD
Regla del cuadro sobre festivos no se puede implementar
```

**Impacto:** 
- Rotativos UIO deberían tratar festivos como días hábiles
- No se puede validar si FI en festivo es válida

**Solución:** 
✅ Crear `TBL_FESTIVOS_TALENTO` (archivo: `create_festivos_ecuador_2026.sql`)

---

### **Problema 2: Lógica de Fin de Semana Frágil**

**Versión Original:**
```sql
DATEDIFF(day, '19000101', FECHA_INGRESO) % 7 IN (5, 6)
```

**Problema:** 
- Asume que 1900-01-01 fue lunes (día 0)
- Dependiente del sistema de fechas de SQL Server
- Poco legible

**Solución:**
```sql
DATEPART(WEEKDAY, FECHA_INGRESO) IN (7, 1)  -- Sábado=7, Domingo=1
```

✅ Implementado en vm_atrasos_v2

---

### **Problema 3: Validación de "Hora Cero" Ambigua**

**Versión Original:**
```sql
DATEPART(HOUR, HORARIO_INGRESO) = 0 AND DATEPART(MINUTE, HORARIO_INGRESO) = 0
```

**Problema:** 
- Puede fallar si un turno legítimo empieza a medianoche (00:00)
- Falso positivo para turnos nocturnos válidos

**Solución:**
```sql
CAST(HORARIO_INGRESO AS TIME) = CAST('00:00:00' AS TIME)
```

✅ Implementado en vm_atrasos_v2

---

### **Problema 4: Hardcoded de Empresas**

```sql
T0.NOMINA_EMP IN ('7', '8')
```

**Problema:** 
- Si se agregan empresas, hay que modificar la vista
- No es flexible

**Solución Recomendada:**
Crear tabla de configuración:
```sql
CREATE TABLE dbo.CFG_EMPRESAS_ACTIVAS (
    EMPRESA_ID VARCHAR(10) PRIMARY KEY,
    EMPRESA_NOMBRE VARCHAR(100),
    ACTIVA BIT DEFAULT 1
);
```

---

## 📊 **GUÍA DE DASHBOARDS POWER BI**

### **Consultas Disponibles** (archivo: `powerbi_vm_atrasos_queries.sql`)

| # | Consulta | Propósito | Página Power BI |
|---|----------|-----------|-----------------|
| 1 | Resumen Ejecutivo | KPIs principales | Dashboard Ejecutivo |
| 2 | Tendencia Mensual | Evolución mensual | Tendencias |
| 3 | Top Empleados Críticos | Reincidentes | Accion Correctiva |
| 4 | Análisis por Área | Comparación áreas | Gestión por Área |
| 5 | Distribución por Día | Patrones diarios | Patrones |
| 6 | Análisis por Jornada | Comparación horarios | Gestión de Horarios |
| 7 | Distribución Horas | Impacto en productividad | Costos |
| 8 | Reporte Diario | Vista diaria RRHH | Seguimiento |
| 9 | Comparativo UIO vs GYE | Benchmark sedes | Comparativo |
| 10 | Tendencia Mejora/Empeoramiento | Evolución empleados | Seguimiento Individual |
| 11 | Análisis de Faltas | Profundización FIs | Plan de Acción |
| 12 | Reporte para Nómina | Descuento en nómina | Integración Nómina |
| 13 | Heatmap Hora/Día | Patrones horarios | Análisis Detallado |
| 14 | Resumen Gerencial | KPIs en una fila | Gerencia General |

---

### **Páginas Recomendadas para Power BI**

#### **Página 1: Dashboard Ejecutivo**
**Visuales:**
- Tarjetas: Total Casos, Empleados Afectados, Horas Perdidas, Reincidentes
- Gráfico Línea: Tendencia Mensual (Consulta 2)
- Gráfico Barras: Faltas vs Atrasos por Ciudad (Consulta 9)
- Tabla: Top 10 Empleados Críticos (Consulta 3)

---

#### **Página 2: Gestión por Área**
**Visuales:**
- Matriz: Áreas con métricas (Consulta 4)
- Gráfico Donut: Distribución por Tipo Jornada (Consulta 6)
- Gráfico Dispersión: Horas vs Cantidad de Casos
- Segmentación: Área, Departamento, Ciudad

---

#### **Página 3: Patrones y Tendencias**
**Visuales:**
- Mapa Calor: Atrasos por Día/Hora (Consulta 13)
- Gráfico Barras: Distribución por Día Semana (Consulta 5)
- Gráfico Línea: Comparativo UIO vs GYE (Consulta 9)
- Segmentación: Mes, Año

---

#### **Página 4: Accion Correctiva**
**Visuales:**
- Tabla: Empleados Reincidentes con Nivel (Consulta 3)
- Tabla: Análisis de FIs por Empleado (Consulta 11)
- Gráfico: Tendencia Mejora/Empeoramiento (Consulta 10)
- Segmentación: Nivel Reincidencia, Área

---

#### **Página 5: Reporte para Nómina**
**Visuales:**
- Tabla: Resumen por Empleado (Consulta 12)
- Tarjetas: Horas Faltas, Horas Atrasos, Días Descuento
- Gráfico Barras: Horas por Área
- Segmentación: Período 21-20

---

### **Medidas DAX Recomendadas**

```dax
-- Tasa de Ausentismo
Tasa_Ausentismo = 
DIVIDE(
    CALCULATE(COUNTROWS(vm_atrasos), vm_atrasos[Tipo_Permiso] = "FI"),
    DISTINCTCOUNT(vm_atrasos[empleado_id])
) * 100

-- Promedio de Horas por Caso
Promedio_Horas_Caso = 
AVERAGE(vm_atrasos[Horas_Permiso_Calculadas])

-- Empleados Reincidentes (3+ casos)
Empleados_Reincidentes = 
COUNTX(
    FILTER(
        SUMMARIZE(vm_atrasos, vm_atrasos[empleado_id], "TotalCasos", COUNTROWS(vm_atrasos)),
        [TotalCasos] >= 3
    ),
    [empleado_id]
)

-- Costo Estimado (ajuntar costo real/hora)
Costo_Estimado = 
SUM(vm_atrasos[Horas_Permiso_Calculadas]) * 5.00  -- AJUSTAR costo/hora real

-- % de Mejora vs Mes Anterior
Tasa_Mejora = 
VAR Casos_Mes_Actual = COUNTROWS(vm_atrasos)
VAR Casos_Mes_Anterior = CALCULATE(
    COUNTROWS(vm_atrasos), 
    DATEADD(vm_atrasos[Fecha_Inicio], -1, MONTH)
)
RETURN
DIVIDE(Casos_Mes_Anterior - Casos_Mes_Actual, Casos_Mes_Anterior) * 100
```

---

### **Slicers (Filtros) Recomendados**

- **Período** (campo `PeriodoEtiqueta`)
- **Ciudad** (campo `Ciudad_Sede`: UIO/GYE)
- **Tipo Permiso** (campo `Tipo_Permiso`: FI/A)
- **Área** (campo `Area`)
- **Departamento** (campo `Departamento`)
- **Tipo Jornada** (campo `Descripcion_Jornada`)
- **Fecha Rango** (campo `Fecha_Inicio`)
- **Nivel Reincidencia** (campo calculado)

---

## 🚀 **GUÍA DE IMPLEMENTACIÓN**

### **Paso 1: Crear Tabla de Festivos**
```bash
# Ejecutar en base de datos TH
sqlcmd -S 192.168.20.15 -d TH -U sa -P Empaqplastssql.! -i create_festivos_ecuador_2026.sql
```

### **Paso 2: Verificar Festivos**
```sql
SELECT * FROM dbo.vw_festivos_activos ORDER BY fecha;
```

### **Paso 3: Crear Vista Mejorada**
```bash
sqlcmd -S 192.168.20.15 -d TH -U sa -P Empaqplastssql.! -i vm_atrasos_v2_mejorada.sql
```

### **Paso 4: Verificar Vista**
```sql
SELECT TOP 10 * FROM dbo.vm_atrasos_v2 ORDER BY Fecha_Inicio DESC;
```

### **Paso 5: Comparar con Versión Anterior**
```sql
SELECT 'Anterior' AS version, COUNT(*) AS regs FROM dbo.vm_atrasos
UNION ALL
SELECT 'Nueva v2' AS version, COUNT(*) AS regs FROM dbo.vm_atrasos_v2;
```

### **Paso 6: Configurar Power BI**
1. Importar consultas desde `powerbi_vm_atrasos_queries.sql`
2. Crear modelo de datos con relaciones
3. Configurar actualización programada
4. Publicar en Power BI Service

---

## 📈 **MÉTRICAS CLAVE A MONITOREAR**

### **Operativas**
- **Tasa de Ausentismo:** FIs / Días laborables esperados (Meta: <3%)
- **Puntualidad:** % empleados sin atrasos >15min (Meta: >90%)
- **Reincidencia:** % empleados con 3+ casos/mes (Meta: <5%)

### **Financieras**
- **Horas Perdidas:** Total horas de FIs + Atrasos
- **Costo Estimado:** Horas perdidas × costo/hora promedio
- **Días de Descuento:** FIs × 8 horas / jornada estándar

### **Comparativas**
- **UIO vs GYE:** Benchmark de puntualidad
- **Áreas:** Identificar áreas problemáticas
- **Tipos Jornada:** Rotativos vs Fijos

---

## 🔐 **SEGURIDAD Y PERMISOS**

### **Permisos Recomendados**

```sql
-- Rol de solo lectura para Power BI
CREATE ROLE powerbi_reader;
GRANT SELECT ON dbo.vm_atrasos_v2 TO powerbi_reader;
GRANT SELECT ON dbo.TBL_FESTIVOS_TALENTO TO powerbi_reader;

-- Rol de administrador de RRHH
CREATE ROLE rrhh_admin;
GRANT SELECT, INSERT, UPDATE ON dbo.TBL_FESTIVOS_TALENTO TO rrhh_admin;
GRANT SELECT ON dbo.vm_atrasos_v2 TO rrhh_admin;
GRANT SELECT, INSERT ON dbo.TBL_FESTIVOS_HISTORIAL TO rrhh_admin;
```

### **Seguridad a Nivel de Fila (RLS)**

Para Power BI, implementar RLS para que cada área vea solo sus datos:

```dax
-- Regla RLS en Power BI
[Area] = USERPRINCIPALNAME()
-- O mapear usuario a área en tabla de seguridad
```

---

## 🛠️ **MANTENIMIENTO**

### **Mensual**
- Revisar datos de última semana
- Verificar que no haya errores de carga
- Actualizar festivos si hay decretos nuevos

### **Trimestral**
- Revisar índices de SQL Server
- Analizar rendimiento de consultas
- Optimizar si es necesario

### **Anual**
- Cargar festivos del año siguiente
- Revisar reglas de negocio (¿cambios en horarios?)
- Actualizar documentación

---

## 📞 **SOPORTE**

### **Problemas Comunes**

| Problema | Causa | Solución |
|----------|-------|----------|
| Vista no devuelve datos | Linked server caído | Verificar conexión a ONLYC |
| Consulta lenta | Índices faltantes | Crear índices del archivo v2 |
| Festivos no aplican | Tabla no cargada | Ejecutar create_festivos_ecuador_2026.sql |
| Doble conteo de faltas | Datos duplicados en TBL_ASISTENCIA | Revisar deduplicación en WHERE |

---

## 📝 **HISTORIAL DE VERSIONES**

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2026-03-16 | Vista original (alter_vm_atrasos_cuadro_horarios.sql) |
| 2.0 | 2026-04-13 | + Soporte festivos<br>+ Validación 00:00<br>+ Columnas adicionales<br>+ Índices optimizados |

---

## ✅ **CHECKLIST DE IMPLEMENTACIÓN**

- [ ] Crear tabla TBL_FESTIVOS_TALENTO
- [ ] Cargar festivos 2026
- [ ] Crear vista vm_atrasos_v2
- [ ] Verificar datos con versión anterior
- [ ] Crear índices de optimización
- [ ] Configurar permisos
- [ ] Importar consultas Power BI
- [ ] Crear modelo de datos
- [ ] Configurar actualización programada
- [ ] Publicar dashboard
- [ ] Capacitar usuarios

---

**📅 Última Actualización:** 2026-04-13  
**👤 Autor:** Jefferson Vásconez  
**🏢 Empresa:** EMPAQPLAST  
**📧 Soporte:** Equipo de Talento Humano
