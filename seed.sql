-- Hospital DB: schema + realistic sample data (MySQL 8.x)
-- Covers:
-- 1) PK/FK constraints (including unique discharge per admission)
-- 2) Time logic constraints via triggers:
--    - DISCHARGES.discharge_date >= ADMISSIONS.admission_date (same-day discharge allowed)
--    - TREATMENT_LOG.exam_date within [admission_date, discharge_date] if discharged,
--      otherwise exam_date >= admission_date (and not in the future).
--    - If an admission has no TREATMENT_LOG rows, DISCHARGES.discharge_dept_id must equal
--      ADMISSIONS.admission_dept_id (no dept change without logged transfers; doctors unconstrained).

-- Create & select database (safe rerun)
CREATE DATABASE IF NOT EXISTS csc3170_hospital
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE csc3170_hospital;

SET FOREIGN_KEY_CHECKS = 0;

-- Drop order (safe rerun)
DROP TABLE IF EXISTS TREATMENT_LOG;
DROP TABLE IF EXISTS DISCHARGES;
DROP TABLE IF EXISTS ADMISSIONS;
DROP TABLE IF EXISTS DOCTORS;
DROP TABLE IF EXISTS DEPARTMENTS;
DROP TABLE IF EXISTS PATIENTS;
DROP TABLE IF EXISTS DOCTOR_EMERGENCY_CONTACT;
DROP TABLE IF EXISTS PATIENT_EMERGENCY_CONTACT;
DROP TABLE IF EXISTS PROVINCES;
SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- Tables
-- =========================

CREATE TABLE PROVINCES (
  province_id CHAR(2) PRIMARY KEY,
  province_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE PATIENT_EMERGENCY_CONTACT (
  pec_id INT PRIMARY KEY,
  first_name VARCHAR(30) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  phone VARCHAR(20) NOT NULL
);

CREATE TABLE DOCTOR_EMERGENCY_CONTACT (
  dec_id INT PRIMARY KEY,
  first_name VARCHAR(30) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  phone VARCHAR(20) NOT NULL
);

CREATE TABLE PATIENTS (
  patient_id INT PRIMARY KEY,
  first_name VARCHAR(30) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  gender CHAR(1) NOT NULL CHECK (gender IN ('M','F','O')),
  birth_date DATE NOT NULL,
  city VARCHAR(50) NOT NULL,
  allergies VARCHAR(200),
  height DECIMAL(5,2) CHECK (height IS NULL OR (height BETWEEN 40 AND 250)),
  weight DECIMAL(6,2) CHECK (weight IS NULL OR (weight BETWEEN 2 AND 400)),
  phone VARCHAR(20) NOT NULL,
  province_id CHAR(2) NOT NULL,
  pec_id INT NOT NULL,
  CONSTRAINT fk_patients_province FOREIGN KEY (province_id) REFERENCES PROVINCES(province_id),
  CONSTRAINT fk_patients_pec FOREIGN KEY (pec_id) REFERENCES PATIENT_EMERGENCY_CONTACT(pec_id)
);

CREATE TABLE DEPARTMENTS (
  dept_id INT PRIMARY KEY,
  dept_name VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE DOCTORS (
  doctor_id INT PRIMARY KEY,
  first_name VARCHAR(30) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  speciality VARCHAR(80) NOT NULL,
  years_of_exp INT NOT NULL CHECK (years_of_exp BETWEEN 0 AND 60),
  phone VARCHAR(20) NOT NULL,
  dept_id INT NOT NULL,
  dec_id INT NOT NULL,
  CONSTRAINT fk_doctors_dept FOREIGN KEY (dept_id) REFERENCES DEPARTMENTS(dept_id),
  CONSTRAINT fk_doctors_dec FOREIGN KEY (dec_id) REFERENCES DOCTOR_EMERGENCY_CONTACT(dec_id)
);

CREATE TABLE ADMISSIONS (
  admission_id INT PRIMARY KEY,
  patient_id INT NOT NULL,
  attending_doctor_id INT NOT NULL,
  admission_dept_id INT NOT NULL,
  admission_date DATE NOT NULL,
  diagnosis VARCHAR(120) NOT NULL,
  diag_severity INT NOT NULL CHECK (diag_severity BETWEEN 1 AND 5),
  CONSTRAINT fk_admissions_patient FOREIGN KEY (patient_id) REFERENCES PATIENTS(patient_id),
  CONSTRAINT fk_admissions_doctor FOREIGN KEY (attending_doctor_id) REFERENCES DOCTORS(doctor_id),
  CONSTRAINT fk_admissions_dept FOREIGN KEY (admission_dept_id) REFERENCES DEPARTMENTS(dept_id)
);

CREATE TABLE DISCHARGES (
  discharge_id INT PRIMARY KEY,
  admission_id INT NOT NULL UNIQUE,
  discharge_dept_id INT NOT NULL,
  discharge_doctor_id INT NOT NULL,
  discharge_date DATE NOT NULL,
  discharge_status CHAR(1) NOT NULL CHECK (discharge_status IN ('R','T','D')), -- Recovered/Transferred/Deceased
  CONSTRAINT fk_discharges_admission FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id),
  CONSTRAINT fk_discharges_dept FOREIGN KEY (discharge_dept_id) REFERENCES DEPARTMENTS(dept_id),
  CONSTRAINT fk_discharges_doctor FOREIGN KEY (discharge_doctor_id) REFERENCES DOCTORS(doctor_id)
);

CREATE TABLE TREATMENT_LOG (
  log_id INT PRIMARY KEY,
  admission_id INT NOT NULL,
  examining_doctor_id INT NOT NULL,
  to_dept_id INT NOT NULL,
  exam_result VARCHAR(500) NOT NULL,
  exam_date DATE NOT NULL,
  CONSTRAINT fk_treatment_admission FOREIGN KEY (admission_id) REFERENCES ADMISSIONS(admission_id),
  CONSTRAINT fk_treatment_doctor FOREIGN KEY (examining_doctor_id) REFERENCES DOCTORS(doctor_id),
  CONSTRAINT fk_treatment_to_dept FOREIGN KEY (to_dept_id) REFERENCES DEPARTMENTS(dept_id)
);

-- =========================
-- Time logic triggers
-- =========================

DROP TRIGGER IF EXISTS discharge_date_check_bi;
DROP TRIGGER IF EXISTS discharge_date_check_bu;
DROP TRIGGER IF EXISTS treatment_log_date_check_bi;
DROP TRIGGER IF EXISTS treatment_log_date_check_bu;
DROP TRIGGER IF EXISTS admissions_not_dead_bi;
DROP TRIGGER IF EXISTS admissions_not_dead_bu;
DROP TRIGGER IF EXISTS admissions_obgyn_bi;
DROP TRIGGER IF EXISTS admissions_obgyn_bu;
DROP TRIGGER IF EXISTS discharges_obgyn_bi;
DROP TRIGGER IF EXISTS discharges_obgyn_bu;
DROP TRIGGER IF EXISTS discharges_no_log_same_dept_bi;
DROP TRIGGER IF EXISTS discharges_no_log_same_dept_bu;
DROP TRIGGER IF EXISTS treatment_log_obgyn_bi;
DROP TRIGGER IF EXISTS treatment_log_obgyn_bu;

DELIMITER //

CREATE TRIGGER discharge_date_check_bi
BEFORE INSERT ON DISCHARGES
FOR EACH ROW
BEGIN
  DECLARE a_date DATE;

  SELECT admission_date INTO a_date
  FROM ADMISSIONS
  WHERE admission_id = NEW.admission_id;

  IF a_date IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'DISCHARGES.admission_id not found';
  END IF;

  IF NEW.discharge_date < a_date THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'discharge_date must be on or after admission_date';
  END IF;
END//

CREATE TRIGGER discharge_date_check_bu
BEFORE UPDATE ON DISCHARGES
FOR EACH ROW
BEGIN
  DECLARE a_date DATE;

  SELECT admission_date INTO a_date
  FROM ADMISSIONS
  WHERE admission_id = NEW.admission_id;

  IF a_date IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'DISCHARGES.admission_id not found';
  END IF;

  IF NEW.discharge_date < a_date THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'discharge_date must be on or after admission_date';
  END IF;
END//

CREATE TRIGGER treatment_log_date_check_bi
BEFORE INSERT ON TREATMENT_LOG
FOR EACH ROW
BEGIN
  DECLARE a_date DATE;
  DECLARE d_date DATE;

  SELECT admission_date INTO a_date
  FROM ADMISSIONS
  WHERE admission_id = NEW.admission_id;

  IF a_date IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'TREATMENT_LOG.admission_id not found';
  END IF;

  SELECT discharge_date INTO d_date
  FROM DISCHARGES
  WHERE admission_id = NEW.admission_id;

  IF NEW.exam_date < a_date THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'exam_date must be on/after admission_date';
  END IF;

  IF d_date IS NOT NULL AND NEW.exam_date > d_date THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'exam_date must be on/before discharge_date';
  END IF;

  IF NEW.exam_date > CURRENT_DATE() THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'exam_date cannot be in the future';
  END IF;
END//

CREATE TRIGGER treatment_log_date_check_bu
BEFORE UPDATE ON TREATMENT_LOG
FOR EACH ROW
BEGIN
  DECLARE a_date DATE;
  DECLARE d_date DATE;

  SELECT admission_date INTO a_date
  FROM ADMISSIONS
  WHERE admission_id = NEW.admission_id;

  IF a_date IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'TREATMENT_LOG.admission_id not found';
  END IF;

  SELECT discharge_date INTO d_date
  FROM DISCHARGES
  WHERE admission_id = NEW.admission_id;

  IF NEW.exam_date < a_date THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'exam_date must be on/after admission_date';
  END IF;

  IF d_date IS NOT NULL AND NEW.exam_date > d_date THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'exam_date must be on/before discharge_date';
  END IF;

  IF NEW.exam_date > CURRENT_DATE() THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'exam_date cannot be in the future';
  END IF;
END//

DELIMITER ;

-- Obstetrics & Gynecology dept id must match DEPARTMENTS (Excel: dept_id=4)
-- Business rule: only female patients (gender='F') may use OB/GYN (admission / discharge dept / treatment log to_dept).

DELIMITER //

CREATE TRIGGER admissions_not_dead_bi
BEFORE INSERT ON ADMISSIONS
FOR EACH ROW
BEGIN
  DECLARE n INT DEFAULT 0;
  SELECT COUNT(*) INTO n
  FROM DISCHARGES d
  JOIN ADMISSIONS a ON d.admission_id = a.admission_id
  WHERE a.patient_id = NEW.patient_id AND d.discharge_status = 'D';
  IF n > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot admit: patient already has a deceased (D) discharge';
  END IF;
END//

CREATE TRIGGER admissions_not_dead_bu
BEFORE UPDATE ON ADMISSIONS
FOR EACH ROW
BEGIN
  DECLARE n INT DEFAULT 0;
  SELECT COUNT(*) INTO n
  FROM DISCHARGES d
  JOIN ADMISSIONS a ON d.admission_id = a.admission_id
  WHERE a.patient_id = NEW.patient_id AND d.discharge_status = 'D';
  IF n > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot admit: patient already has a deceased (D) discharge';
  END IF;
END//

CREATE TRIGGER admissions_obgyn_bi
BEFORE INSERT ON ADMISSIONS
FOR EACH ROW
BEGIN
  DECLARE g CHAR(1);
  SELECT gender INTO g FROM PATIENTS WHERE patient_id = NEW.patient_id;
  IF NEW.admission_dept_id = 4 AND IFNULL(g,'') <> 'F' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Obstetrics and Gynecology admission dept is only for female patients';
  END IF;
END//

CREATE TRIGGER admissions_obgyn_bu
BEFORE UPDATE ON ADMISSIONS
FOR EACH ROW
BEGIN
  DECLARE g CHAR(1);
  SELECT gender INTO g FROM PATIENTS WHERE patient_id = NEW.patient_id;
  IF NEW.admission_dept_id = 4 AND IFNULL(g,'') <> 'F' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Obstetrics and Gynecology admission dept is only for female patients';
  END IF;
END//

CREATE TRIGGER discharges_obgyn_bi
BEFORE INSERT ON DISCHARGES
FOR EACH ROW
BEGIN
  DECLARE g CHAR(1);
  SELECT p.gender INTO g
  FROM ADMISSIONS a JOIN PATIENTS p ON p.patient_id = a.patient_id
  WHERE a.admission_id = NEW.admission_id;
  IF NEW.discharge_dept_id = 4 AND IFNULL(g,'') <> 'F' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Obstetrics and Gynecology discharge dept is only for female patients';
  END IF;
END//

CREATE TRIGGER discharges_obgyn_bu
BEFORE UPDATE ON DISCHARGES
FOR EACH ROW
BEGIN
  DECLARE g CHAR(1);
  SELECT p.gender INTO g
  FROM ADMISSIONS a JOIN PATIENTS p ON p.patient_id = a.patient_id
  WHERE a.admission_id = NEW.admission_id;
  IF NEW.discharge_dept_id = 4 AND IFNULL(g,'') <> 'F' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Obstetrics and Gynecology discharge dept is only for female patients';
  END IF;
END//

CREATE TRIGGER discharges_no_log_same_dept_bi
BEFORE INSERT ON DISCHARGES
FOR EACH ROW
BEGIN
  DECLARE adm_dept INT;
  DECLARE nlog INT DEFAULT 0;
  SELECT admission_dept_id INTO adm_dept
  FROM ADMISSIONS
  WHERE admission_id = NEW.admission_id
  LIMIT 1;
  IF adm_dept IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'DISCHARGES.admission_id not found in ADMISSIONS';
  END IF;
  SELECT COUNT(*) INTO nlog FROM TREATMENT_LOG WHERE admission_id = NEW.admission_id;
  IF nlog = 0 AND NEW.discharge_dept_id <> adm_dept THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'discharge_dept must match admission_dept when admission has no treatment_log';
  END IF;
END//

CREATE TRIGGER discharges_no_log_same_dept_bu
BEFORE UPDATE ON DISCHARGES
FOR EACH ROW
BEGIN
  DECLARE adm_dept INT;
  DECLARE nlog INT DEFAULT 0;
  SELECT admission_dept_id INTO adm_dept
  FROM ADMISSIONS
  WHERE admission_id = NEW.admission_id
  LIMIT 1;
  IF adm_dept IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'DISCHARGES.admission_id not found in ADMISSIONS';
  END IF;
  SELECT COUNT(*) INTO nlog FROM TREATMENT_LOG WHERE admission_id = NEW.admission_id;
  IF nlog = 0 AND NEW.discharge_dept_id <> adm_dept THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'discharge_dept must match admission_dept when admission has no treatment_log';
  END IF;
END//

CREATE TRIGGER treatment_log_obgyn_bi
BEFORE INSERT ON TREATMENT_LOG
FOR EACH ROW
BEGIN
  DECLARE g CHAR(1);
  SELECT p.gender INTO g
  FROM ADMISSIONS a JOIN PATIENTS p ON p.patient_id = a.patient_id
  WHERE a.admission_id = NEW.admission_id;
  IF NEW.to_dept_id = 4 AND IFNULL(g,'') <> 'F' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Treatment log to OB/GYN only for female patients';
  END IF;
END//

CREATE TRIGGER treatment_log_obgyn_bu
BEFORE UPDATE ON TREATMENT_LOG
FOR EACH ROW
BEGIN
  DECLARE g CHAR(1);
  SELECT p.gender INTO g
  FROM ADMISSIONS a JOIN PATIENTS p ON p.patient_id = a.patient_id
  WHERE a.admission_id = NEW.admission_id;
  IF NEW.to_dept_id = 4 AND IFNULL(g,'') <> 'F' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Treatment log to OB/GYN only for female patients';
  END IF;
END//

DELIMITER ;

-- =========================
-- Load Excel data
-- =========================
-- 1) pip install openpyxl
-- 2) python import_excel_to_mysql.py
-- 3) mysql -u root -p < import_data.sql
--    (PowerShell: Get-Content -Raw import_data.sql | mysql -u root -p)
