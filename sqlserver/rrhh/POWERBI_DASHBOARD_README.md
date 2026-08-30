# POWER BI DASHBOARD - TCONTROL + ONLYCONTROL Integration

## Overview
This project provides comprehensive SQL queries for building impactful Power BI dashboards by integrating biometric attendance data (TCONTROL) with employee master data (ONLYCONTROL).

## Database Architecture

### Source Systems
- **sqlserver-timecontrol (TCONTROL)**: Biometric attendance tracking, time logs, schedules, overtime approvals
- **sqlserver-onlycontrol (ONLYCONTROL)**: Employee master data, organizational structure, departments, positions

### Data Flow
```
ONLYCONTROL (Dimensions) ──┐
                            ├──> Power BI Dashboard
TCONTROL (Facts) ──────────┘
```

## Query Catalog (25 Queries)

### 📊 **Dashboard Pages**

| # | Query Name | Purpose | Power BI Page |
|---|------------|---------|---------------|
| 1 | Employee Master Data | Base employee dimension | Employee Directory |
| 2 | Daily Attendance Summary | Main attendance fact table | Attendance Overview |
| 3 | Weekly Attendance History | Weekly trends | Trends Analysis |
| 4 | Overtime Analysis | Overtime by rate and employee | Overtime Dashboard |
| 5 | Absences & Leaves | Vacation, sick leave tracking | Leave Management |
| 6 | Justifications | Attendance justifications | Exceptions Report |
| 7 | Non-Worked Time | Hours not worked | Absence Analysis |
| 8 | Real-Time Biometric Logs | Live attendance monitoring | Real-Time Dashboard |
| 9 | Schedule Assignments | Employee-schedule mapping | Schedule Planning |
| 10 | Schedule Catalog | Schedule definitions | Reference Data |

### 📈 **Analytics Queries**

| # | Query Name | Purpose | Power BI Page |
|---|------------|---------|---------------|
| 11 | Department Attendance Summary | Department KPIs | Department Comparison |
| 12 | Monthly Trends | Monthly attendance trends | Executive Trends |
| 13 | Top Late Employees | Punctuality analysis | Performance Review |
| 14 | Top Overtime Employees | Overtime leaders | Overtime Analysis |
| 15 | Payroll Period Summary | Payroll-ready data | Payroll Dashboard |
| 16 | Device Utilization | Biometric device monitoring | IT Infrastructure |
| 17 | Holiday Calendar | Reference calendar | Scheduling |
| 18 | Permissions Matrix | User access control | Security Audit |
| 19 | System Activity Log | Audit trail | System Monitoring |
| 20 | Employee 360 View | Complete employee profile | Employee Details |

### 🎯 **Advanced Analytics**

| # | Query Name | Purpose | Power BI Page |
|---|------------|---------|---------------|
| 21 | Area Comparison | Cross-department analysis | Department Dashboard |
| 22 | Daily Exceptions Report | HR review report | Exceptions Dashboard |
| 23 | Vacation Balance | Leave balance calculation | Leave Management |
| 24 | Shift Coverage | Shift assignment analysis | Schedule Planning |
| 25 | Executive Summary | High-level KPIs | Executive Dashboard |

## Power BI Implementation Guide

### Step 1: Data Connection

#### Option A: Direct Query (Recommended for large datasets)
1. Open Power BI Desktop
2. Get Data → SQL Server
3. Server: `SRV-BIOM-001\SQLEXPRESS2008R2`
4. Database: `TCONTROL`
5. Select "DirectQuery" mode

#### Option B: Import Mode (Better performance for smaller datasets)
1. Import each query as a separate table
2. Use Power Query to transform data
3. Set up scheduled refresh (hourly/daily)

### Step 2: Create Relationships

```
NOMINA (ONLYCONTROL)
├── NOMINA_ID ──┐
└── NOMINA_AREA ──> AREA.AREA_ID

TBL_ASISTENCIA (TCONTROL)
├── EMP_ID ──> NOMINA.NOMINA_ID
├── Fecha_Ingreso ──> Date Table
├── horario ──> TBL_HORARIO.H_ID
└── modalidad ──> TBL_MODALIDAD.M_ID

TBL_PERM_AUS
└── E_EMPID ──> NOMINA.NOMINA_ID

TBL_JUSTIFICACIONES
└── EMP_ID ──> NOMINA.NOMINA_ID
```

### Step 3: Create Date Table
```dax
Date Table = 
ADDCOLUMNS (
    CALENDAR ( DATE ( 2020, 1, 1 ), DATE ( 2030, 12, 31 ) ),
    "DateAsInteger", FORMAT ( [Date], "YYYYMMDD" ),
    "Year", YEAR ( [Date] ),
    "MonthNumber", FORMAT ( [Date], "MM" ),
    "MonthName", FORMAT ( [Date], "MMMM" ),
    "DayOfWeekNumber", WEEKDAY ( [Date] ),
    "DayOfWeek", FORMAT ( [Date], "dddd" ),
    "Quarter", "Q" & FORMAT ( [Date], "Q" ),
    "YearQuarter", FORMAT ( [Date], "YYYY" ) & "/Q" & FORMAT ( [Date], "Q" )
)
```

### Step 4: Key DAX Measures

#### Attendance Rate
```dax
Attendance Rate = 
DIVIDE(
    CALCULATE(COUNTROWS(TBL_ASISTENCIA), TBL_ASISTENCIA[Ausente] = 0),
    COUNTROWS(TBL_ASISTENCIA)
) * 100
```

#### Average Hours Worked
```dax
Avg Hours Worked = 
AVERAGE(TBL_ASISTENCIA[Horas_Laboradas])
```

#### Total Overtime Hours
```dax
Total OT Hours = 
DIVIDE(
    SUM(TBL_ASISTENCIA[total_overtime_minutes]),
    60
)
```

#### Overtime Cost
```dax
OT Cost = 
SUMX(
    TBL_ASISTENCIA_APROBACION,
    TBL_ASISTENCIA_APROBACION[minutos] * TBL_ASISTENCIA_APROBACION[cost_multiplier]
)
```

#### Absence Rate
```dax
Absence Rate = 
DIVIDE(
    CALCULATE(COUNTROWS(TBL_ASISTENCIA), TBL_ASISTENCIA[Ausente] = 1),
    COUNTROWS(TBL_ASISTENCIA)
) * 100
```

### Step 5: Dashboard Design

#### Page 1: Executive Summary
**Visuals:**
- Cards: Active Employees, Today's Attendance Rate, Monthly Overtime Hours, Absences This Week
- Line Chart: Monthly Attendance Trend
- Bar Chart: Overtime by Department
- Donut Chart: Leave Types Distribution
- Table: Top 10 Late Employees

#### Page 2: Attendance Overview
**Visuals:**
- Matrix: Daily Attendance by Department (heatmap)
- Line Chart: Weekly Attendance Pattern
- Gauge: Current Month Attendance Rate vs Target (95%)
- Table: Daily Exceptions
- Slicer: Date Range, Department, Employee

#### Page 3: Overtime Analysis
**Visuals:**
- Stacked Bar: Overtime by Rate (25%, 50%, 100%, etc.)
- Line Chart: Monthly Overtime Trend
- Bar Chart: Top 20 Overtime Employees
- Treemap: Overtime by Department
- Card: Total Overtime Cost

#### Page 4: Leave Management
**Visuals:**
- Stacked Column: Leave Types by Month
- Table: Currently on Leave
- Card: Available Vacation Days (per employee)
- Pie Chart: Paid vs Unpaid Leave
- Calendar Visual: Leave Distribution

#### Page 5: Department Comparison
**Visuals:**
- Bar Chart: Attendance Rate by Department
- Scatter Plot: Hours vs Overtime by Department
- Table: Department KPIs
- Radar Chart: Performance Metrics

#### Page 6: Employee 360
**Visuals:**
- Card: Employee Info (Photo, Name, Position, Department)
- Timeline: Attendance History
- Bar Chart: Monthly Hours Worked
- Table: Leave History
- KPI: Punctuality Score

### Step 6: Color Palette Recommendations

**Professional Theme:**
- Primary: `#1F4E79` (Navy Blue)
- Secondary: `#2E75B6` (Medium Blue)
- Accent: `#FFC000` (Gold)
- Success: `#548235` (Green)
- Warning: `#ED7D31` (Orange)
- Danger: `#C00000` (Red)
- Neutral: `#D9D9D9` (Light Gray)

### Step 7: Performance Optimization

1. **Use Query Folding**: Ensure Power Query can fold queries back to SQL Server
2. **Create Indexes** on SQL Server:
   ```sql
   CREATE INDEX IX_ASISTENCIA_EMP_FECHA ON TBL_ASISTENCIA(EMP_ID, Fecha_Ingreso);
   CREATE INDEX IX_ASISTENCIA_FECHA ON TBL_ASISTENCIA(Fecha_Ingreso);
   CREATE INDEX IX_PERM_AUS_EMP ON TBL_PERM_AUS(E_EMPID);
   ```

3. **Incremental Refresh** (for large datasets):
   - Configure refresh policy to only load last 90 days
   - Archive older data in separate table

4. **Use Aggregations**:
   - Create summary tables for historical data
   - Use DirectQuery for recent data, Import for archives

## Key Metrics to Track

### Operational KPIs
- **Attendance Rate**: % of employees present daily (Target: >95%)
- **Punctuality Rate**: % of on-time arrivals (Target: >90%)
- **Average Delay**: Mean minutes late for tardy employees (Target: <15 min)
- **Overtime Hours**: Total overtime per employee per month (Target: <20 hrs)
- **Absence Rate**: % of unplanned absences (Target: <3%)

### Financial KPIs
- **Overtime Cost**: Total overtime hours × cost multiplier
- **Lost Hours**: Hours lost to absences/delays
- **Leave Cost**: Paid leave days × daily salary

### Compliance KPIs
- **Justification Rate**: % of delays with valid justification
- **Approval Rate**: % of overtime requests approved
- **Device Uptime**: % of biometric devices operational

## Common Issues & Solutions

### Issue 1: Cross-Database Join Fails
**Solution**: Use linked server or import both databases into Power BI separately and create relationships in the data model.

### Issue 2: Slow Query Performance
**Solution**: 
- Add indexes on join columns
- Use date range filters in queries
- Consider creating views in SQL Server

### Issue 3: Missing Employee Data
**Solution**: Some employees may exist in TCONTROL but not in ONLYCONTROL. Use LEFT JOIN to preserve all attendance records.

### Issue 4: Time Zone Issues
**Solution**: Ensure all timestamps are in the same timezone. Convert if necessary in Power Query.

## Maintenance Schedule

| Task | Frequency | Responsible |
|------|-----------|-------------|
| Refresh Data | Daily/Hourly | Power BI Service |
| Review Indexes | Monthly | DBA |
| Update Queries | As needed | BI Developer |
| Dashboard Review | Weekly | HR Manager |
| Performance Audit | Quarterly | IT Team |

## Security Considerations

1. **Row-Level Security (RLS)**: Implement in Power BI to restrict data by department
   ```dax
   [Department] = USERPRINCIPALNAME()
   ```

2. **Data Masking**: Hide sensitive fields (phone, address) for non-HR users

3. **Access Control**: Limit SQL Server access to Power BI service account only

## Future Enhancements

- [ ] Integrate with SAP HANA for payroll data
- [ ] Add predictive analytics for absenteeism
- [ ] Create automated email reports for managers
- [ ] Implement real-time dashboard with Power BI Streaming
- [ ] Add mobile-optimized layout
- [ ] Create benchmarking against industry standards

## Contact & Support

For questions or issues:
- Review MCP server logs for connection errors
- Check SQL Server connectivity using SQL Server Management Studio
- Verify user permissions on both databases

---

**Version**: 1.0  
**Last Updated**: 2026-04-13  
**Status**: Production Ready ✅
