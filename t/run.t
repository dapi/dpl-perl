BEGIN { $| = 1; print "1..1\n";}
use lib "blib/lib";
use Config::General;
use Data::Dumper;

sub pause;

print "ok\n";
print STDERR " .. ok\n";

use dpl::Conf;
use dpl::Log;
use dpl::Db::Database;
use dpl::Db::Table;

dpl::Log::Init('./t/logging.conf');
dpl::Conf::LoadDefaultXMLConfig('./t/test.xml');

db()->Connect();
table('test')->Insert({id=>10});
db()->Disconnect();

sub pause {
  # we are pausing between tests
  # so the output gets not confused
  # by stderr/stdout "collisions"
  select undef, undef, undef, 0.3;
}
