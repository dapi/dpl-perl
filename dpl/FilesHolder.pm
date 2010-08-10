package dpl::FilesHolder;
use strict;
use dpl::Error;
use dpl::Log;
use dpl::Config;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::XML;
use File::Path;
use dpl::Base;
use dpl::Context;
use URI::Escape;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Base);

sub new {
  my ($class,$home,$uri) = @_;
  my $self =  bless {}, $class; # @_в bless не ставить
  $self->{home} = $home;
  $self->{uri} = $uri;
  return $self;
}

sub RemoveFile {
  my ($self,$id) = @_;
  my $file = db()->
    SuperSelectAndFetch('select * from filesholder_file where id=? for update',
                           $id);

  return undef unless $file;

  my $dir = table('filesholder_dir')->
    Load($file->{dir_id});

  unlink "$self->{home}$dir->{path}$file->{gallery_file}"
    if $file->{gallery_file};
  unlink "$self->{home}$dir->{path}$file->{thumb_file}"
    if $file->{thumb_file};
  unlink "$self->{home}$dir->{path}$file->{src_file}"
    if $file->{src_file};

  unlink "$self->{home}$dir->{path}$file->{file}";

  table('filesholder_file')->Delete($id);

  db()->Commit();
  return $file;
}

# sub Linked {
#    my ($linked,$from,$to) = @_;
#    my %l = map {$_=>1} split(',',$linked);
#    delete $l{$from};
#    $l{$to}=1;
#    return join(',',sort keys %l);
#  }


sub RemoveLinkOfFileFromDir {
  my ($self,$file_id,$dir_id)=@_;
  my $link = db()->
    SuperSelectAndFetch('select * from filesholder_file where link_id=? and dir_id=? for update',
                        $file_id,$dir_id);

  return undef unless $link;
  my $dir = db()->
    SuperSelectAndFetch('select * from filesholder_dir where id=? for update',
                           $dir_id);
  my $file = db()->
    SuperSelectAndFetch('select * from filesholder_file where id=? for update',
                        $file_id);

  db()->
    SuperSelect('update filesholder_dir set files=files-1 where id=?',
                $dir_id);

  my %l = map {$_=>1} split(',',$file->{linked});
  delete $l{$file_id};
  db()->
    SuperSelect('update filesholder_file set linked=? where id=?',
                join(',',sort keys %l),
                $file_id);

  table('filesholder_file')->Delete($link->{id});
  db()->Commit();
}

sub RemoveLink {
  my ($self,$id) = @_;
  my $link = db()->
    SuperSelectAndFetch('select * from filesholder_file where id=? for update',
                           $id);

  return undef unless $link;
  my $file = db()->
    SuperSelectAndFetch('select * from filesholder_file where id=? for update',
                           $link->{link_id});

  my $dir = db()->
    SuperSelectAndFetch('select * from filesholder_dir where id=? for update',
                           $link->{dir_id});

  db()->
    SuperSelect('update filesholder_dir set files=files-1 where id=?',
                $link->{dir_id});

  my %l = map {$_=>1} split(',',$file->{linked});
  delete $l{$id};
  db()->
    SuperSelect('update filesholder_file set linked=? where id=?',
                join(',',sort keys %l),
                $file->{id});

  table('filesholder_file')->
    Delete($id);
  db()->Commit();
  return $link;
}

sub CreateLink {
  my ($self,$id,$dir_id) = @_;
  my $file = db()->
    SuperSelectAndFetch('select * from filesholder_file where id=? for update',
                           $id);

  return undef unless $file;

  my $dir = db()->
    SuperSelectAndFetch('select * from filesholder_dir where id=? for update',
                           $dir_id);

  db()->
    SuperSelect('update filesholder_dir set files=files+1 where id=?',
                $dir_id);

  delete $file->{id};
  delete $file->{linked};
  delete $file->{timestamp};
  $file->{dir_id}=$dir_id;
  $file->{link_id}=$id;
  my $res =
    table('filesholder_file')->
      Create($file);

  my %l = map {$_=>1} split(',',$file->{linked});
  $l{$res->{id}}=1;
  db()->
    SuperSelect('update filesholder_file set linked=? where id=?',
                join(',',sort keys %l),
                $id);

  db()->Commit();
  return $res;
}



sub CreateDir {
  my ($self,$h) = @_;
  $h->{parent_id}=undef unless $h->{parent_id};
  fatal("Unknown symbols in path") if $h->{path}=~/[^0-9_a-z\-\/]/;
  unless ($h->{path}=~/^\//) {
    if ($h->{parent_id}) {
      my $parent = db()->SuperSelectAndFetch('select * from filesholder_dir where id=? for update',$h->{parent_id});
      $h->{path}=$parent->{path}.$h->{path};
    } else {
      $h->{path}="/$h->{path}";
    }
  }
#  print STDERR "Create filesholder_dir path:$h->{path}, name:'$h->{name}', parent_id:$h->{parent_id}\n";
  my $res = table('filesholder_dir')->
    Create($h);
  db()->Query('update filesholder_dir set subdirs=subdirs+1 where id=?',$h->{parent_id})
    if $h->{parent_id};
  db()->Commit();
  return $res;
}

sub GetDirsTree {
  my ($self,$parent_id) = @_;
  my $list = table('filesholder_dir')->List({parent_id=>undef});
  return undef unless $list && @$list;
  foreach (@$list) {
    $_->{subs} = $self->GetDirsTree($_->{id})
      if $_->{subdirs};
  }
  return $list;
}

#  $g->{files}=[random_permutation(@{$g->{files}})];


sub LookFile {
  my ($self,$dir_id,$file) = @_;
  return table('filesholder_file')->
    Load({dir_id=>$dir_id,
          file=>$file});
}

sub LoadFile {
  my ($self,$file_id) = @_;
  return table('filesholder_file')->Load($file_id);
}

sub GetFile {
  my ($self,$file_id) = @_;
  my $file = table('filesholder_file')->Load($file_id);
  return undef unless $file;
  $file->{linked}=[split(',',$file->{linked})];
  $file->{linked_h}=map {$_=>1} @{$file->{linked}};
  db()->Query('update filesholder_file set views = views + 1 where id=?',$file_id);
  my $dir = table('filesholder_dir')->Load($file->{dir_id});
  $file->{prev} = db()->
    SuperSelectAndFetch("select * from filesholder_file where id<? and dir_id=? and type=? order by id desc limit 1",
                        $file->{id},$file->{dir_id},$file->{type});
  if ($file->{prev}) {
    $file->{prev}->{uri} = $self->{uri}.$file->{prev}->{path}.uri_escape($file->{prev}->{file});
  } else {
    if ($dir->{files}) {
      $file->{last} = db()->
        SuperSelectAndFetch("select * from filesholder_file where id>? and dir_id=? and type=? order by id desc limit 1",
                            $file->{id},$file->{dir_id},$file->{type});
      $file->{last}->{uri} = $self->{uri}.$file->{last}->{path}.uri_escape($file->{last}->{file})
        if $file->{last};
    }
  }

  $file->{next} = db()->
    SuperSelectAndFetch("select * from filesholder_file where id>? and dir_id=? and type=? order by id limit 1",
                        $file->{id},$file->{dir_id},$file->{type});
  if ($file->{next}) {
    $file->{next}->{uri} = $self->{uri}.$file->{next}->{path}.uri_escape($file->{next}->{file})
  } elsif ($file->{prev}) {
    $file->{start} = db()->
      SuperSelectAndFetch("select * from filesholder_file where id<? and dir_id=? and type=? order by id asc limit 1",
                          $file->{id},$file->{dir_id},$file->{type});
    $file->{start}->{uri} = $self->{uri}.$file->{start}->{path}.uri_escape($file->{start}->{file})
  }

  if ($file->{next}) {
    $file->{next_count} = db()->
      SuperSelectAndFetch("select count(*) as count from filesholder_file where id>? and dir_id=?",
                          $file->{id},$file->{dir_id});
    $file->{next_count}=$file->{next_count}->{count}
      if $file->{next_count};
  }
  if ($file->{prev}) {
    $file->{prev_count} = db()->
      SuperSelectAndFetch("select count(*) as count from filesholder_file where id<? and dir_id=?",
                          $file->{id},$file->{dir_id});
    $file->{prev_count}=$file->{prev_count}->{count}
      if $file->{prev_count};
  }

  $file->{dir} = $dir;

  $file->{uri} = $self->{uri}.$file->{path}.uri_escape($file->{file});
  $file->{src_uri} = $self->{uri}.$file->{path}.uri_escape($file->{src_file});
  return $file;
}

sub GetFiles {
  my ($self,$where,$limit,$order) = @_;
  my @b;
  my @k = keys %$where;
  foreach (@k) {
    $where->{"filesholder_file.$_"}=$where->{$_};
    delete $where->{$_};
  }
  my $w = db()->prepareData($where,'and',\@b,1);
  $w="WHERE $w" if $w;
  $order='id' unless $order;
  my $query = "select filesholder_file.*, link.rating as link_rating, link.raters as link_raters from filesholder_file
left join filesholder_file as link on link.id=filesholder_file.link_id
$w order by $order";
  if ($limit) {
    $query.=" limit ? ";
    push @b,$limit+0;
  }
  my $sth = db()->SuperSelect($query, @b);
   my @files;
  my $f;
  while ($f = $sth->fetchrow_hashref()) {
    if ($f->{link_id}) {
      $f->{raters}=$f->{link_raters};
      $f->{rating}=$f->{link_rating};
    }
    $f->{uri} = $self->{uri}.$f->{path}.uri_escape($f->{file});
    $f->{src_uri} = $self->{uri}.$f->{path}.uri_escape($f->{src_file});
    if (@files) {
      $files[$#files-1]->{next}=$f;
      $f->{prev}=$files[$#files-1];
    }
    push @files,$f;
  }
  if (@files>1) {
    $f->{start}=$files[0];
    $files[0]->{last}=$f;
  }
  return \@files;
}


sub GetDir {
  my ($self,$id,$where,$limit,$order) = @_;
  my $dir = table('filesholder_dir')->Load($id);
  $where={} unless $where;
  $where->{dir_id}=$id;
  $dir->{files} = $self->GetFiles($where,$limit,$order);
  $dir->{subs} = table('filesholder_dir')->List({parent_id=>$id});
  return $dir;
}

sub UploadFile {
  my ($self,$dir_id,$file,$name,$comment)=@_;
  fatal("No directory defined to upload") unless $dir_id;
  my $d = db()->SuperSelectAndFetch('select * from filesholder_dir where id=? for update',$dir_id);
  my $dir = $self->{home}.$d->{path};
  mkdir $dir unless -d $dir.$d->{path};
  return undef unless $file;
  my  $newfile=$file;
  $newfile=~s/^.*[\/\\]//g;
  $newfile=~s/\.\.//;
  $newfile=~s/[^a-z_0-9\-.]/_/ig;
  open(W, "> $dir$newfile") || fatal("Can't open file $dir$newfile to write");
  while (<$file>) {
    print W $_;
  }
  close(W) || fatal("Can't close file $dir$newfile");
  unless ($name) {
    $name=$file;
    $name=~s/.*\///g;
    $name=~s/.*\\//g;
    $name=~s/\..*$//g;
  }
  table('filesholder_file')->
    Create({file=>$newfile,
            name=>$name,
            comment=>$comment,
            dir_id=>$dir_id,
            size=>(stat("$dir$newfile"))[7]});
  db()->Query('update filesholder_dir set files=files+1 where id=?',$dir_id);
  db()->Commit();
  return $dir.$newfile;
}


1;
