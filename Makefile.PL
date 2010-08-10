require 5.004;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

ExtUtils::Manifest::mkmanifest;
my $version=1;
my $revision=`svnversion -n .`;
$revision=~s/\:/\./g;
#my $CONFIG_DIR='/usr/local/etc';

unlink 'MANIFEST.bak' if -f 'MANIFEST.bak';
unlink 'Makefile.old' if -f 'Makefile.old';

sub MY::libscan
  {
    my($self,$path) = @_;

    return ''
      if ($path =~ m:/(RCS|CVS|SCCS)/: ||
	  $path =~ m:[~%.]$: ||
	  $path =~ m:\.(orig|rej|nfs)$:
	 );

    $path;
  }

#sub MY::post_initialize	{"";	}


WriteMakefile(
	      NAME	   => 'dpl',
              VERSION      => "$version.$revision",
	      AUTHOR       => 'Danil Pismenny <danil@orionet.ru>',
	      ABSTRACT     => 'Danil`s Perl Library',
	      PMLIBDIRS    => [ 'lib', '$(BASEEXT)', 'dpl' ],
	      PREREQ_PM    => { 'Error'           => 0.15,
				'Apache2'        => 0,
				'XML::LibXML'   => 1.31,
                                'Digest::MD5'   => 1.31,
				'XML::LibXSLT'  => 1.31,
				'DBI'           => 1.20,
				'URI'           => 1.12,
                                'HTTP::Date'    => 0,
                                'Date::Handler' => 0,
                                'Date::Parse'   => 0,
			      },

	      dist => {COMPRESS=>'bzip2', SUFFIX=>'bz2'},
	      clean => {FILES=>'*.bz2*'}
	     );
