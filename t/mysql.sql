create database dpl_test;
connect dpl_test;

create table test (
        id integer auto_increment primary key,
	name VARCHAR(20), 
	sex CHAR(1),
	birth DATE,
	death TIMESTAMP);
