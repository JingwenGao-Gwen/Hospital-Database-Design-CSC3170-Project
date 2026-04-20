/* =========================================================
   INDEXES FOR CSC3170_HOSPITAL (MATCHED VERSION)
   ========================================================= */


/* =========================================================
   1. PATIENTS
   ========================================================= */

/* Foreign Keys */
USE csc3170_hospital;
CREATE INDEX idx_patients_province_id
ON PATIENTS(province_id);

CREATE INDEX idx_patients_pec_id
ON PATIENTS(pec_id);

/* Name search */
CREATE INDEX idx_patients_name
ON PATIENTS(last_name, first_name);

/* Phone */
CREATE INDEX idx_patients_phone
ON PATIENTS(phone);



/* =========================================================
   2. DOCTORS
   ========================================================= */

/* Foreign Keys */
CREATE INDEX idx_doctors_dept_id
ON DOCTORS(dept_id);

CREATE INDEX idx_doctors_dec_id
ON DOCTORS(dec_id);

/* Name */
CREATE INDEX idx_doctors_name
ON DOCTORS(last_name, first_name);

/* speciality */
CREATE INDEX idx_doctors_speciality
ON DOCTORS(speciality);



/* =========================================================
   3. DEPARTMENTS
   ========================================================= */

/* Optional */
CREATE INDEX idx_departments_name
ON DEPARTMENTS(dept_name);



/* =========================================================
   4. ADMISSIONS
   ========================================================= */

/* Foreign Keys */
CREATE INDEX idx_admissions_patient_id
ON ADMISSIONS(patient_id);

CREATE INDEX idx_admissions_doctor_id
ON ADMISSIONS(attending_doctor_id);

CREATE INDEX idx_admissions_dept_id
ON ADMISSIONS(admission_dept_id);

/* Date */
CREATE INDEX idx_admissions_date
ON ADMISSIONS(admission_date);

/* Composite */
CREATE INDEX idx_admissions_patient_date
ON ADMISSIONS(patient_id, admission_date);



/* =========================================================
   5. DISCHARGES
   ========================================================= */

/* Foreign Keys */
CREATE INDEX idx_discharges_admission_id
ON DISCHARGES(admission_id);

CREATE INDEX idx_discharges_dept_id
ON DISCHARGES(discharge_dept_id);

CREATE INDEX idx_discharges_doctor_id
ON DISCHARGES(discharge_doctor_id);

/* Date */
CREATE INDEX idx_discharges_date
ON DISCHARGES(discharge_date);



/* =========================================================
   6. TREATMENT_LOG
   ========================================================= */

/* Foreign Keys */
CREATE INDEX idx_treatment_admission_id
ON TREATMENT_LOG(admission_id);

CREATE INDEX idx_treatment_doctor_id
ON TREATMENT_LOG(examining_doctor_id);

/* to_dept_id */
CREATE INDEX idx_treatment_dept_id
ON TREATMENT_LOG(to_dept_id);

/* Date */
CREATE INDEX idx_treatment_date
ON TREATMENT_LOG(exam_date);

/* Composite */
CREATE INDEX idx_treatment_admission_date
ON TREATMENT_LOG(admission_id, exam_date);



/* =========================================================
   7. EMERGENCY CONTACT (OPTIONAL)
   ========================================================= */

CREATE INDEX idx_pec_phone
ON PATIENT_EMERGENCY_CONTACT(phone);

CREATE INDEX idx_dec_phone
ON DOCTOR_EMERGENCY_CONTACT(phone);