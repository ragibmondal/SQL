CREATE DATABASE DIUDB;
DROP DATABASE DIUDB;
CREATE DATABASE NSUDB;
CREATE DATABASE AUSTDB;
DROP DATABASE DIUDB;
DROP DATABASE AUSTDB;
USE DIUDB;
CREATE TABLE student(
id INT PRIMARY KEY,
name VARCHAR(50),
section CHAR(1) DEFAULT'A',
age INT CHECK(age>18)
);
/*INSERT INTO student VALUES(1,"rahim","A",23);*/
INSERT INTO student
(id,name,age)
VALUES
(7,"nabila",37);
UPDATE student  /* we can update a null column without typing where */
SET section="K"
WHERE id=1;
SET SQL_SAFE_UPDATES=0;
UPDATE student
SET age=30
WHERE section='A'; /*safe mode of korlei hobe*/


DELETE FROM student
WHERE ID=2;
ALTER TABLE student
ADD COLUMN city VARCHAR(20) DEFAULT "DHAKA";
DROP COLUMN age;
SELECT *FROM student;
UPDATE student
SET city="Dhaka"
