# School Database Design

## 1. Overview

The School Database is designed to manage students, courses, and student enrolments. It stores student contact information, course details, and the grades students receive in their courses. The database uses SQLite and relational database principles to maintain data consistency and reduce unnecessary duplication.

## 2. Table Descriptions

### Students

The `students` table stores information about each student. It contains `student_id`, `first_name`, `last_name`, and `email`. The student ID is the primary key and uniquely identifies each student. The email field is required and has a UNIQUE constraint to prevent duplicate email addresses.

### Courses

The `courses` table stores information about courses offered by the school. It contains `course_id`, `course_name`, and `course_description`. The course ID is the primary key. The course name is required and unique so that the same course name cannot be entered more than once.

### Enrolments

The `enrolments` table records which students take which courses. It contains `enrolment_id`, `student_id`, `course_id`, and `grade`. The enrolment ID is the primary key, while student ID and course ID are foreign keys referencing the `students` and `courses` tables. The grade belongs in this table because it depends on the particular student-course combination.

The UNIQUE constraint on `(student_id, course_id)` prevents a student from being enrolled in the same course twice.

## 3. Relationships

### One-to-Many Relationships

A student can have multiple enrolments, but each enrolment belongs to one student. This creates a one-to-many relationship between `students` and `enrolments`.

Similarly, a course can have multiple enrolments, but each enrolment refers to one course. This creates a one-to-many relationship between `courses` and `enrolments`.

### Many-to-Many Relationship

Students and courses have a many-to-many relationship. One student may study several courses, and each course may contain several students.

A join table, `enrolments`, is necessary to represent this relationship in a relational database. It connects the student and course records through foreign keys and stores additional information, such as the student's grade for each course. Without the join table, the design would be more difficult to maintain and could require repeating course or student information.

## 4. Index Recommendation

I would add an index on `enrolments(course_id)` to support queries that retrieve students enrolled in a particular course and calculate enrolment counts. This can improve lookup performance as the number of enrolments increases. The UNIQUE constraint on `(student_id, course_id)` already creates an index in SQLite, so a separate index on `student_id` is not essential for this initial design. The proposed course index may still be useful because the existing composite index begins with `student_id`, not `course_id`.

Example:

```sql
CREATE INDEX idx_enrolments_course_id
ON enrolments(course_id);
```

## 5. SQL or NoSQL?

I would choose a relational SQL database for this school management system. The data has a clear structure, with students, courses, enrolments, and grades connected through well-defined relationships. SQL supports primary keys, foreign keys, UNIQUE constraints, and joins, which help maintain data integrity and retrieve related information efficiently. Transactions are also useful for keeping related changes consistent. A NoSQL database can be useful for flexible or unstructured data, but it would not provide an advantage for the core requirements of this system. SQLite is suitable for a small project because it is lightweight, requires minimal setup, and supports the SQL features needed here.
