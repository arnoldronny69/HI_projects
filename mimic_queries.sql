-- Arnoldas Girdauskas
-- Health Informatics
-- Practical task Topic 8: PostgreSQL import + query for patients with pain='unable'

\set ON_ERROR_STOP on

-- 1) Start clean so the script can be re-run safely
DROP TABLE IF EXISTS pain_unable_diagnoses CASCADE;
DROP TABLE IF EXISTS people_unable CASCADE;
DROP TABLE IF EXISTS pain_unable CASCADE;
DROP TABLE IF EXISTS vitalsign CASCADE;
DROP TABLE IF EXISTS triage CASCADE;
DROP TABLE IF EXISTS pyxis CASCADE;
DROP TABLE IF EXISTS medrecon CASCADE;
DROP TABLE IF EXISTS diagnosis CASCADE;
DROP TABLE IF EXISTS edstays CASCADE;

-- 2) Create tables 
-- Numeric identifiers are BIGINT, timestamps are timestamp without time zone
-- diagnosis/medication codes are VARCHAR to preserve leading zeros and alphanumeric ICD codes
CREATE TABLE edstays (
    subject_id BIGINT,
    hadm_id BIGINT,
    stay_id BIGINT,
    intime TIMESTAMP WITHOUT TIME ZONE,
    outtime TIMESTAMP WITHOUT TIME ZONE,
    gender VARCHAR(10),
    race VARCHAR(100),
    arrival_transport VARCHAR(100),
    disposition VARCHAR(100)
);

CREATE TABLE diagnosis (
    subject_id BIGINT,
    stay_id BIGINT,
    seq_num INTEGER,
    icd_code VARCHAR(20),
    icd_version INTEGER,
    icd_title VARCHAR(255)
);

CREATE TABLE vitalsign (
    subject_id BIGINT,
    stay_id BIGINT,
    charttime TIMESTAMP WITHOUT TIME ZONE,
    temperature REAL,
    heartrate INTEGER,
    resprate INTEGER,
    o2sat INTEGER,
    sbp INTEGER,
    dbp INTEGER,
    rhythm VARCHAR(100),
    pain VARCHAR(50)
);

CREATE TABLE triage (
    subject_id BIGINT,
    stay_id BIGINT,
    temperature REAL,
    heartrate INTEGER,
    resprate INTEGER,
    o2sat INTEGER,
    sbp INTEGER,
    dbp INTEGER,
    pain VARCHAR(50),
    acuity INTEGER,
    chiefcomplaint VARCHAR(255)
);

CREATE TABLE pyxis (
    subject_id BIGINT,
    stay_id BIGINT,
    charttime TIMESTAMP WITHOUT TIME ZONE,
    med_rn INTEGER,
    name VARCHAR(255),
    gsn_rn INTEGER,
    gsn VARCHAR(20)
);

CREATE TABLE medrecon (
    subject_id BIGINT,
    stay_id BIGINT,
    charttime TIMESTAMP WITHOUT TIME ZONE,
    name VARCHAR(255),
    gsn VARCHAR(20),
    ndc VARCHAR(30),
    etc_rn INTEGER,
    etccode VARCHAR(20),
    etcdescription VARCHAR(255)
);

-- 3) Import CSV files 
-- Empty CSV fields become SQL NULL values
\copy edstays   FROM 'edstays.csv'   WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');
\copy diagnosis FROM 'diagnosis.csv' WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');
\copy vitalsign FROM 'vitalsign.csv' WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');
\copy triage    FROM 'triage.csv'    WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');
\copy pyxis     FROM 'pyxis.csv'     WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');
\copy medrecon  FROM 'medrecon.csv'  WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');

-- 4) Row-count check after import
SELECT 'edstays' AS table_name, COUNT(*) AS row_count FROM edstays
UNION ALL SELECT 'diagnosis', COUNT(*) FROM diagnosis
UNION ALL SELECT 'vitalsign', COUNT(*) FROM vitalsign
UNION ALL SELECT 'triage', COUNT(*) FROM triage
UNION ALL SELECT 'pyxis', COUNT(*) FROM pyxis
UNION ALL SELECT 'medrecon', COUNT(*) FROM medrecon
ORDER BY table_name;

SELECT * FROM vitalsign LIMIT 5;

-- 6) Intermediate table 1
-- all vitalsign rows where pain is 'unable'
-- LOWER/TRIM makes the query robust to case or accidental surrounding spaces
CREATE TABLE pain_unable AS
SELECT *
FROM vitalsign
WHERE LOWER(TRIM(pain)) = 'unable';

-- 7) Intermediate table 2 
-- distinct patients with pain='unable', plus gender and race
-- This follows the task example by joining on subject_id, because the question asks for patients
CREATE TABLE people_unable AS
SELECT DISTINCT
    p.subject_id,
    e.gender,
    e.race
FROM pain_unable p
JOIN edstays e
    ON p.subject_id = e.subject_id;

-- 8) Final table 
-- ICD diagnosis fields + gender/race, sorted alphabetically by diagnosis title.
CREATE TABLE pain_unable_diagnoses AS
SELECT DISTINCT
    pu.subject_id,
    pu.gender,
    pu.race,
    d.icd_code,
    d.icd_version,
    d.icd_title
FROM people_unable pu
JOIN diagnosis d
    ON pu.subject_id = d.subject_id
ORDER BY d.icd_title, d.icd_code, pu.subject_id;

-- 9) Final table display
SELECT *
FROM pain_unable_diagnoses
ORDER BY icd_title, icd_code, subject_id;

-- 10) Export final table to CSV
\copy (SELECT * FROM pain_unable_diagnoses ORDER BY icd_title, icd_code, subject_id) TO 'pain_unable_diagnoses.csv' WITH (FORMAT csv, HEADER true);
