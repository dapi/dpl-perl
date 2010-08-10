
create table cuser (
 id SERIAL primary key not null,
 timestamp timestamp not null default now(), -- Время создания

 login varchar(255) not null unique,
 password varchar(100) not null,

 name varchar(255) not null,
 email varchar(100) not null unique,

 is_admin boolean not null default 'f',
 is_worker boolean not null default 'f',

 sign_ip inet not null,
 last_ip inet not null,

 session char(32) not null unique,
 sessiontime timestamp not null default now(),

 lasttime timestamp not null default now(),

 is_logged boolean default 'f',
 is_active boolean default 't'
);


insert into cuser
        values (1,current_timestamp,'admin','admin','admin','admin@orionet.ru',
        't','t','10.100.1.1','10.100.1.1',1,current_timestamp,current_timestamp,
        'f','t');

--
-- create table manager (
--  id SERIAL primary key not null,
--
--  comment varchar(255)
-- );


commit;
