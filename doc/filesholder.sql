create table filesholder_dir (
   id SERIAL primary key not null,

   timestamp timestamp not null default current_timestamp,

   path varchar(255) not null unique,
   name varchar(255) not null,


   files integer not null default 0,
   subdirs integer not null default 0,
   parent_id integer,

   comment text,

   user_id integer,

   unique (parent_id,name),
   foreign key (parent_id) references filesholder_dir (id)
   on delete cascade on update cascade
);

create table filesholder_file (
   id SERIAL primary key not null,
   dir_id integer not null,
   file varchar(255) not null,
   name varchar(255) not null,
   comment text,
   type varchar(10) not null default 0,
   -- video, music, image, programm, archive, other


   -- Параметры пиктограммы или тп
   thumb_width integer,
   thumb_height integer,
   thumb_file varchar(200),

   -- Параметры медиа файла, если это медиа файл
   media_width integer,
   media_height integer,
   length_secs long,

   timestamp timestamp not null default current_timestamp,

   size bigint not null default 0,

   user_id integer,

   unique (dir_id,file),
   unique (dir_id,name),
   foreign key (dir_id) references filesholder_dir (id)
   on delete cascade
   on update cascade
);
