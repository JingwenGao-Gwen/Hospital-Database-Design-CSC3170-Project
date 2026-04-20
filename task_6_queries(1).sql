USE csc3170_hospital;
-- Limit output to 5 rows per query for readability (where applicable).

-- Query 1: Retrieve patients' basic info and their emergency contacts
SELECT 
    p.first_name, 
    p.last_name, 
    p.allergies, 
    pec.first_name AS contact_name, 
    pec.phone AS contact_phone
FROM PATIENTS p
JOIN PATIENT_EMERGENCY_CONTACT pec ON p.pec_id = pec.pec_id
LIMIT 5;

-- Query 2: Count patients by province (top 5 provinces by patient count)
SELECT 
    prov.province_name, 
    COUNT(p.patient_id) AS patient_count
FROM PATIENTS p
JOIN PROVINCES prov ON p.province_id = prov.province_id
GROUP BY prov.province_name
ORDER BY patient_count DESC
LIMIT 5;

-- Query 3: Admission and discharge timeline; ADMISSIONS links PATIENTS and DISCHARGES (routine discharge only)
SELECT 
    p.first_name, 
    p.last_name, 
    a.admission_date, 
    d.discharge_date, 
    d.discharge_status
FROM ADMISSIONS a
JOIN PATIENTS p ON a.patient_id = p.patient_id
JOIN DISCHARGES d ON a.admission_id = d.admission_id
WHERE d.discharge_status = 'R' -- 'R' = recovered (routine discharge)
LIMIT 5;

-- Query 4: Patients with an inter-department transfer during the stay, and destination department
SELECT 
    p.last_name, 
    a.diagnosis, 
    tl.exam_date AS transfer_date, 
    dept.dept_name AS transferred_to
FROM TREATMENT_LOG tl
JOIN ADMISSIONS a ON tl.admission_id = a.admission_id
JOIN PATIENTS p ON a.patient_id = p.patient_id
JOIN DEPARTMENTS dept ON tl.to_dept_id = dept.dept_id
LIMIT 5;

-- Query 5: Top 3 doctors by number of admissions handled (attending doctor)
SELECT 
    doc.last_name AS doctor_name, 
    doc.speciality, 
    COUNT(a.admission_id) AS total_admissions_handled
FROM DOCTORS doc
JOIN ADMISSIONS a ON doc.doctor_id = a.attending_doctor_id
GROUP BY doc.doctor_id, doc.speciality
ORDER BY total_admissions_handled DESC
LIMIT 3;

-- Query 6: Severe admissions (severity >= 4) with penicillin allergy noted in allergies
SELECT 
    p.first_name, 
    p.last_name, 
    p.allergies, 
    a.diagnosis, 
    a.diag_severity
FROM PATIENTS p
JOIN ADMISSIONS a ON p.patient_id = a.patient_id
WHERE a.diag_severity >= 4 
  AND p.allergies LIKE '%Penicillin%';