CREATE DATABASE IF NOT EXISTS RikkeiClinicDB;
USE RikkeiClinicDB;

DROP TABLE IF EXISTS Beds;
DROP TABLE IF EXISTS Patient_Invoices;
DROP TABLE IF EXISTS Appointments;
DROP TABLE IF EXISTS Wallets;
DROP TABLE IF EXISTS Service_Usages;
DROP TABLE IF EXISTS Services;
DROP TABLE IF EXISTS Medicines;
DROP TABLE IF EXISTS Inventory;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS Departments;
DROP TABLE IF EXISTS Patients;

CREATE TABLE Patients (
    patient_id INT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) UNIQUE NOT NULL,
    date_of_birth DATE,
    medical_status VARCHAR(20) NOT NULL DEFAULT 'Active'
);

CREATE TABLE Departments (
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

CREATE TABLE Beds (
    bed_id INT PRIMARY KEY,
    dept_id INT NOT NULL,
    patient_id INT DEFAULT NULL,
    FOREIGN KEY (dept_id) REFERENCES Departments(dept_id),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
);

INSERT INTO Patients VALUES
(1, 'Nguyen Van An', '0901111222', '1990-05-15', 'Active'),
(2, 'Tran Thi Binh', '0912222333', '1985-08-20', 'Completed'),
(3, 'Le Hoang Cuong', '0923333444', '2000-12-01', 'Active');

INSERT INTO Departments VALUES
(1, 'Emergency'),
(2, 'ICU'),
(3, 'Cardiology');

INSERT INTO Beds VALUES
(101, 1, 1),
(102, 1, NULL),
(201, 2, NULL),
(202, 2, NULL),
(301, 3, 3);

DROP PROCEDURE IF EXISTS FindAvailableBed;
DROP PROCEDURE IF EXISTS TransferPatientBed;

DELIMITER //

CREATE PROCEDURE FindAvailableBed(
    IN p_dept_id INT,
    OUT o_bed_id INT
)
BEGIN

    SELECT bed_id
    INTO o_bed_id
    FROM Beds
    WHERE dept_id = p_dept_id
    AND patient_id IS NULL
    LIMIT 1;

END //

CREATE PROCEDURE TransferPatientBed(
    IN p_patient_id INT,
    IN p_target_dept_id INT,
    OUT o_new_bed_id INT,
    OUT o_message VARCHAR(255)
)
BEGIN

    DECLARE v_patient_count INT DEFAULT 0;
    DECLARE v_dept_count INT DEFAULT 0;
    DECLARE v_current_bed INT;
    DECLARE v_patient_status VARCHAR(20);
    DECLARE v_dept_name VARCHAR(100);

    SELECT COUNT(*)
    INTO v_patient_count
    FROM Patients
    WHERE patient_id = p_patient_id;

    IF v_patient_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Patient does not exist.';
    END IF;

    SELECT medical_status
    INTO v_patient_status
    FROM Patients
    WHERE patient_id = p_patient_id;

    IF v_patient_status = 'Completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transfer rejected: Patient record already completed.';
    END IF;

    SELECT COUNT(*)
    INTO v_dept_count
    FROM Departments
    WHERE dept_id = p_target_dept_id;

    IF v_dept_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Department does not exist.';
    END IF;

    SELECT dept_name
    INTO v_dept_name
    FROM Departments
    WHERE dept_id = p_target_dept_id;

    CALL FindAvailableBed(
        p_target_dept_id,
        o_new_bed_id
    );

    IF o_new_bed_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT(
            'Transfer rejected: Department ',
            v_dept_name,
            ' has no available beds.'
        );
    END IF;

    START TRANSACTION;

    SELECT bed_id
    INTO v_current_bed
    FROM Beds
    WHERE patient_id = p_patient_id
    LIMIT 1;

    UPDATE Beds
    SET patient_id = NULL
    WHERE bed_id = v_current_bed;

    UPDATE Beds
    SET patient_id = p_patient_id
    WHERE bed_id = o_new_bed_id;

    COMMIT;

    SET o_message = CONCAT(
        'Transfer successful. New bed assigned: ',
        o_new_bed_id
    );

END //

DELIMITER ;

CALL TransferPatientBed(
    1,
    2,
    @new_bed,
    @msg
);

SELECT @new_bed AS new_bed_id,
       @msg AS message;

UPDATE Beds
SET patient_id = 999
WHERE bed_id = 201;

UPDATE Beds
SET patient_id = 998
WHERE bed_id = 202;

CALL TransferPatientBed(
    3,
    2,
    @new_bed,
    @msg
);

CALL TransferPatientBed(
    2,
    1,
    @new_bed,
    @msg
);

CALL TransferPatientBed(
    1,
    999,
    @new_bed,
    @msg
);