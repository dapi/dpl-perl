package dpl::Db::Database;
use strict;
use DBI;
use dpl::Context;
use dpl::Log;
use dpl::Error;
use dpl::Error::Db;
use dpl::Config;
use dpl::XML;
use dpl::Base;
use Time::HiRes;
use Exporter;
use Error qw(:try);


use vars qw(@ISA
	    @EXPORT
	    $VERSION
	    $CURRENT_DB
            $RV
            $DS_XML
            $equery
	   );

@ISA = qw(Exporter
	  dpl::Base);

( $VERSION ) = '$Revision: 1.8 $ ' =~ /\$Revision:\s+([^\s]+)/;
$DS_XML='datasource';

@EXPORT = qw(db
             SetDefaultDb
             Query
             Fetch
             SuperSelect
             SuperSelectAndFetch
             SuperSelectAndFetchAll);


sub SetDefaultDb {
  my $db = shift;
  setContext('dbs','default',$db);
}

sub db {
  my $name = shift || 'default';
  return context('dbs',
		 $name) || setContext('dbs',$name,
				      dpl::Db::Database->instance($name,@_));
}

sub to_el {
  my ($self) = @_;
#  use el::Db;
  my $db = el::Db->new();
  $db->{dbh}=$self->{dbh};
  return $db;
}

sub init {
  my ($self,$name,$param) = @_;
  return $param ? $self->initDb($param) : $self->initDbXML(config()->root());
}

sub initDbXML {
  my ($self,$config) =@_;
  my $config = config()->root();
  my $q = "\@name='$self->{name}'";
  $q.=" or not(\@name)" if $self->{name} eq 'default';
  my $node = $config->findnodes("./databases/database[$q]")->pop() ||
    throw("No config for this database '$self->{name}'");
  my $ds_node = $node->findnodes("./$DS_XML")->pop() ||
    throw("No datasource node for database '$self->{name}'");
  my %d;
  $d{datasource} = $ds_node->findvalue(".") ||
    throw("No datasource defined for database '$self->{name}'");
  $d{character_set} = xmlDecode($node->getAttribute('character_set')) if $node->hasAttribute('character_set');
  $d{user} = xmlDecode($node->getAttribute('user')) if $node->hasAttribute('user');
  $d{password} = xmlDecode($node->getAttribute('password')) if $node->hasAttribute('password');
  $d{quote_tables} = xmlDecode($node->getAttribute('quote_tables')) if $node->hasAttribute('quote_tables');
  $d{attr} = xmlAttrToHash($ds_node);
  $self->{config} = $config;
  $self->initDb(\%d);
  return $self;
}

sub initDb {
  my ($self,$param) = @_;
  foreach (keys %$param) {
    $self->{$_} = $param->{$_};
  }
#  $self->{attr}->{RaiseError}=1;
  $self->{attr}->{HandleError}=dpl::Error::Db->handler();
  return $self;
}

sub LockTables {
  my ($self,$type) = (shift,shift);
  $self->Connect(1);
  my $sth = $self->{dbh}->prepare_cached("LOCK TABLES ".join(', ',map {"$_ $type"} @_));
  return $self->execute($sth);
}
sub UnlockTables {
  my $self = shift;
  $self->Connect(1);
  my $sth = $self->{dbh}->prepare_cached("UNLOCK TABLES");
  return $self->execute($sth);
}

sub GetLock {
  my $self  = shift;
  $self->Connect(1);
  my $sth = $self->{dbh}->prepare_cached("select get_lock(?,?)");
  $self->execute($sth,@_);
  my ($res)=$sth->fetchrow_array($sth);
  return $res;
}

sub ReleaseLock {
  my ($self,$name)  = @_;
  $self->Connect(1);
  my $sth = $self->{dbh}->prepare_cached("select release_lock(?)");
  $self->execute($sth,$name);
  my ($res)=$sth->fetchrow_array($sth);
  return $res;
}


sub GetLastIncrement {
  my ($self,$table,$id,$seq) = @_;
  if ($self->{datasource}=~/^DBI:Pg/) {
    $seq=$table.'_'.$id.'_seq' unless $seq;
#    fatal("Sequence is not selected") unless $seq;
    my $sth = $self->Query("select currval(?)",$seq);
    return $self->FetchOne($sth)->{currval};
  } else {
    my $sth = $self->Select("select LAST_INSERT_ID() as id");
    my $a = $self->FetchOne($sth);
    return $a->{id};
  }

}

sub Select {
  my $self = shift;
  return $self->Query(@_) if scalar @_ == 1;
  my ($table,$fields,$where,$extra)=@_;
  my @bind;
  my $w = $self->prepareData($where,'and',\@bind,1);
  $w="WHERE $w" if $w;
  $fields=join(';',@$fields) if ref($fields)=~/ARRAY/;
  $fields='*' unless $fields;
  my $query = "SELECT $fields FROM ".$self->quoteTable($table)." $w";
  $query="$query $extra" if $extra;

  $self->Connect(1);
#  logger('sql')->debug($query,' -values are- ',@bind);
  $equery=$query;
  my $sth = $self->{dbh}->prepare($query);
  my $rv  = $self->execute($sth,@bind);

  return $sth;
}

sub Query {
  my $self = UNIVERSAL::isa($_[0], 'dpl::Db::Database') ? shift : db();
#  my $self = shift;
  my ($query,@bind)=@_;
  $self->Connect(1);
  #  logger('sql')->debug($query,join(';',@bind));
  $equery=$query;
  my $sth = $self->{dbh}->prepare($query);
  my $rv  = $self->execute($sth, @bind);
  $RV=$rv;
  return $sth;
}

sub Update {
  my $self = shift;
  my ($table,$data,$pwhere)=@_;
  my @sbind;
  my @wbind;
  my $set   = $self->prepareData($data,',',\@sbind);
  my $where = $self->prepareData($pwhere,'and',\@wbind,1);
  $where="WHERE $where" if $where;
  my $query="UPDATE ".$self->quoteTable($table)." SET $set $where";
  throw("Неуказано что изменять")
    unless $set;
  logger('sql')->debug($query,join(';',@sbind),join(';',@wbind));
  $self->Connect(1);
  return $self->{dbh}->do($query,undef,map {"$_"} @sbind,map {"$_"} @wbind);
}

sub Insert {
  my ($self,$table,$data)=@_;
  throw("No data to insert")
    unless $data && %$data;
  my @bind;
  my $values  = $self->prepareData($data,',',\@bind,2);
  my $query   = "INSERT INTO ".$self->quoteTable($table)." (".join(',',keys %$data).") values ($values)";
#  logger('sql')->debug($query,join(';',@bind));
  $self->Connect(1);
  $equery=$query;
  my $sth = $self->{dbh}->prepare($query);
  my $res = $self->execute($sth,@bind);
  return $res;
}

sub Replace {
  my ($self,$table,$data)=@_;
  throw("No data to replace")
    unless $data && %$data;
  my @bind;
  my $values  = $self->prepareData($data,',',\@bind,2);
  my $query   = "REPLACE INTO ".$self->quoteTable($table)." (".join(',',keys %$data).") values ($values)";
#  logger('sql')->debug($query,@bind);
  $self->Connect(1);
  $equery=$query;
  my $sth = $self->{dbh}->prepare($query);
  my $res = $self->execute($sth,@bind);
  return $res;
}



sub Delete {
  my $self = shift;
  my ($table,$where)=@_;
  my @bind;
  $where = $self->prepareData($where,'and',\@bind,1);
  $where="WHERE $where" if $where;
  my $query="DELETE FROM ".$self->quoteTable($table)." $where";
  logger('sql')->debug($query,@bind);
  $self->Connect(1);
  return $self->{dbh}->do($query,undef,@bind);
}

sub throw {
  throw dpl::Error::Db(-text=>join(';',@_));
}

sub Transaction (&@) {
  my ($self,$code) = (shift,shift);
  return try {
    my $res=&$code(@_);
    $self->Commit();
    return $res;
  } otherwise {
    my $e = shift;
    $self->Rollback();
    $e->throw();
  };
}

sub Commit {
  my $self = shift;
  logger('sql')->debug('COMMIT');
  $self->Connect(1);
  return $self->{dbh}->{AutoCommit} ? undef : $self->{dbh}->commit();
}

sub Begin {
  my $self = shift;
  logger('sql')->debug('BEGIN');
  $self->Connect(1);
  my $res = $self->{dbh}->begin_work();
  my $l = shift;
  $self->Query($l)
    if $l;
  return $res;
}

sub Rollback {
  my $self = shift;
  logger('sql')->debug('ROLLBACK');
#  $self->Connect();
  return $self->{dbh} ? $self->{dbh}->rollback() : undef;
}

sub GenerateId {
  my ($self,$table) = @_;
  my $query=$self->{generator};
  $query=~s/\?/$table/;
  $self->Connect(1);
  $equery=$query;
  my $sth = $self->{dbh}->prepare($query);
  my $rv  = $self->execute($sth);
  my $res=$self->Fetch($sth);
  $sth->finish();
  return (each %$res)[1]+0;
}

sub Fetch {
  my $self = UNIVERSAL::isa($_[0], 'dpl::Db::Database') ? shift : db();
  my $sth = shift;
  return $sth->fetchrow_hashref($self->{fieldsName} eq 'low' ? 'NAME_lc' : $self->{fieldsName} eq 'up' ? 'NAME_uc' : 'NAME');
}

sub FetchAll {
  my $self = shift;
  my ($sth,$key)=@_;
  my (@a,%h);
  while ($_=$sth->fetchrow_hashref($self->{fieldsName} eq 'low' ? 'NAME_lc' : $self->{fieldsName} eq 'up' ? 'NAME_uc' : 'NAME')) {
    if ($key) {
      $h{$_->{$key}}=$_;
    } else {
      push @a,$_;
    }
  }
  $sth->finish();
  return $key ? \%h : \@a;
}

sub FetchOne {
  my $self = shift;
  my ($sth)=@_;
  my (@a,%h);
  my $d=$sth->fetchrow_hashref($self->{fieldsName} eq 'low' ? 'NAME_lc' : $self->{fieldsName} eq 'up' ? 'NAME_uc' : 'NAME');
  $sth->finish();
  return $d;
}

sub SuperSelect {
  my $self = UNIVERSAL::isa($_[0], 'dpl::Db::Database') ? shift : db();
  my ($query,@bind)=@_;
#  die dpl::Db::Database::db();
  $self->Connect(1);
  #  logger('sql')->debug($query,join(';',@bind));
  $equery=$query;
  my $sth = $self->{dbh}->prepare($query);
  my $rv  = $self->execute($sth, @bind);
  return $sth;
}

sub SuperSelectAndFetchAll {
  my $self = UNIVERSAL::isa($_[0], 'dpl::Db::Database') ? shift : db();
  return $self->FetchAll($self->SuperSelect(@_));
}

sub SuperSelectAndFetch {
  my $self = UNIVERSAL::isa($_[0], 'dpl::Db::Database') ? shift : db();
  return $self->FetchOne($self->SuperSelect(@_));
}


sub SelectAndFetchAll {
  my $self = shift;
  return undef unless my $sth=$self->Select(@_);
  return $self->FetchAll($sth);
}

sub SelectAndFetchOne {
  my $self = shift;
  return undef unless my $sth=$self->Select(@_);
  return $self->FetchOne($sth);
}

sub prepareData {
  my $self = shift;
  my ($data,$logic,$bind,$type)=@_;
  my $str;
  if ($logic eq '-') {
    push @$bind,ref($data) ? @$data : $data;
  } else {
    if (ref($data)=~/ARRAY/) {
      foreach (@$data) {
	my $add='';
	if (ref($_)) {
	  $add.=$self->prepareData($_,$logic,$bind);
	} else {
	  $add=$_;
	}
	$str.=$str ? " $logic $add " : $add if $add;
      }
    } elsif (ref($data)=~/HASH/) {
      foreach (keys %$data) {
	my $add='';
	if (ref($data->{$_}) || $_ eq '-') {
	  $add = $self->prepareData($data->{$_},$_,$bind,1);
	} else {
	  if (defined $data->{$_}) {
	    $add= $type==2 ? '?' : "$_=?";
	    push @$bind,$data->{$_};
	  } else {
	    $add= $type==2 ? 'NULL' : $type ? "$_ is NULL" : "$_=NULL";
	  }
	}
	$str.=$str ? " $logic $add " : $add if $add;
      }
    } elsif ($data) {
      $str=$data;
    }
  }
  return $type==1 && $str ? "($str)" : $str;
}

sub quoteTable {
  my ($self,$table) = @_;
  return $table unless $self->{quote_tables};
  return "\"$table\"";
}

sub Connect {
  my $self = shift;
#  my $inter = shift;
#  return if $inter && $self->{dbh};
  logger('sql')->debug("connect to database '$self->{datasource}', user: $self->{user}, attr",join(',',map {"$_=>$self->{attr}->{$_}"} keys %{$self->{attr}}))
    unless $self->{dbh};
#  unless ($self->{dbh}) {
    $self->{dbh}=DBI->
      connect_cached($self->{datasource},
                     $self->{user},
                     $self->{password},
                     $self->{attr});
 # }
  if ($self->{character_set}) {
    $self->{dbh}->do("set character set $self->{character_set}");
  }
}

sub DESTROY {
  my $self = shift;
  $self->Disconnect();
}

sub Disconnect {
  my $self = shift;
  return undef unless $self->{dbh};
  #    log_info('error',awe::Log::lastError());
  #		awe::Log::lastError() ? dbRollback() :	dbCommit();
  logger('sql')->debug('disconnect');

  #
  # The is the method to suppredd the rollback executed in the Apache::DBI, otherwise
  # it writes the not fatal error to the STDERR

  #
  # This method MUST NOT BE USED under common DBI (not Apache::DBI);
  #

  $self->{dbh}->{AutoCommit}=1 if $self->{datasource}=~/interbase/i;
  $self->{dbh}->disconnect();
  $self->{dbh}->{AutoCommit}=0 if $self->{datasource}=~/interbase/i;
  $self->{dbh} = undef;
}


sub execute {
  my ($self,$sth)=(shift,shift);
  return undef unless $sth;
  my $t = [ Time::HiRes::gettimeofday() ];
#  logger('sql')->debug("execute: ",$sth,join(',',@_));
  my $rv = $sth->execute(@_);
  my $i = Time::HiRes::tv_interval($t, [ Time::HiRes::gettimeofday() ]);
  $equery=~s/\n//gm;
  logger('sql')->debug($equery,';',join(';',@_),". TIME=$i");
  return $rv;
}


1;

__END__

=head1 NAME

  dpl::Db::Database

=head1 XML




=head1 AUTHOR

Danil Pismenny <danil@orionet.ru>

=cut
