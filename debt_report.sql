 Підсумкові дані для звіту про заборгованість за всіма контрактами розстрочки. Звітний місяць.


WITH paid_to_date AS
(
SELECT 
    merchant_id, 
    contract_number,
    SUM(ISNULL(payment,0)) AS paid_to_date
FROM payments
WHERE date_payment <= '2020-04-30'
GROUP BY merchant_id, contract_number
),

should_be_paid AS
(
SELECT
    i.merchant_id,
    i.contract_number,
    i.inst,
    i.qu_inst,
    i.date_purch,
CASE 
    WHEN i.date_purch > '2020-04-30' THEN 0
    WHEN (
         (YEAR('2020-04-30') - YEAR(i.date_purch)) * 12 +
         (MONTH('2020-04-30') - MONTH(i.date_purch)) + 1 ) >= i.qu_inst
         THEN i.inst * i.qu_inst
        ELSE (
            (YEAR('2020-04-30') - YEAR(i.date_purch)) * 12 +
            (MONTH('2020-04-30') - MONTH(i.date_purch)) + 1
        ) * i.inst
    END AS should_paid_to_date
FROM installment_plan i
), zav1_3 AS 
(
SELECT
    i.merchant_id,
    i.contract_number,
    s.date_purch,
    s.qu_inst,
    s.should_paid_to_date,

    -- повна сума договору
    (i.inst * i.qu_inst) AS sum_vsnosov,

    -- реально сплачено
    ISNULL(p.paid_to_date,0) AS total_payment,

    -- залишок по договору
    (i.inst * i.qu_inst) - ISNULL(p.paid_to_date,0) AS vsego,

    -- прострочена заборгованість
    CASE 
        WHEN s.should_paid_to_date - ISNULL(p.paid_to_date,0) < 0 THEN 0
        ELSE s.should_paid_to_date - ISNULL(p.paid_to_date,0)
    END AS borg,
    CASE 
        WHEN (
             (YEAR('2020-04-30') - YEAR(s.date_purch)) * 12 +
             (MONTH('2020-04-30') - MONTH(s.date_purch)) + 1
        ) >= s.qu_inst
        THEN 'Закінчений'
        ELSE 'Не закінчений'
    END AS period_1,

    CASE 
        WHEN  (CASE WHEN s.should_paid_to_date - ISNULL(p.paid_to_date,0) < 0 THEN 0 ELSE s.should_paid_to_date - ISNULL(p.paid_to_date,0) END)  > 0 THEN 'Є борг'
        ELSE 'Немає боргу'
        END AS statys_borg,
    CASE 
      WHEN (
         (YEAR('2020-04-30') - YEAR(s.date_purch)) * 12 +
         (MONTH('2020-04-30') - MONTH(s.date_purch)) + 1
        ) >= s.qu_inst
        THEN 0
      ELSE
        (s.qu_inst - (
         (YEAR('2020-04-30') - YEAR(s.date_purch)) * 12 +
         (MONTH('2020-04-30') - MONTH(s.date_purch)) + 1
        )) * i.inst
END AS zalishok_bez_borgu
FROM installment_plan i
LEFT JOIN paid_to_date p
    ON i.merchant_id = p.merchant_id
   AND i.contract_number = p.contract_number
LEFT JOIN should_be_paid s
    ON i.merchant_id = s.merchant_id
   AND i.contract_number = s.contract_number
) , calendar AS
--Календарь платежів
(
SELECT
    i.merchant_id,
    i.contract_number,
    DATEADD(month, n.n, i.date_purch) AS plan_month
FROM installment_plan i
JOIN numbers n
    ON n.n < i.qu_inst
), 
  calendar_paid AS --Чи був платіж у місяці
(
SELECT
    c.merchant_id,
    c.contract_number,
    YEAR(c.plan_month) AS y,
    MONTH(c.plan_month) AS m,

    CASE
        WHEN SUM(p.payment) IS NULL THEN 0
        ELSE 1
    END AS paid_flag
FROM calendar c
LEFT JOIN payments p
    ON p.merchant_id = c.merchant_id
   AND p.contract_number = c.contract_number
   AND YEAR(p.date_payment) = YEAR(c.plan_month)
   AND MONTH(p.date_payment) = MONTH(c.plan_month)
GROUP BY
    c.merchant_id,
    c.contract_number,
    YEAR(c.plan_month),
    MONTH(c.plan_month)
), missed_months AS --Кількість пропущених місяців
(
SELECT
    merchant_id,
    contract_number,
    SUM(CASE WHEN paid_flag = 0 THEN 1 ELSE 0 END) AS missed_cnt
FROM calendar_paid
GROUP BY merchant_id, contract_number
)
SELECT
    z.period_1,
    z.statys_borg,

    COUNT(*) cnt_CL,
    SUM(z.sum_vsnosov) AS suma_rassrochki,
    SUM(z.should_paid_to_date) AS sum_oplat,
    SUM(z.total_payment) AS splacheno,
    SUM(z.borg) AS prostrochka,
    SUM(z.zalishok_bez_borgu) AS zalishok,
    --кол. кл. з прострочкою 
    SUM(CASE WHEN mm.missed_cnt = 0 THEN 1 ELSE 0 END) AS pros_con0,
    SUM(CASE WHEN mm.missed_cnt = 1 THEN 1 ELSE 0 END) AS pros_con1,
    SUM(CASE WHEN mm.missed_cnt = 2 THEN 1 ELSE 0 END) AS pros_con2,
    SUM(CASE WHEN mm.missed_cnt = 3 THEN 1 ELSE 0 END) AS pros_con3,
    SUM(CASE WHEN mm.missed_cnt >= 4 THEN 1 ELSE 0 END) AS pros_con4,
    --сума боргу. кл. з прострочкою
    SUM(CASE WHEN mm.missed_cnt = 0 THEN z.borg ELSE 0 END) AS borg_0,
    SUM(CASE WHEN mm.missed_cnt = 1 THEN z.borg ELSE 0 END) AS borg_1,
    SUM(CASE WHEN mm.missed_cnt = 2 THEN z.borg ELSE 0 END) AS borg_2,
    SUM(CASE WHEN mm.missed_cnt = 3 THEN z.borg ELSE 0 END) AS borg_3,
    SUM(CASE WHEN mm.missed_cnt >= 4 THEN z.borg ELSE 0 END) AS borg_4
FROM zav1_3 z
LEFT JOIN missed_months mm
    ON z.merchant_id = mm.merchant_id
   AND z.contract_number = mm.contract_number
GROUP BY z.period_1, z.statys_borg
