-- =========================================================
-- DAY 6: SCHOOL DATABASE
-- Database: SQLite
-- =========================================================

-- Enable foreign key enforcement in SQLite.
PRAGMA foreign_keys = ON;

-- Remove existing tables so the script can be run repeatedly.
DROP TABLE IF EXISTS enrolments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;


-- =========================================================
-- 1. CREATE TABLES
-- =========================================================

-- Students table: stores student information.
CREATE TABLE students (
    student_id INTEGER PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);


-- Courses table: stores available courses.
CREATE TABLE courses (
    course_id INTEGER PRIMARY KEY,
    course_name TEXT NOT NULL UNIQUE,
    course_description TEXT
);


-- Enrolments table: connects students and courses.
-- Each enrolment belongs to one student and one course.
-- The same student cannot enrol in the same course twice.
CREATE TABLE enrolments (
    enrolment_id INTEGER PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    grade TEXT,

    FOREIGN KEY (student_id)
        REFERENCES students(student_id),

    FOREIGN KEY (course_id)
        REFERENCES courses(course_id),

    UNIQUE (student_id, course_id)
);


-- =========================================================
-- 2. INSERT SAMPLE STUDENTS
-- =========================================================

INSERT INTO students (student_id, first_name, last_name, email)
VALUES
    (1, 'Alice', 'Wanjiku', 'alice@example.com'),
    (2, 'Brian', 'Otieno', 'brian@example.com'),
    (3, 'Carol', 'Achieng', 'carol@example.com');


-- =========================================================
-- 3. INSERT SAMPLE COURSES
-- =========================================================

INSERT INTO courses (course_id, course_name, course_description)
VALUES
    (1, 'Computer Science', 'Introduction to computing and programming'),
    (2, 'Database Systems', 'Database design and SQL'),
    (3, 'Mathematics', 'Foundations of applied mathematics');


-- =========================================================
-- 4. INSERT SAMPLE ENROLMENTS
-- =========================================================

INSERT INTO enrolments
    (enrolment_id, student_id, course_id, grade)
VALUES
    (1, 1, 1, 'A'),
    (2, 1, 2, 'B'),
    (3, 2, 1, 'B'),
    (4, 2, 3, 'A'),
    (5, 3, 2, 'A');


-- =========================================================
-- QUERY 1: ALL COURSES FOR ONE STUDENT, BY NAME
-- Example student: Alice Wanjiku
-- =========================================================

SELECT
    s.first_name || ' ' || s.last_name AS student_name,
    c.course_name,
    e.grade
FROM students AS s
JOIN enrolments AS e
    ON s.student_id = e.student_id
JOIN courses AS c
    ON e.course_id = c.course_id
WHERE s.first_name = 'Alice'
  AND s.last_name = 'Wanjiku'
ORDER BY c.course_name;


-- =========================================================
-- QUERY 2: ALL STUDENTS ON ONE COURSE
-- Example course: Computer Science
-- =========================================================

SELECT
    c.course_name,
    s.first_name || ' ' || s.last_name AS student_name,
    e.grade
FROM courses AS c
JOIN enrolments AS e
    ON c.course_id = e.course_id
JOIN students AS s
    ON e.student_id = s.student_id
WHERE c.course_name = 'Computer Science'
ORDER BY s.last_name, s.first_name;


-- =========================================================
-- QUERY 3: NUMBER OF STUDENTS PER COURSE
-- LEFT JOIN ensures courses with zero students also appear.
-- =========================================================

SELECT
    c.course_name,
    COUNT(e.student_id) AS number_of_students
FROM courses AS c
LEFT JOIN enrolments AS e
    ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_name
ORDER BY c.course_name;


-- =========================================================
-- QUERY 4: STUDENTS WHO HAVE NO ENROLMENTS
-- LEFT JOIN finds students without a matching enrolment.
-- =========================================================

SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    s.email
FROM students AS s
LEFT JOIN enrolments AS e
    ON s.student_id = e.student_id
WHERE e.enrolment_id IS NULL
ORDER BY s.last_name, s.first_name;


-- =========================================================
-- QUERY 5: UPDATE ONE ENROLMENT'S GRADE
-- Change Alice's Database Systems grade from B to A.
-- =========================================================

UPDATE enrolments
SET grade = 'A'
WHERE student_id = (
    SELECT student_id
    FROM students
    WHERE first_name = 'Alice'
      AND last_name = 'Wanjiku'
)
AND course_id = (
    SELECT course_id
    FROM courses
    WHERE course_name = 'Database Systems'
);


-- Display the updated enrolment to verify the change.
SELECT
    s.first_name || ' ' || s.last_name AS student_name,
    c.course_name,
    e.grade
FROM enrolments AS e
JOIN students AS s
    ON e.student_id = s.student_id
JOIN courses AS c
    ON e.course_id = c.course_id
WHERE s.first_name = 'Alice'
  AND s.last_name = 'Wanjiku'
  AND c.course_name = 'Database Systems';
