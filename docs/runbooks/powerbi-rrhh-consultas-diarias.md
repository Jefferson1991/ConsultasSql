# POWER BI QUICK REFERENCE - Essential Queries

## 🔥 TOP 10 Most Important Queries

### 1. Daily Attendance (Use Every Day)
```sql
-- Query 2 from main file - Use this for daily reports
SELECT 
    a.EMP_ID,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS employee_name,
    a.Fecha_Ingreso,
    a.Hora_Ingreso,
    a.Hora_Salida,
    a.Horas_Laboradas,
    a.Atrasos,
    CASE WHEN a.Ausente = 1 THEN 'Absent' ELSE 'Present' END AS status
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
WHERE a.Fecha_Ingreso >= '2026-04-01'  -- Adjust date range
ORDER BY a.Fecha_Ingreso DESC;
```

### 2. Employee Directory (Dimension Table)
```sql
-- Query 1 from main file - Import once as dimension
SELECT 
    n.NOMINA_ID,
    n.NOMINA_NOM,
    n.NOMINA_APE,
    a.AREA_NOM AS department,
    c.CALI_NOM AS position,
    n.NOMINA_FING AS hire_date,
    CASE WHEN n.NOMINA_FSAL IS NULL THEN 'Active' ELSE 'Inactive' END AS status
FROM ONLYCONTROL.dbo.NOMINA n
LEFT JOIN ONLYCONTROL.dbo.AREA a ON n.NOMINA_AREA = a.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID;
```

### 3. Overtime Summary (Monthly Report)
```sql
-- Simplified overtime query
SELECT 
    a.EMP_ID,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS employee_name,
    a.Fecha_Ingreso,
    a.min_25, a.min_50, a.min_100,
    (ISNULL(a.min_25,0) + ISNULL(a.min_50,0) + ISNULL(a.min_100,0)) AS total_ot_min
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
WHERE (a.min_25 > 0 OR a.min_50 > 0 OR a.min_100 > 0)
  AND a.Fecha_Ingreso >= '2026-04-01';
```

### 4. Absences This Week
```sql
-- Current week absences
SELECT 
    a.EMP_ID,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS employee_name,
    ar.AREA_NOM AS department,
    a.Fecha_Ingreso,
    a.Ausente
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
WHERE a.Ausente = 1
  AND a.Fecha_Ingreso >= DATEADD(DAY, -7, GETDATE());
```

### 5. Late Arrivals Today
```sql
-- Today's late arrivals
SELECT TOP 20
    a.EMP_ID,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS employee_name,
    ar.AREA_NOM AS department,
    a.Hora_Ingreso,
    a.Atrasos AS minutes_late
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
WHERE a.Atrasos > 0
  AND a.Fecha_Ingreso = CAST(GETDATE() AS DATE)
ORDER BY a.Atrasos DESC;
```

### 6. Department Summary
```sql
-- Department attendance summary
SELECT 
    ar.AREA_NOM AS department,
    COUNT(DISTINCT a.EMP_ID) AS employees_present,
    AVG(CAST(a.Horas_Laboradas AS FLOAT)) AS avg_hours,
    AVG(CAST(a.Atrasos AS FLOAT)) AS avg_delay_min,
    SUM(CAST(a.Atrasos AS INT)) AS total_delay_minutes
FROM TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
WHERE a.Fecha_Ingreso >= DATEADD(DAY, -30, GETDATE())
GROUP BY ar.AREA_NOM;
```

### 7. Vacation Requests
```sql
-- Current leave requests
SELECT 
    pa.E_EMPID,
    n.NOMINA_NOM + ' ' + n.NOMINA_APE AS employee_name,
    pa.E_NOM AS leave_type,
    pa.E_FECHA_I AS start_date,
    pa.E_FECHA_F AS end_date,
    DATEDIFF(DAY, pa.E_FECHA_I, pa.E_FECHA_F) + 1 AS days,
    CASE pa.D_PAG WHEN 1 THEN 'Paid' ELSE 'Unpaid' END AS type
FROM TBL_PERM_AUS pa
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON pa.E_EMPID = n.NOMINA_ID
WHERE pa.E_FECHA_F >= GETDATE();
```

### 8. Monthly Executive Summary
```sql
-- Monthly KPIs
SELECT 
    YEAR(a.Fecha_Ingreso) AS year,
    MONTH(a.Fecha_Ingreso) AS month,
    COUNT(DISTINCT a.EMP_ID) AS total_records,
    AVG(CAST(a.Horas_Laboradas AS FLOAT)) AS avg_hours,
    SUM(CAST(a.Atrasos AS INT)) AS total_delay_minutes,
    COUNT(CASE WHEN a.Ausente = 1 THEN 1 END) AS absences
FROM TBL_ASISTENCIA a
WHERE a.Fecha_Ingreso >= '2026-01-01'
GROUP BY YEAR(a.Fecha_Ingreso), MONTH(a.Fecha_Ingreso)
ORDER BY year DESC, month DESC;
```

### 9. Employee 360 (Single Employee)
```sql
-- Complete view for one employee (change EMP_ID)
SELECT 
    n.NOMINA_ID,
    n.NOMINA_NOM,
    n.NOMINA_APE,
    ar.AREA_NOM AS department,
    c.CALI_NOM AS position,
    n.NOMINA_FING AS hire_date,
    (SELECT COUNT(*) FROM TBL_ASISTENCIA 
     WHERE EMP_ID = n.NOMINA_ID AND Ausente = 1) AS total_absences,
    (SELECT SUM(Atrasos) FROM TBL_ASISTENCIA 
     WHERE EMP_ID = n.NOMINA_ID) AS total_delay_minutes,
    (SELECT COUNT(*) FROM TBL_PERM_AUS 
     WHERE E_EMPID = n.NOMINA_ID AND E_NOM = 'VC') AS vacation_days_taken
FROM ONLYCONTROL.dbo.NOMINA n
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
LEFT JOIN ONLYCONTROL.dbo.CALIFICA c ON n.NOMINA_CAL = c.CALI_ID
WHERE n.NOMINA_ID = '000001';  -- <-- Change this
```

### 10. Executive Dashboard KPIs
```sql
-- Quick KPIs for today
SELECT 
    (SELECT COUNT(*) FROM ONLYCONTROL.dbo.NOMINA WHERE NOMINA_FSAL IS NULL) AS active_employees,
    (SELECT COUNT(DISTINCT EMP_ID) FROM TBL_ASISTENCIA 
     WHERE Fecha_Ingreso = CAST(GETDATE() AS DATE)) AS clocked_today,
    (SELECT COUNT(DISTINCT EMP_ID) FROM TBL_ASISTENCIA 
     WHERE Fecha_Ingreso = CAST(GETDATE() AS DATE) AND Ausente = 1) AS absent_today,
    (SELECT COUNT(DISTINCT EMP_ID) FROM TBL_ASISTENCIA 
     WHERE Fecha_Ingreso = CAST(GETDATE() AS DATE) AND Atraso = 1) AS late_today;
```

## 📊 Power BI Quick Setup

### Step 1: Import Tables
```
1. Employee Dimension (Query 2)
2. Daily Attendance (Query 1)  
3. Department Reference (from NOMINA table)
4. Position Reference (from CALIFICA table)
```

### Step 2: Create Relationships
```
NOMINA[NOMINA_ID] ──1:Many──> TBL_ASISTENCIA[EMP_ID]
NOMINA[NOMINA_AREA] ──> AREA[AREA_ID]
NOMINA[NOMINA_CAL] ──> CALIFICA[CALI_ID]
```

### Step 3: Essential Visuals
- **Card**: Active Employees, Attendance Rate, Absences Today
- **Line Chart**: Monthly Attendance Trend
- **Bar Chart**: Overtime by Department
- **Table**: Late Arrivals (sorted by minutes)
- **Matrix**: Attendance by Department and Day

## 🎨 Dashboard Design Tips

### Colors
- ✅ Green for good metrics (high attendance)
- ⚠️ Yellow for warnings (moderate delays)
- 🔴 Red for alerts (absences, high overtime)
- 🔵 Blue for neutral data

### Layout
```
┌─────────────────────────────────────────┐
│         EXECUTIVE SUMMARY               │
│  [Card] [Card] [Card] [Card] [Card]     │
├─────────────────────────────────────────┤
│  [Line Chart: Monthly Trend]            │
│  [Bar Chart: By Department]             │
├─────────────────────────────────────────┤
│  [Table: Top Issues]                    │
│  [Filters: Date, Dept, Employee]        │
└─────────────────────────────────────────┘
```

## ⚡ Performance Tips

1. **Always filter by date** - Add `WHERE Fecha_Ingreso >= '2026-01-01'`
2. **Use TOP clause** for "Top N" queries
3. **Avoid SELECT \*** - Only select needed columns
4. **Create indexes** on EMP_ID and Fecha_Ingreso

## 🔧 Troubleshooting

### Query Returns No Data
- Check date range filter
- Verify employee ID format (6 digits: 000001)
- Confirm tables have recent data

### Slow Performance
- Add WHERE clause with date range
- Create indexes on join columns
- Use TOP for large result sets

### Duplicate Rows
- Check for multiple schedule assignments
- Verify date joins are correct
- Use DISTINCT if needed

## 📱 Mobile Dashboard Layout

### Screen 1: Overview
- Cards with key metrics
- Today's attendance rate
- Absences alert

### Screen 2: Details
- Employee search
- Individual attendance
- Leave balance

### Screen 3: Analytics
- Monthly trends
- Department comparison
- Overtime analysis

---

**Tip**: Start with these 10 queries, then explore the full 25 queries in the main file!
