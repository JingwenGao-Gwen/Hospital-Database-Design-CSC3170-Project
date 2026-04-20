-- Task 7: Produce sample SQL queries on these relations which are 
-- of an analytical or data mining nature (up to 5% bonus mark)

USE csc3170_hospital;

-- 1. Data mining (classification) Doctor Experience vs. Patient Discharge Status
-- Predict Discharge Class (R for recovered/T for transferred/D for deceased) using Doctor Experience Level
WITH classification_data AS (
    -- Labeled training instances (items + attributes + known classes)
    SELECT
        a.admission_id AS item_id,
        dr.years_of_exp,
        -- Attribute: Doctor experience level
        CASE
            WHEN dr.years_of_exp < 5 THEN 'Junior'
            WHEN dr.years_of_exp BETWEEN 5 AND 15 THEN 'Intermediate'
            ELSE 'Senior'
        END AS doctor_experience_level,
        -- Class: Actual discharge status
        dis.discharge_status AS actual_class
    FROM ADMISSIONS a
    INNER JOIN DOCTORS dr ON a.attending_doctor_id = dr.doctor_id
    INNER JOIN DISCHARGES dis ON a.admission_id = dis.admission_id
    WHERE dis.discharge_status IS NOT NULL
),
class_frequency AS (
    -- Count how many patients fall into each class per doctor experience level
    SELECT
        doctor_experience_level,
        actual_class,
        COUNT(*) AS class_count
    FROM classification_data
    GROUP BY doctor_experience_level, actual_class
),
max_frequency AS (
    -- Find the MOST COMMON class = predicted class (classification rule)
    SELECT
        doctor_experience_level,
        MAX(class_count) AS max_count
    FROM class_frequency
    GROUP BY doctor_experience_level
)
-- Classification Output (Predictor → Class + Accuracy)
SELECT
    cd.doctor_experience_level,
    COUNT(cd.item_id) AS total_training_cases,
    -- Class distribution counts
    SUM(CASE WHEN cd.actual_class = 'R' THEN 1 ELSE 0 END) AS count_Recovered_R,
    SUM(CASE WHEN cd.actual_class = 'T' THEN 1 ELSE 0 END) AS count_Transferred_T,
    SUM(CASE WHEN cd.actual_class = 'D' THEN 1 ELSE 0 END) AS count_Deceased_D,
    -- Predicted class (most frequent outcome)
    cf.actual_class AS predicted_discharge_class,
    -- Classification accuracy %
    ROUND((mf.max_count / COUNT(cd.item_id)) * 100, 2) AS prediction_accuracy_pct
FROM classification_data cd
INNER JOIN max_frequency mf
    ON cd.doctor_experience_level = mf.doctor_experience_level
INNER JOIN class_frequency cf
    ON cd.doctor_experience_level = cf.doctor_experience_level
    AND cf.class_count = mf.max_count
GROUP BY
    cd.doctor_experience_level,
    cf.actual_class,
    mf.max_count
ORDER BY prediction_accuracy_pct DESC;


-- 2. Data mining (association) Investigate whether patients with certain allergies tend to have specific types of diagnoses
WITH total_admission_transactions AS (
    -- Total transactions (unique admissions = 100% base)
    SELECT COUNT(DISTINCT admission_id) AS total_unique_trans
    FROM ADMISSIONS
),
patient_allergy_diagnosis AS (
    -- 1 admission = 1 transaction
    SELECT
        a.admission_id,
        p.allergies AS antecedent_allergy,  -- X
        a.diagnosis AS consequent_diagnosis  -- Y
    FROM ADMISSIONS a
    INNER JOIN PATIENTS p 
        ON a.patient_id = p.patient_id
    WHERE 
        p.allergies IS NOT NULL 
)
-- Calculate Association Rules (X -> Y)
SELECT
    antecedent_allergy,
    consequent_diagnosis,
    COUNT(DISTINCT admission_id) AS transaction_count,
    -- SUPPORT = % of all transactions that contain BOTH X and Y (0-100%)
    ROUND(
        COUNT(DISTINCT admission_id) * 100.0 / (SELECT total_unique_trans FROM total_admission_transactions),
        2
    ) AS support_pct,
    -- CONFIDENCE = % of X cases that also have Y (0-100%)
    ROUND(
        COUNT(DISTINCT admission_id) * 100.0 / SUM(COUNT(DISTINCT admission_id)) OVER (PARTITION BY antecedent_allergy),
        2
    ) AS confidence_pct
FROM patient_allergy_diagnosis
GROUP BY antecedent_allergy, consequent_diagnosis
HAVING transaction_count >= 3  -- To make sure they are not rare cases
ORDER BY confidence_pct DESC, support_pct DESC;


-- 3. Data mining (clustering) Patient Grouping by Age
WITH patient_age_calculation AS (
    SELECT
        p.patient_id,
        TIMESTAMPDIFF(YEAR, p.birth_date, CURDATE()) AS patient_age
    FROM PATIENTS p
),
age_clusters AS (
    -- Create clusters
    SELECT
        patient_id,
        patient_age,
        CASE
            WHEN patient_age BETWEEN 0 AND 17   THEN 'Cluster 1: Minor (0–17)'
            WHEN patient_age BETWEEN 18 AND 44 THEN 'Cluster 2: Younger Adult (18–44)'
            WHEN patient_age BETWEEN 45 AND 64 THEN 'Cluster 3: Middle-Aged (45–64)'
            WHEN patient_age >= 65             THEN 'Cluster 4: Senior (65+)'
        END AS age_cluster
    FROM patient_age_calculation
)
-- Show cluster quality
SELECT
    age_cluster,
    COUNT(patient_id) AS total_patients,
    ROUND(AVG(patient_age), 1) AS cluster_center_avg_age,  -- Center of similar patients
    MIN(patient_age) AS min_age,                          -- Tight range = HIGH similarity
    MAX(patient_age) AS max_age,                          -- Tight range = HIGH similarity
    ROUND(STD(patient_age), 2) AS within_cluster_variation  -- LOW value = HIGH similarity
FROM age_clusters
GROUP BY age_cluster
ORDER BY cluster_center_avg_age;


-- 4. Regression analysis (out-of-syllabus but I think is of analytical nature) 
-- Predict patient's Length of Stay (LOS)
-- Regression Equation used: LOS = β₀ + β₁Age + β₂BMI + β₃Severity + β₄Doctor_Exp + β₅Allergies
WITH
-- Clean & compute features
feature_data AS (
    SELECT
        DATEDIFF(d.discharge_date, a.admission_date) AS los,
        TIMESTAMPDIFF(YEAR, p.birth_date, d.discharge_date) AS age,
        ROUND(p.weight / POWER(p.height/100, 2), 2) AS bmi,
        a.diag_severity AS severity,
        CASE WHEN p.allergies IS NOT NULL AND p.allergies != '' THEN 1 ELSE 0 END AS allergies
    FROM ADMISSIONS a
    JOIN PATIENTS p     ON a.patient_id = p.patient_id
    JOIN DISCHARGES d   ON a.admission_id = d.admission_id
    WHERE p.height > 0 AND p.weight IS NOT NULL
),
-- Precompute aggregates
regression_agg AS (
    SELECT
        COUNT(*) AS n,
        SUM(los) AS sum_y,          AVG(los) AS avg_y,
        SUM(age) AS sum_x1,        AVG(age) AS avg_x1,
        SUM(bmi) AS sum_x2,        AVG(bmi) AS avg_x2,
        SUM(severity) AS sum_x3,   AVG(severity) AS avg_x3,
        SUM(allergies) AS sum_x4,  AVG(allergies) AS avg_x4,
        
        SUM(age * los) AS sum_x1y,
        SUM(bmi * los) AS sum_x2y,
        SUM(severity * los) AS sum_x3y,
        SUM(allergies * los) AS sum_x4y,
        
        SUM(POWER(age,2)) AS sum_x1sq,
        SUM(POWER(bmi,2)) AS sum_x2sq,
        SUM(POWER(severity,2)) AS sum_x3sq,
        SUM(POWER(allergies,2)) AS sum_x4sq
    FROM feature_data
)
-- Regression coefficients
SELECT
    n AS total_samples,
    ROUND( avg_y
        - avg_x1 * (sum_x1y - sum_x1*avg_y/n) / (sum_x1sq - POW(sum_x1,2)/n)
        - avg_x2 * (sum_x2y - sum_x2*avg_y/n) / (sum_x2sq - POW(sum_x2,2)/n)
        - avg_x3 * (sum_x3y - sum_x3*avg_y/n) / (sum_x3sq - POW(sum_x3,2)/n)
        - avg_x4 * (sum_x4y - sum_x4*avg_y/n) / (sum_x4sq - POW(sum_x4,2)/n),
    4) AS beta_0_intercept,
    ROUND((sum_x1y - sum_x1*avg_y/n) / (sum_x1sq - POW(sum_x1,2)/n), 4) AS beta_1_age,
    ROUND((sum_x2y - sum_x2*avg_y/n) / (sum_x2sq - POW(sum_x2,2)/n), 4) AS beta_2_bmi,
    ROUND((sum_x3y - sum_x3*avg_y/n) / (sum_x3sq - POW(sum_x3,2)/n), 4) AS beta_3_severity,
    ROUND((sum_x4y - sum_x4*avg_y/n) / (sum_x4sq - POW(sum_x4,2)/n), 4) AS beta_4_allergies,
    ROUND(avg_y, 2) AS avg_los
FROM regression_agg;
