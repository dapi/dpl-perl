package dpl::Error::Db::Unknown; @dpl::Error::Db::Unknown::ISA = qw(dpl::Error::Db);
package dpl::Error::Db::H; @dpl::Error::Db::H::ISA = qw(dpl::Error::Db);
package dpl::Error::Db::DRH; @dpl::Error::Db::DRH::ISA = qw(dpl::Error::Db::H);
package dpl::Error::Db::DBH; @dpl::Error::Db::DBH::ISA = qw(dpl::Error::Db::H);
package dpl::Error::Db::STH; @dpl::Error::Db::STH::ISA = qw(dpl::Error::Db::H);
package dpl::Error::Db; @dpl::Error::Db::ISA = qw(dpl::Error);


# the code stolen from Error::Db

#use dpl::Error::Db::Unknown;
#use dpl::Error::Db::H;
#use dpl::Error::Db::DRH;
#use dpl::Error::Db::DBH;
#use dpl::Error::Db::STH;


use 5.00500;
use strict;
use dpl::Error;
use vars qw($VERSION
            @ISA
            %classes);
$VERSION = '0.91';


@ISA = qw(dpl::Error);

sub new {
  my $self  = shift;
  # было +3 но в веб-приложениях выводила ошибка в Database
  local $Error::Depth = $Error::Depth + 4; # TODO Сделать автоматиеское определение. Чтобы ошибка не выходила в Db::*
  return $self->SUPER::new(@_);
}

sub stringify {
  my $self = shift;
  my $text = defined $self->{errstr} ? $self->{errstr} : "unknown db error";
  $text="$text ($self->{err})"
    if $self->{err};
  $text="$text ($self->{-text})"
    if $self->{-text};
  $text .= sprintf(" at %s line %d.\n", $self->file, $self->line)
    unless($text =~ /\n$/s);
  return $text;
}

sub handler {
  sub {
    my ($err, $dbh, $retval) = @_;
    if (ref $dbh) {
      # Assemble arguments for a handle exception.
      my @params = ( error               => $err,
                     errstr              => $dbh->errstr,
                     err                 => $dbh->err,
                     state               => $dbh->state,
                     retval              => $retval,
                     warn                => $dbh->{Warn},
                     active              => $dbh->{Active},
                     kids                => $dbh->{Kids},
                     active_kids         => $dbh->{ActiveKids},
                     compat_mode         => $dbh->{CompatMode},
                     inactive_destroy    => $dbh->{InactiveDestroy},
                     trace_level         => $dbh->{TraceLevel},
                     fetch_hash_key_name => $dbh->{FetchHashKeyName},
                     chop_blanks         => $dbh->{ChopBlanks},
                     long_read_len       => $dbh->{LongReadLen},
                     long_trunc_ok       => $dbh->{LongTruncOk},
                     taint               => $dbh->{Taint},
                   );
      if (UNIVERSAL::isa($dbh, 'DBI::dr')) {
        # Just throw a driver exception. It has no extra attributes.
        dpl::Error::Db::DRH->throw(@params);
      } elsif (UNIVERSAL::isa($dbh, 'DBI::db')) {
#        print STDERR "- 1 --------$dbh-\n";
        # Throw a database handle exception.
        dpl::Error::Db::DBH->throw
            ( @params,
              auto_commit    => $dbh->{AutoCommit},
              db_name        => $dbh->{Name},
              statement      => $dbh->{Statement},
              row_cache_size => $dbh->{RowCacheSize}
            );
      } elsif (UNIVERSAL::isa($dbh, 'DBI::st')) {
        # Throw a statement handle exception.
        dpl::Error::Db::STH->throw
            ( @params,
              num_of_fields => $dbh->{NUM_OF_FIELDS},
              num_of_params => $dbh->{NUM_OF_PARAMS},
              field_names   => $dbh->{NAME},
              type          => $dbh->{TYPE},
              precision     => $dbh->{PRECISION},
              scale         => $dbh->{SCALE},
              nullable      => $dbh->{NULLABLE},
              cursor_name   => $dbh->{CursorName},
              param_values  => $dbh->{ParamValues},
              statement     => $dbh->{Statement},
              rows_in_cache => $dbh->{RowsInCache}
            );
      } else {
        # Unknown exception. This shouldn't happen.
        dpl::Error::Db::Unknown->throw(@params);
      }
    } else {
      # Set up for a base class exception.
      my $exc = 'dpl::Error::Db';
      # Make it an unknown exception if $dbh isn't a DBI class
      # name. Probably shouldn't happen.
      $exc .= '::Unknown' unless $dbh and UNIVERSAL::isa($dbh, 'DBI');
      if ($DBI::lasth) {
        # There was a handle. Get the errors. This may be superfluous,
        # since the handle ought to be in $dbh.
        $exc->throw( error  => $err,
                     errstr => $DBI::errstr,
                     err    => $DBI::err,
                     state  => $DBI::state,
                     retval => $retval
                   );
      } else {
        # No handle, no errors.
        $exc->throw( error  => $err,
                     retval => $retval
                   );
      }
    }
  };
}

1;
