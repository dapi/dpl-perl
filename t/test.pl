#!/usr/bin/perl
use strict;
use Data::Dumper;
use dpl::Context;
use dpl::Config;
use dpl::Log;
use dpl::Db::Database;
use dpl::Db::Table;
dpl::Context::Init(logger_config=>'./t/logging.conf',
		   default_config=>'./t/test.xml');
db()->Connect();
my $date = new Date::Handler({ date => [2001,04,12,03,01,55]});
my $time = new Date::Handler({ date => [2001,04,12,03,01,55]});
table('test')->Insert({name=>'john',sex=>1,birth=>$date,death=>$time});
table('test')->Delete({});
table('test')->Insert({name=>'john',sex=>1,birth=>$date,death=>$time});
table('test')->Insert({name=>'billy',sex=>1,birth=>$date,death=>$time});
table('test')->Update({sex=>0},{name=>'billy'});
my $list = table('test')->List();
db()->Disconnect();
print Dumper($list);
