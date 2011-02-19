# -*- coding: koi8-r -*-
package dpl::Web::Forum::Topic;
use strict;
use XML::XSPF;
use XML::XSPF::Track;

use Date::Parse;
use dpl::Log;
use dpl::Context;
use dpl::System;
use dpl::Config;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Web::Forum::Base;
use dpl::FilesHolder;
use dpl::Web::Utils;
use dpl::Web::Forum::Journal;
#use dpl::Web::Forum::Processor::Base;

use dpl::Error;
use MP3::Tag;
use Audio::WMA;
use URI::Escape;
use Storable;
use Number::Format qw(:subs);
use File::PathInfo;
use File::Path;
use Image::ExifTool;
use GD;
use Exporter;
use base qw(Exporter);
use vars qw(@ISA
            %FILE_TYPES
						$VOTES_COUNT
            @EXPORT);

@ISA = qw(Exporter
          dpl::Web::Forum::Base);

%FILE_TYPES=(jpeg=>'image',jpg=>'image',gif=>'image','png'=>'image',
             wma=>'music',mp3=>'music',
#             wmv=>'movie',mov=>'movie',mpg=>'movie',mpeg=>'movie',avi=>'movie',
#             swf=>'flash',
            );
$VOTES_COUNT=30;

@EXPORT = qw(LoadTopic
             TopicInstance
             MoveTopicToDraft
             SaveDraftTopic
             PublishTopic);


# TODO
#                               ,              select for update

sub filesholder {
  setting('files_holder');
}

#  $data->{journals}=1;
#  $data->{short_text}=dpl::Web::Forum::ShortText($data->{text})
#    unless $data->{short_text};
#  $data->{short_text}=dpl::Web::Forum::ShortText($data->{short_text})
  #    if length($data->{short_text})>250;
sub checkParams {
  my $data = shift;
  delete $data->{journal_id};
  $data->{topic_type}=''
    if exists $data->{topic_type} && !$data->{topic_type};
#  $data->{image_mode}=1 if $data->{topic_type} eq 'gallery';
  foreach (qw(image_id
              place_id place_category_id
              event_date event_time event_place)) {
    if (exists $data->{$_}) {
      $data->{$_}=undef unless $data->{$_} && $data->{$_} ne '0';
    }
  }
  $data->{comment_list_mode}+=0 if exists $data->{comment_list_mode};
  if ($data->{event_id}) {
    my $event = table('topic')->Load($data->{event_id})
      || fatal("No such event $data->{event_id}");
    map {$data->{$_}=$event->{$_}} qw(place_id event_date event_time place_category_id);
    $data->{event_name}=$event->{subject};
  } elsif (defined $data->{event_id}) {
    $data->{event_id}=undef;
  }
  $data->{event_place}=table('place')->Load($data->{place_id})->{name}
    if $data->{place_id};
  $data->{place_id}=undef if defined $data->{place_id} && !$data->{place_id};
  #  $data->{image_mode}+=0 if exists $data->{image_mode};

  foreach (qw(place_id event_id place_category_id)) {
    $data->{$_}=undef if $data->{$_} eq 'no';
  }

#  die "$data->{place_id}/$data->{event_id}";
  #  $data->{category_id}=$data->{category_id} || undef if exists $data->{category_id};
  #  $data->{show_text}+=0 if exists $data->{show_text};
  #   $data->{short_text}=dpl::Web::Forum::ShortText($data->{short_text})
  #     if length($data->{short_text})>250;
}

sub SetImage {
  my $self = shift;
  my $id = shift;
  $self->CheckAccess('can_edit');
  db()->Query("update journal_topic set image_id=$id where topic_id=".$self->Get('id'));
}

sub Edit {
  my ($self,$data,$votes) = @_;
# die $votes->[0];
	
  $self->CheckAccess('can_edit');
  $data->{sign}=getUser()->Get('sign');
  $data->{change_time}='now';
  $data->{update_time}='now';
  $data->{topic_type}='' if $data->{topic_type} eq 'basic';
  $data->{change_ip}=setting('uri')->{remote_ip};
  checkParams($data);
  checkText($data);
	if ($data->{topic_type} eq 'vote') {
		foreach (0..$VOTES_COUNT) {
			my $v = $votes->[$_] || '';
			my $res = table('topic_vote')->Modify({name=>$v},
																						{topic_id=>$self->Get('id'),
																						 id=>$_,
																						});
			if ($res eq '0E0') {
				table('topic_vote')->Create({topic_id=>$self->Get('id'),
																		 id=>$_,
																		 name=>$v
																		});

			}
#			print STDERR "vote: $_ - $res\n";
		}
	}
	$data->{videos_looked}='f';
  return table('topic')->Modify($data,$self->Get('id'));
}


sub checkText {
  my $data = shift;
  return undef unless $data->{text};
  $data->{youtubes}=1
    if $data->{text}=~/youtube\.com\/watch/
			|| $data->{text}=~/rutube\.ru\/tracks/;
  $data->{escaped_text}=dpl::Web::Forum::Processor::Base::filter_escape_text($data->{text});
}

sub SaveDraftTopic {
  my ($data,$votes) = @_;
  fatal("No user") unless getUser();
  $data->{user_id}=getUser()->Get('id');
  $data->{sign}=getUser()->Get('sign');
  $data->{topic_type}='' if $data->{topic_type} eq 'basic';
  $data->{create_ip}=setting('uri')->{remote_ip};
  checkParams($data);
  checkText($data);
  
  my $t = table('topic')->Create($data);
	if ($data->{topic_type} eq 'vote') {
		foreach (0..$VOTES_COUNT) {
			table('topic_vote')->Create({topic_id=>$t->{id},
																	 id=>$_,
																	 name=>$votes->[$_]
																	});
		}
		
	}
	
	db()->Query("update fuser set draft_topics = draft_topics + 1, topics=topics+1 where id=".getUser()->Get('id'));
  return $t;
}


sub GetDefaultPublishScheme {
  my $self = shift;
  if ($self->Get('topic_type') eq 'event') {
    return (2,1);
  } elsif ($self->Get('topic_type') eq 'gallery') {
    return (4,1);
  } else {
    return (1);
  }

}

#      journal_id          ,                             

sub PublishTopic {
  my ($self,@j) = @_;

  fatal("No user") unless getUser();
#   my $topic = db()->
#     SuperSelectAndFetch('select * from topic where id=?',
#                         $topic_id);

  $self->CheckAccess('can_edit')
    unless $self->Get('journal_id');
  
  db()->Begin();
  @j=$self->GetDefaultPublishScheme() unless @j;
  # TODO                             
  my ($success,$errors);

  table('topic')->Modify({has_igo=>1},$self->Get('id'))
  	if $self->Get('topic_type') eq 'event'; #$self->Get('place_id')==5 && # gallery-club
	
  foreach my $jid (@j) {
    # $jid==$self->Get('journal_id')
    my $journal = dpl::Web::Forum::Journal::JournalInstance($jid);
    next if $journal->IsTopicLinked($self->Get('id'));
    if ($journal->HasAccess('can_create_topic')) {
      $success++
        if $journal->LinkTopic($self->Get('id'));
    } else {
      $errors++;
    }
  }

  if ($success) {
    db()->Commit();
    return 1;
  } else {
    db()->Rollback();
    return 0;
  }
  
}



sub getTempDir {
  my $self = shift;
  my $dir = $self->getTopicDir();
  my $p = "$dir/.temp";
  fatal("can't create temp dir $p, $!")
    unless -d $p || mkpath($p);
  
  return $p;
}

sub getTempArcDir {
  my $self = shift;
  my $dir = $self->getTopicDir();
  my $p = "$dir/.temp_arc";
  `rm -fr $p`;
  fatal("can't create temp arc dir $p, $!")
    unless -d $p || mkpath($p);
  return $p;
}


sub getThumbDir {
  my $self = shift;
  my $dir = $self->getTopicDir();
  my $p = "$dir/t";
  fatal("can't create thumb dir $p")
    unless -d $p || mkpath($p);
  return $p;
}

sub getSrcDir {
  my $self = shift;
  my $dir = $self->getTopicDir();
  my $p = "$dir/src";
  fatal("can't create src dir $p")
    unless -d $p || mkpath($p);
  return $p;
}

sub getGalleryDir {
  my $self = shift;
  my $dir = $self->getTopicDir();
  my $p = "$dir/g";
  fatal("can't create gallery dir $p")
    unless -d $p || mkpath($p);
  return $p;
}


sub getTopicDir {
  my $self = shift;
  my $dir = directory('topic').$self->Get('id');
  fatal("can't create topic dir $dir")
    unless -d $dir || mkpath($dir);
  return $dir;
}


#                              
sub LookFile {
  my ($self,$file) = @_;
  return undef unless $self->Get('dir_id');
  return filesholder()->LookFile($self->Get('dir_id'),$file);
}

sub LoadFile {
  my ($self,$file,$title,$o) = @_;
  $self->CheckAccess('can_upload');
  $self->makeFileDir() unless $self->Get('dir_id');
  my $src_file = dpl::Web::Utils::receiveFile($self->getTempDir(),$file) || return undef;
  return $self->AttachFile($src_file,$title,$o);
}

sub nextFilename {
  my ($self,$filename,$ext) = @_;
  my $i = 0;
  $filename=~s/^.*[\/\\]//g;
  $filename=~s/\.\.//;
  $filename=~s/\s/_/g;
  my $f = $filename;
  # TODO                                 replace
  while ($self->LookFile("$filename.$ext")) {
    $i++;
    $filename="$f-$i";
  }
  return $filename;
}

sub AttachFile {
  my ($self,$src_file,$title,$o)=@_;
  my $f = new File::PathInfo;
  $f->set($src_file) or die("file does not exist $src_file");
  my $id;
  db()->Begin();
  $self->LockTopic();
  if ($f->ext() eq 'rar' || $f->ext() eq 'zip') {
    $id=$self->attachArchive($src_file,$title,$o);
  } else {
    $id=$self->attachMediaFile($src_file,$title,$o)
  }
  return undef unless $id;
  $self->_updateAllViewInfo($id);
  db()->Commit();
  return 1;


}

sub attachMediaFile {
  my ($self,$src_file,$title,$o)=@_;
  my $f = new File::PathInfo;
  $f->set($src_file) or die("file does not exist $src_file");
  my $ext = lc($f->ext());
  my $type = $FILE_TYPES{$ext} || 'unknown';
  my $filename = $self->nextFilename($f->filename_only(),$ext);
  if ($type eq 'image') {
    return $self->attachImageFile($src_file,$filename,$ext,$title,$o);
  } elsif ($type eq 'music') {
    return $self->attachMusicFile($src_file,$filename,$ext,$title,$o);
  } elsif ($type eq 'movie') {
    return $self->attachVideoFile($src_file,$filename,$ext,$title,$o);
  } else {
    fatal("Unknown file type '$src_file' - '$ext'");
  }
}

sub file_escape {
  my $file = shift;
#  $file=~s/['"\]
  return $file;
}

sub attachArchive {
  my ($self,$src_file,$title,$o)=@_;

  my $dir = $self->getTempArcDir();
  my $sf = file_escape($src_file);
  my $cmd = $src_file=~/\.rar/ ? "/usr/local/bin/rar e $sf $dir/" : "/usr/local/bin/unzip -j $sf -d $dir/";
  `$cmd`;

  if ($?) {
    fatal("Error executing '$cmd': $?");
  }
  opendir(DIR,$dir) || fatal("Can't open directory $dir");
  my $id;
  foreach my $f (grep {/\.jpg|\.jpeg|\.gif|\.png|\.wma|\.mp3/i || -f "$dir/$_"} sort readdir(DIR)) {
    $id=$self->attachMediaFile("$dir/$f",$title,$o);
  }
  closedir(DIR);
  `rm -fr $dir`;
  unlink($src_file);
  return $id;
}

sub tran {
  my $str = shift;
  $str=~tr/                                                       ÷        \xA8\xB8/  ÷                                                               /;
  return $str;
}


sub attachVideoFile {
  my ($self,$src_file,$filename,$ext,$title,$o)=@_;
  my $dir_id = $self->Get('dir_id');
  my %h = (dir_id=>$dir_id,
           topic_id=>$self->Get('id'),
           user_id=>getUser()->Get('id'),
           src_file=>"src/$filename.$ext",
           file=>"$filename.$ext",
           name=>"$filename.$ext",
           type=>'movie',
           topic_subject=>$self->Get('subject'),
           title=>"$title",
          );
  my $info = Image::ExifTool::ImageInfo($src_file);
  ($h{media_width},$h{media_height}) = ($info->{ImageWidth},$info->{ImageHeight});
  $h{length_secs}=int($info->{TrackDuration}+0);
  $h{media_info}=tran(Storable::freeze($info));
  my $dir = $self->getTopicDir();
  my $src_dir = $self->getSrcDir();
  `cp "$src_file" "$dir/$filename.$ext"`;
  `mv "$src_file" "$src_dir/$filename.$ext"`;
  my @s = stat("$src_dir/$filename.$ext");
  $h{src_size}=$s[7] || fatal("no size of file $src_dir/$filename.$ext");
  $h{size}=$h{src_size};
  my $dir = filesholder()->
    GetDir($dir_id);
  $h{path}=$dir->{path};
  db()->Begin();
  my $res =
    table('filesholder_file')->
      Create(\%h);
  db()->
    Query("update topic set files = files + 1, movies = movies + 1, last_file_id = ?, update_time = current_timestamp where id=?",
          $res->{id},
          $self->{id});
  return $res->{id};
}


sub attachMusicFile {
  my ($self,$src_file,$filename,$ext,$title,$o)=@_;
  my $dir_id = $self->Get('dir_id');
  my %h = (dir_id=>$dir_id,
           topic_id=>$self->Get('id'),
           user_id=>getUser()->Get('id'),
           src_file=>"src/$filename.$ext",
           file=>"$filename.$ext",
           name=>"$filename.$ext",
           type=>'music',
           topic_subject=>$self->Get('subject'),
           title=>"$title",
          );

  if ($ext eq 'mp3') {
    my $mp3 = MP3::Tag->new($src_file) || fatal("Error open file: $src_file");
    my $tags = $mp3->autoinfo();
    $h{length_secs}=$mp3->total_secs_int();
    foreach (qw(title track artist album year genre)) {
      $h{"media_$_"}=tran($tags->{$_})
        if $tags->{$_};
    }
    $h{media_info}=tran(Storable::freeze($tags));
  } elsif ($ext eq 'wma') {
    my $wma  = Audio::WMA->new($src_file) || fatal("Error open file: $src_file");

    my $info = $wma->info();
    my $tags = $wma->tags();
    $h{media_info}=tran({info=>Storable::freeze($info),
                         tags=>Storable::freeze($tags)});
    $h{media_title}=tran($tags->{TITLE});
    $h{media_artist}=tran($tags->{AUTHOR});
    $h{media_album}=tran($tags->{ALBUMTITLE});
    $h{media_year}=tran($tags->{YEAR});
    $h{media_track}=tran($tags->{TRACK});
    $h{media_genre}=tran($tags->{GENRE}); #                ,                    
  } else {
    fatal("Unknown media extenstion '$ext'");
  }
  $h{title}=$h{media_title};
  my $dir = $self->getTopicDir();
  my $src_dir = $self->getSrcDir();
  `cp "$src_file" "$dir/$filename.$ext"`;
  `mv "$src_file" "$src_dir/$filename.$ext"`;
  my @s = stat("$src_dir/$filename.$ext");
  $h{src_size}=$s[7] || fatal("no size of file $src_dir/$filename.$ext");
  $h{size}=$h{src_size};
  my $dir = filesholder()->
    GetDir($dir_id);
  $h{path}=$dir->{path};
  db()->Begin();
  my $res =
    table('filesholder_file')->
      Create(\%h);
  db()->
    Query("update topic set files = files + 1, music = music + 1, last_file_id = ?, update_time = current_timestamp where id=?",
          $res->{id},
          $self->{id});
  db()->
    Query("update fuser set podcast_files = podcast_files + 1 where id=?",
          getUser()->Get('id')
         );
	$self->AddFileToPlayList(\%h);
	
  return $res->{id};
#  return "$filename.$ext";
}

sub AddFileToPlayList {
	my ($self,$t) = @_;
	my $tid = $self->Get('id');
	
	my $dir = "/usr/local/www/mirror/zhazhda/pic/topics/$tid";
	my $c = Text::Iconv->new("koi8-ru", "utf-8");
	$c->raise_error(0);

	my $xspf  = XML::XSPF->new;
	$xspf->title($c->convert($self->Get('subject')));
	$xspf->creator('dapi@zhazhda.ru');

	my $sth = db()->
		SuperSelect("select * from filesholder_file where type='music' and topic_id=$tid order by id asc");
	my @t;
	
  while (my $f = Fetch($sth)) {

		my $track = XML::XSPF::Track->new;
		
		my $n = $f->{media_artist};
		$n="$n / " if $n;
		$n.=$f->{media_title};
		
		$track->title($c->convert($n || $f->{file}));
		$track->location("http://zhazhda.ru/files/topics/$tid/".uri_escape($f->{file}));
		push @t,$track;

#		print '.';
	}
	$xspf->trackList(@t);
#	my $s = ;
	#	print "$s\n";
	my $file = "$dir/playlist.xspf";
	open(FILE, "> $file") || die "Can't open file $file ";
	
	print FILE $xspf->toString();
	close(FILE) || die "Can't close file $file ";
}


sub attachImageFile {
  my ($self,$src_file,$filename,$ext,$title,$o)=@_;
  my $src = GD::Image->new($src_file) || fatal("Error open file: $src_file");

  my $dir_id = $self->Get('dir_id');
  my $src_dir = $self->getSrcDir();

  my %h = (dir_id=>$dir_id,
           topic_id=>$self->Get('id'),
           user_id=>getUser()->Get('id'),
           file=>"$filename.$ext",
           src_file=>"src/$filename.$ext",
           gallery_file=>"g/$filename.$ext",
           thumb_file=>"t/$filename.$ext",

           name=>"$filename.$ext",
           type=>'image',
           topic_subject=>$self->Get('subject'),
           title=>"$title",
          );

  $h{is_moderated}=1
    if $self->HasAccess('foto_moderator');
  
  $src=$src->copyRotate90() if $o->{rotate}==90;
  $src=$src->copyRotate180() if $o->{rotate}==180;
  $src=$src->copyRotate270() if $o->{rotate}==270;

  $o->{logo}=$o->{logo_basic};
  ($h{size},$h{media_width},$h{media_height})=
    dpl::Web::Utils::resampleImage($src_file,$self->getTopicDir(),$filename,$ext,$src,600,600,$o);
  
  $o->{logo}=$o->{logo_gallery};
  ($h{gallery_size},$h{gallery_width},$h{gallery_height})=
    dpl::Web::Utils::resampleImage($src_file,$self->getGalleryDir(),$filename,$ext,$src,130,250,$o);

  delete $o->{logo};

  ($h{thumb_size},$h{thumb_width},$h{thumb_height})=
    dpl::Web::Utils::resampleImage($src_file,$self->getThumbDir(),$filename,$ext,$src,80,120,$o);

  `mv "$src_file" "$src_dir/$filename.$ext"`;
  my @s = stat("$src_dir/$filename.$ext");
  $h{src_size}=$s[7] || fatal("no size of file $src_dir/$filename.$ext");
  
  $h{size}=0 unless $h{size};
  $h{thumb_size}=0 unless $h{thumb_size};
  $h{gallery_size}=0 unless $h{gallery_size};
  
  my $dir = filesholder()->
    GetDir($dir_id);
  $h{path}=$dir->{path};
  $h{dir_id}=$dir_id;
  db()->Begin();
  my $res = table('filesholder_file')->
    Create(\%h);
  
  db()->
    Query("update topic set files = files + 1, images = images + 1, last_file_id = ?, update_time = current_timestamp where id=?",
          $res->{id},$self->{id});
  return $res->{id};
}

sub makeFileDir {
  my $self = shift;
  my $id = $self->Get('id');
  my $dir =
    filesholder()->
      CreateDir({topic_id=>$id,
                 user_id=>getUser()->Get('id'),
                 parent_id=>6,
                 path=>"/topics/$id/",
                 name=>$self->Get('subject')
                });
  my $res = table('topic')->Modify({dir_id=>$dir->{id}},$self->Get('id'));
  my $p = $self->getTopicDir();
  $self->{data}->{dir_id}=$dir->{id};
  return $dir;
}



# sub journal {
#   my $self = shift;
#   return $self->{journal_instance} || die "No journal instance in this topic ($self->{id})";
# }

sub LockTopic {
  my $self = shift;
  db()->
    SuperSelectAndFetch(qq(select * from topic
                           where topic.id=? for update),
                        $self->Get('id'));


}

sub TopicInstance {
  my ($id) = @_;
  my $data = LoadTopic($id) || return undef;
  return dpl::Web::Forum::Topic->instance($data);
}


sub MoveTopicToDraft {
  my ($self) = shift;
  $self->CheckAccess('can_edit');
  return undef unless $self->Get('journal_id');
  my $uid = getUser()->Get('id');
  my $id = $self->Get('id');
  db()->Begin();
  # TODO                 !
  dpl::Web::Forum::Journal::UnlinkTopic(undef,$self->Get('id'));
  db()->Commit();
}


sub Delete {
  my ($self,$force) = @_;

  $self->CheckAccess('can_delete');
  db()->Begin();
  $self->LockTopic();
  
  
  # TODO                 !

  my $sth = db()->
    SuperSelect("select * from topic_views where (is_freshed OR new_answers>0) and topic_id=? for update",
                $self->{id});
  while (my $rec = Fetch($sth)) {
    db()->
      Query("select * from fuser where id=? for update",
                $rec->{user_id});
    my @w;
    if ($rec->{is_freshed}) {
      push @w,"fresh_topics=fresh_topics-1";
    }
    if ($rec->{new_answers}) {
      push @w,"new_answers=new_answers-$rec->{new_answers}";
    }
    db()->Query("update fuser set ".join(',',@w)." where id=?",
                       $rec->{user_id});
  }

#
  dpl::Web::Forum::Journal::UnlinkTopic(undef,$self->Get('id'));
  $force=1 unless $self->Get('journal_id');
  if ($force) {
    db()->Query("delete from filesholder_file where topic_id=?",$self->{id});
    db()->Query("delete from topic_views where topic_id=?",$self->{id});
    db()->Query("delete from topic_igos where topic_id=?",$self->{id});
    db()->Query("delete from topic where id=?",$self->{id});
    db()->Query("update fuser set draft_topics=draft_topics-1 where id=?",
                $self->Get('user_id'))
      unless $self->Get('journal_id');
    db()->Query("update fuser set topics=topics-1 where id=?",
                $self->Get('user_id'));
  } else {
    db()->Query("delete from topic_views where topic_id=?",$self->{id});
    db()->Query("update filesholder_file set is_in_gallery='f', is_on_main='f' where topic_id=?",$self->{id});
    db()->Query(qq(update topic set
                        is_removed=?, remove_user_id=?
                        where id=?
                       ),'t',getUser()->Get('id'),$self->{id});
    
  }
  db()->Commit();
}


sub LoadTopic {
  my ($id) = @_;
  my $topic = db()->
    SuperSelectAndFetch(qq(select topic.*, $dpl::Web::Forum::user_fields
                           from topic
                           left join fuser on fuser.id=topic.user_id
                           where topic.id=?),
                        $id) || return undef;
  # $topic->{own_issue} = db()->
#       SuperSelectAndFetch(qq(select *
#                            from journal_topic
#                            where topic_id=? and issue_id=?),
#                           $id,$topic->{issue_id})
#         if $topic->{issue_id};
#   

  my $j = db()->
    SuperSelectAndFetch(qq(select *
                           from journal
                           where id=?),
                        1);
  my $res = db()->
    SuperSelectAndFetch(qq(select *
                           from journal_topic
                           where topic_id=?),
                        $id);
  #  die "$j->{current_issue_id}: $res";
  #                             ,                        
  if ($res) {
    map {$topic->{$_}=$res->{$_}}
      qw(is_on_top is_bold is_red is_sticky is_hot
         is_on_main
         sticky_date show_text short_text
         image_id image_mode);
    $topic->{category}=table('topic_category')->
      Load($res->{category_id})
        if $res->{category_id};
#     $topic->{issue}=table('journal_issue')->
#       Load($res->{issue_id})
#         if $res->{issue_id};
    $topic->{journal_topic}=$res;
  }
  # }
  if ($topic->{place_id}) {
    $topic->{place}=table('place')->Load($topic->{place_id});
    $topic->{event_place}=$topic->{place}->{name};

  }

  $topic->{topper}=table('fuser')->Load($topic->{topper_id})
    if $topic->{topper_id};
  $topic->{remove_user}=
    table('fuser')->
      Load($topic->{remove_user_id})
        if $topic->{remove_user_id};

  $topic->{place_category}=
    table('place_category')->
      Load($topic->{place_category_id})
        if $topic->{place_category_id};
  $topic->{event_time}=~s/\:00$//;

  if ($topic->{igos_counter} && getUser()) {
  $topic->{is_user_go}=1 
  if db()->
		SuperSelectAndFetch('select  * from topic_igos where topic_id=? and user_id=?',
		$id,getUser()->Get('id'));
  }
  return $topic;

}

sub PostComment {
  my ($self,$data) = @_;
  $self->CheckAccess('can_comment');
  $data->{topic_id}=$self->{id};
  $data->{file_id}=undef unless $data->{file_id};
  $data->{user_id}=getUser()->Get('id');
  $data->{sign}=getUser()->Get('sign') || '';
  $data->{create_ip}=setting('uri')->{remote_ip};
  db()->Begin();
  $self->LockTopic();
  if ($data->{parent_id}) {
    my $c = table('comment')->Load($data->{parent_id});
    $data->{parent_user_id}=$c->{user_id};
    $data->{file_id}=$c->{file_id}
      unless $data->{file_id};
  } else {
    #        ''     0           
    delete $data->{parent_id};
    $data->{parent_user_id}=$self->Get('user_id');
  }
  my $m;
  if ($data->{file_id}) {
    db()->
      SuperSelectAndFetch('select * from filesholder_file where id=? for update',
                          $data->{file_id});
  }
  $m = table('comment')->Create($data);
  if ($data->{file_id}) {
    db()->
      Query('update filesholder_file set comments = comments + 1, last_comment_time=current_timestamp, last_comment_id=? where id=?',
                          $m->{id},
                          $data->{file_id});
  }
  $self->
    _updateAllViewInfo($m->{id},undef,
                       $data->{parent_user_id} || $self->Get('user_id'));

  db()->Query(qq(update topic set
                        comments = comments + 1, last_comment_time = current_timestamp,
                        last_comment_id = ?, update_time = current_timestamp
                        where id=?),
                     $m->{id},$self->Get('id'));# and (last_comment_id<? or last_comment_id is null)
  db()->Commit();

  db()->Query("update fuser set comments = comments + 1 where id=?",
              getUser()->Get('id'));
  db()->Commit();
  return $m;
}

sub AddVote {
  my ($self,$data) = @_;
  $data->{topic_id}=$self->{id};
  my $v = table('topic_vote')->Create($data);
  db()->Commit();
  return $v;
}

sub DoVote {
  my ($self,$id) = @_;
  return undef unless getUser();
  my $uid = getUser()->Get('id');
	return undef if $self->Get('is_vote_closed');
	
  my $vote = table('topic_vote')->
    Load({id=>$id,
          topic_id=>$self->{id}}) || die "No such vote ($id) in topic ($self->{id})";
  my $view = $self->_getUserViewInfo($uid);
  if ($view) {
    db()->
      Query('update topic_vote set votes = votes - 1 where id=? and topic_id=?',$view->{vote_id},$self->{id})
        if $view->{vote_time};
    db()->
      Query('update topic_views set vote_id=?, vote_time=now() where topic_id=? and user_id=?',$id,$self->Get('id'),$uid);
  } else {
    db()->
      Query("insert into topic_views (vote_id,vote_time,topic_id,user_id) values (?,now(),?,?)",
            $id,$self->Get('id'),$uid);
  }
#  die join(',',keys %$view);
  db()->
    Query('update topic set votes = votes + 1 where id=?',$self->Get('id'))
      unless $view && $view->{vote_time};

  db()->
    Query('update topic_vote set votes = votes + 1 where id=? and topic_id=?',$id,$self->{id});

  #  $data->{topic_id}=$self->{id};
#  my $v = table('topic_vote')->Create($data);
  db()->Commit();
  return $vote;
}


sub DeleteComment {
  my ($self,$id,$deep) = @_;
  #  $self->CheckAccess('can_edit');
  # TOFIX new_comments, new_answers
  my $comment = db()->
    SuperSelectAndFetch('select * from comment where id=?',$id);
  $self->CheckMessageAccess($comment,'can_delete');
  return undef unless $comment;
  db()->Begin();
  $self->LockTopic();
  _deleteMessagesToDeep($id,$deep);
  my $res = db()->
    SuperSelectAndFetch("select max(id) as id from comment where topic_id=? and id>?",
                        $self->Get('id'),$id);
  db()->Commit();
  return $res ? $res->{id} : undef;

}

sub _deleteMessagesToDeep {
  my ($id,$deep) = @_;
  my $comment = SuperSelectAndFetch('select * from comment where id=? for update',$id)
    || return undef;
  if ($deep) {
    my $list = SuperSelectAndFetchAll
      (qq(select * from comment where parent_id=? for update),$id);
    foreach (@$list) {
      _deleteMessagesToDeep($_->{id},1);
    }
  } else {
    db()->Query(qq(update comment set parent_id=? where parent_id=?),
                $comment->{parent_id},$id);
    
  }
  
  db()->Query(qq(update topic set
                        comments = comments - 1
                        where id=?
                       ),$comment->{topic_id});
  db()->Query(qq(update fuser set
                        comments = comments - 1
                        where id=?
                       ),$comment->{user_id});
  
  db()->Query('delete from comment where id=?',$id);
}


sub init {
  my ($self,$data) = @_;
  $self->{data} = $data;
  $self->{id} = $data->{id};
#  filesholder()=$journal_instance->{files_holder};
#   $self->{journal_instance}->{db}=db();
#   db() = ;
#  $self->{journal_instance}=$journal_instance;
#  topic = 'topic';

#  print STDERR "topic init $self\n";
  return $self;
}

# sub LoadComment {
#   my ($self,$id) = @_;
#   my $comment = db()->
#     SuperSelectAndFetch(qq(select comment.*, fuser.login as author,
#                         fuser.thumb_file, fuser.thumb_width, fuser.thumb_height
#                         from comment
#                         left join fuser on fuser.id=topic.user_id
#                         where comment.id=?),
#                      $id);
#
#   $self=topic($comment->{topic_id}) unless $self;
#   $self->SetAccessToMessage($comment);
#   return $self->{comments}->{$id} = $comment;
# }

sub GetCommentsTree {
  # file_id -     ,                  
  my ($self,$view_info,$file_id) = @_;

#   my $uid = getUser() ? getUser()->Get('id') : undef;
#   my $last_view = $self->GetUserViewInfo();

  my $sth = $file_id ?
    db()->SuperSelect(qq(select comment.*,
        $dpl::Web::Forum::user_fields
        from comment
        left join fuser on fuser.id=comment.user_id
        where topic_id=? and file_id=?
        order by comment.id),
                             $self->{id},$file_id)
      :
        db()->SuperSelect(qq(select comment.*,
        $dpl::Web::Forum::user_fields
        from comment
        left join fuser on fuser.id=comment.user_id
        where topic_id=? order by comment.id),
                                 $self->{id});

  my %m;
  my @tree;
  my %files;
  my $lm = $self->Get('comment_list_mode') || 1;
  #|| $self->journal()->Get('comment_list_mode');
  while (my $rec = Fetch($sth)) {
    if ($rec->{file_id}) {
      if (exists $files{$rec->{file_id}}) {
        $rec->{file_id}=undef;
      } else {
        $files{$rec->{file_id}}=$rec;
        $rec->{file} = filesholder()->GetFile($rec->{file_id});
        $rec->{dir} = filesholder()->GetDir($rec->{file}->{dir_id});
      }
    }
    $rec->{is_new} = $view_info && $rec->{id}>$view_info->{last_view_comment_id};
    $rec->{access} = $self->GetMessageAccess($rec);
    $m{$rec->{id}}=$rec;
    $rec->{level}=1;
    if ($rec->{parent_id} && $lm==1) {
      my $p = $m{$rec->{parent_id}};

      if ($p) {
        $p->{childs}=[] unless $p->{childs};
        $rec->{level}+=$p->{level};
        push @{$p->{childs}}, $rec;
        if (@{$p->{childs}}>1) {
          $p->{childs}[$#{$p->{childs}}-1]->{next}=$rec;
        }
        if ($rec->{is_new}) {
          my $pp = $p;
          $p->{has_new}=1;
          $p->{comments}++;
          do {
            $pp=$m{$pp->{parent_id}};
            $pp->{has_new}=1;
            $pp->{comments}++;
          } while ($pp->{parent_id} && exists $m{$pp->{parent_id}});
        } else {

          $p->{comments}++;
          my $pp=$p;
          do {
            $pp=$m{$pp->{parent_id}};
            $pp->{comments}++;
          } while ($pp->{parent_id} && exists $m{$pp->{parent_id}});
        }
      } else {
        push @tree,$rec;
        fatal("No parent $rec->{parent_id} for comment $rec->{id}");
        logger()->error("No parent $rec->{parent_id} for comment $rec->{id}");
      }
    } else {
      push @tree,$rec;
    }
  }
  $sth->finish();
  _last_new(\@tree)
    if $view_info;
  return \@tree;
}

sub _last_new {
  my ($tree,$last_new) = @_;
  foreach my $rec (@$tree) {
    if ($rec->{is_new}) {
      $last_new->{next_new}=$rec if $last_new;
      $last_new=$rec;
    }
    $last_new=_last_new($rec->{childs},$last_new) if $rec->{childs};
  }
  return $last_new;
}


sub _updateAllViewInfo {
  my ($self,$comment_id,$file_id,$parent_user_id) = @_;
  my $uid = getUser()->Get('id');

  #       ,                          
  #                                  
  my $list = db()->
    SuperSelectAndFetchAll("select * from topic_views where topic_id=? for update",
                           $self->Get('id'));

  my $sth = db()->
    SuperSelect("select * from topic_views where topic_id=? and not is_freshed and is_subscribed",
                $self->{id});
  while (my $rec = Fetch($sth)) {
    db()->Query("update fuser set fresh_topics=fresh_topics+1 where id=?",
                       $rec->{user_id});
    db()->Query("update topic_views set is_freshed=? where topic_id=? and user_id=?",
                       't',$self->{id},$rec->{user_id});
  }

  if ($comment_id) {
    db()->
      Query("update topic_views set last_posted_comment_id=?, new_comments=new_comments+1, is_fresh='t' where topic_id=?",
            $comment_id,$self->Get('id'));
  } elsif ($file_id) {
    db()->
      Query("update topic_views set last_posted_file_id=?, new_files=new_files+1, is_fresh='t' where topic_id=?",
            $file_id,$self->Get('id'));
  } else {
    fatal("Internal error updateAllInfo");
  }
  #   db()->
  #     Query("update fuser set fresh_topics=fresh_topics+1 where topic_id=? and is_subscribed",
  #           $self->Get('id'));
  if ($parent_user_id) {
    db()->Query("update topic_views set new_answers=new_answers+1, answers=answers+1 where topic_id=? and user_id=?",
                       $self->Get('id'),$parent_user_id);
    db()->Query("update fuser set new_answers_time=now(), new_answers=new_answers+1, answers=answers+1 where id=?",
                       $parent_user_id);
  }
  return 1;
}

sub _getUserViewInfo {
  my ($self,$uid,$fu) = @_;
  return undef unless $uid;
  $fu='for update' if $fu;
  return db()->
    SuperSelectAndFetch("select * from topic_views where topic_id=? and user_id=? $fu",
                        $self->Get('id'),$uid);
}

sub IsUserGo {
	my ($self,$uid)=@_;
	return db()->
		SuperSelectAndFetch('select  * from topic_igos where topic_id=? and user_id=?',
		$self->Get('id'),$uid);
}

sub SetIgo {
  my ($self) = @_;	
#  $self->CheckAccess('can_comment');
  db()->Begin();
  my $uid = getUser()->Get('id');
  return undef if $uid==$self->Get('user_id');
  return undef if $self->IsUserGo($uid);
  db()->Query('set transaction isolation level serializable');

  #die $self->Get('topic_type');
  #return undef unless $self->Get('topic_type') eq 'event';
 #die 4;
  $self->LockTopic();
  db()->Query('insert into topic_igos (topic_id,user_id) values (?,?)',$self->Get('id'),$uid);
  db()->Query('update topic set igos_counter=igos_counter+1 where id=?',$self->Get('id'));
  db()->Commit();
}

sub UnsetIgo {
  my ($self) = @_;	
#  $self->CheckAccess('can_comment');
  db()->Begin();
  my $uid = getUser()->Get('id');
  return undef if $uid==$self->Get('user_id');
  return undef unless $self->IsUserGo($uid);
  db()->Query('set transaction isolation level serializable');

  #                         
  return undef unless $self->Get('topic_type') eq 'event';
  
  $self->LockTopic();
  
  db()->Query('delete from topic_igos where topic_id=? and user_id=?',$self->Get('id'),$uid);
  db()->Query('update topic set igos_counter=igos_counter-1 where id=?',$self->Get('id'));
  db()->Commit();
}


sub Rate {
  my ($self,$rating) = @_;	
  $self->CheckAccess('can_comment');
  db()->Begin();
  my $uid = getUser()->Get('id');
  return undef if $uid==$self->Get('user_id');
  db()->Query('set transaction isolation level serializable');

  #                       
  return undef if $self->Get('topic_type') eq 'event' && $rating<5;
  
  $self->LockTopic();
  $rating+=0;
  $rating=5 if $rating>5;
  $rating=undef if $rating<1;
  my $view = $self->_getUserViewInfo($uid,1);
  db()->
    Query('update topic_views set rating=? where topic_id=? and user_id=?',
          $rating,$self->Get('id'),$uid);

  my $res =
    db()->
      SuperSelectAndFetch("select count(*) as count, sum(rating) as sum from topic_views where topic_id=? and rating is not null",
                          $self->Get('id'));
  my $is_cold = $self->Get('is_cold') || 'f';
  my $is_hot = $self->Get('is_hot') || 'f';
  my $rating = $res->{sum}/$res->{count};
	if ($rating>=4 && $res->{count}>5) {
		$is_hot = 't';
	} elsif ($rating<=2 && $res->{count}>3) {
		$is_cold = 't'
	} elsif ($self->Get('raters')>=10) {
		$is_hot='t'
	}
  db()->Query('update topic set raters=?, rating=? where id=?',
                     $res->{count}, $rating,
                     $self->Get('id'));
  $is_hot='f' if $is_cold eq 't';
  db()->Query('update journal_topic set is_cold=?, is_hot=? where topic_id=?',
                     $is_cold, $is_hot,
                     $self->Get('id'));

  db()->Commit();
}


# 
# sub ChangeCharset {
#   my ($self) = @_;
#   $self->CheckAccess('can_edit');
#   db()->Begin();
#   $self->LockTopic();
#   my %data;
#   # short_text
#   foreach (qw(text subject)) {
#     $data{$_}=tran($self->Get($_));
#   }
#   my $res = table('topic')->Modify(\%data,$self->Get('id'));
#   db()->Commit();
# }


sub EditComment {
  my ($self,$data,$id) = @_;
  my $comment = table('comment')->Load($id) || fatal("No such comment to edit $id");
  $self->CheckMessageAccess($comment,'can_edit');
  $data->{sign}=getUser()->Get('sign');
  $data->{change_time}='now';
  
  $data->{change_ip}=setting('uri')->{remote_ip};
	$data->{videos_looked}='f';
  my $res = table('comment')->
    Modify($data,$id);
  db()->Commit();
}


sub GetTopicFiles {
  my $self = shift;
  my $dir_id = $self->Get('dir_id');
  return undef unless $dir_id;#['rating>=4'] ['rating<4']

  my @rated;
  my @other;
  my @cols=([],[],[]);
  my $c = 0;

  #
  my $sth = db()->
    SuperSelect("select * from filesholder_file where dir_id=? and type='image' and rating>=4 and raters>=3 order by rating desc, raters desc, id",
                $dir_id);
  
  my $f;
  while ($f = $sth->fetchrow_hashref()) {
    $f->{uri} = '/holder/'.$f->{path}.uri_escape($f->{file});
    $f->{src_uri} = '/holder/'.$f->{path}.uri_escape($f->{src_file});
    push @rated, $f;
  }

  my $sth = db()->
    SuperSelect("select * from filesholder_file where dir_id=? and type='image' order by thumb_width desc, thumb_height desc, id",
                $dir_id);
  
  my $f;
  while ($f = $sth->fetchrow_hashref()) {
    $f->{uri} = '/holder/'.$f->{path}.uri_escape($f->{file});
    $f->{src_uri} = '/holder/'.$f->{path}.uri_escape($f->{src_file});
    push @other,$f;
    push @{$cols[$c]},$f;
    $c++;
    $c=0 if $c==3;
  }

  
  return {rated=>\@rated,
          music=>db()->
          SuperSelectAndFetchAll("select * from filesholder_file where dir_id=? and type='music' order by rating desc, raters desc, id",
                      $dir_id),
          other=>\@other};
}

#                 

sub ShowTopic {
  my ($self,$journal,$page) = @_;
  
  #die "$self";
  my $page_size = 25;
  startTimer('show_topic');
  $page=1 unless $page;
  my $start = ($page-1)*$page_size;
  my $limit = $page_size;
  $self->CheckAccess('can_view',$journal);
  db()->Begin();
  $self->LockTopic();
  my $topic =  LoadTopic($self->Get('id'));

  #                                           
  my $view_info = getUser() ? $self->
    _clearUserViewInfo($topic,getUser()->Get('id')) : undef;
  db()->Query(qq(update topic set
           views = views + 1 where id=?),$self->Get('id'));
  db()->Commit();
  my $dir = $self->GetTopicFiles();
  $topic->{access} = $self->GetTopicAccess();

  $topic->{subscribers_list}=
    db()->
      SuperSelectAndFetchAll(qq(select *, $dpl::Web::Forum::user_fields
                            from topic_views
                           left join fuser on fuser.id=topic_views.user_id
                            where topic_id=? and is_subscribed),
                             $self->Get('id'));
  $topic->{downers}=db()->
    SuperSelectAndFetchAll(qq(select *, $dpl::Web::Forum::user_fields
                            from topic_views
                           left join fuser on fuser.id=topic_views.user_id
                            where topic_id=? and rating<=3),
                           $self->Get('id'));
  $topic->{igos}=db()->
    SuperSelectAndFetchAll(qq(select *, $dpl::Web::Forum::user_fields
                            from topic_igos
                           left join fuser on fuser.id=topic_igos.user_id
                            where topic_id=?),
                           $self->Get('id'));			   
  $topic->{uppers}=db()->
    SuperSelectAndFetchAll(qq(select *, $dpl::Web::Forum::user_fields
                            from topic_views
                           left join fuser on fuser.id=topic_views.user_id
                            where topic_id=? and rating>3),
                           $self->Get('id'));
  #  if ($topic->{journals}) {
  $topic->{publications} = SuperSelectAndFetchAll("select * from journal where is_active order by id");
  foreach my $j (@{$topic->{publications}}) {
    $j->{link}=db()->
      SuperSelectAndFetch("select * from journal_topic where journal_id=? and topic_id=?",
                          $j->{id},
                          $self->Get('id'));
    $j->{access}=dpl::Web::Forum::Journal::JournalInstance($j->{id})->
      GetJournalAccess();
  }
#  }
  
  $topic->{view}=$view_info;
  my $h = {topic=>$topic,
           page=>$page,
           files=>$dir,
           comments=>$self->GetCommentsTree($view_info),
           view=>$view_info};

  if ($topic->{topic_type} eq 'vote') {
    $h->{votes}=table('topic_vote')->List({topic_id=>$self->Get('id')});
    foreach my $v (@{$h->{votes}}) {
      $v->{voters}= db()->
        SuperSelectAndFetchAll(qq(select $dpl::Web::Forum::user_fields
                            from topic_views
                           left join fuser on fuser.id=topic_views.user_id
                            where topic_id=?  and vote_id=?),
                               $self->Get('id'),
															 $v->{id});
#			print STDERR "voters $v->{id}: $v->{voters}\n";
			

    }
    $h->{votes_res}=[ reverse sort {$a->{votes}<=>$b->{votes}} @{$h->{votes}}];
  }
  stopTimer('show_topic');
  return $h;
}

sub _clearUserViewInfo {
  my ($self,$topic,$uid) = @_;
  my $u =
    db()->
      SuperSelectAndFetch("select * from fuser where id=? for update",
                          $uid);
  my $view_info =
    db()->
      SuperSelectAndFetch("select * from topic_views where topic_id=? and user_id=? for update",
                          $self->Get('id'),
                          $uid);

  if ($view_info) {
    db()->Query("update topic_views set new_comments=?, new_files=?, new_answers=?,
                        is_fresh=?,
                        is_freshed=?,
                        last_view_comment_id=?, last_view_file_id=?,
                        last_view_time=current_timestamp where topic_id=? and user_id=?",
                       0, 0, 0, 0, 0,
                       $topic->{last_comment_id},
                       $topic->{last_file_id},
                       $self->Get('id'),$uid);
    if ($view_info->{is_freshed}) {
      db()->Query("update fuser set new_answers=new_answers-?, fresh_topics=fresh_topics-1 where id=?",
                         $view_info->{new_answers},$uid);
    } else {
      db()->Query("update fuser set new_answers=new_answers-? where id=?",
                         $view_info->{new_answers},$uid);
    }

  } else {
    db()->Query("insert into topic_views (last_view_comment_id, last_posted_comment_id, last_view_file_id, topic_id, user_id) values (?,?,?,?,?)",
                       $topic->{last_comment_id},
                       $topic->{last_comment_id},
                       $topic->{last_file_id},
                       $self->Get('id'),$uid);
  }
  return $view_info;
}


sub AddPersone {
  my ($self,$file_id,$uid) = @_;
  unless ($uid) {
    fatal("No user to add as persone") unless getUser();
    $uid = getUser()->Get('id');
  }
  db()->Begin();
  unless (db()->
          SuperSelectAndFetch(qq(select * from files_persons
                           where file_id=? and user_id=? for update),
                              $file_id, $uid)) {
    db()->Query('insert into files_persons (file_id,user_id) values (?,?)',
                       $file_id,$uid);

  }
  db()->Commit();
}

sub RemovePersone {
  my ($self,$file_id,$uid) = @_;
  unless ($uid) {
    fatal("No user to add as persone") unless getUser();
    $uid = getUser()->Get('id');
  }
  db()->Begin();
  db()->Query('delete from files_persons where file_id=? and user_id=?',
                     $file_id,$uid);
  db()->Commit();
}



sub ShowFile {
  my ($self,$file_id) = @_;
  my $file = filesholder()->GetFile($file_id) || return undef;
  $file->{dir} = filesholder()->GetDir($file->{dir_id});
  my $topic = $self->Get();
  # TODO                          
  if ($file->{media_width}>600) {
    $file->{media_height}=$file->{media_height}*600/$file->{media_width}; $file->{media_width}=600;
  }
  if ($file->{media_height}>600) {
    $file->{media_width}=$file->{media_width}*600/$file->{media_height}; $file->{media_height}=600;
  }
  $file->{media_width}=~s/\..+//;  $file->{media_height}=~s/\..+//;
  $topic->{access} = $self->GetTopicAccess();
  $file->{topic} = $topic;

  my $u = getUser();
  $file->{persons} = db()->SuperSelectAndFetchAll("select user_id as id,
         fuser.login as login,
         fuser.thumb_file, fuser.thumb_width, fuser.thumb_height, fuser.thumb_time
         from files_persons left join fuser on fuser.id=files_persons.user_id where file_id=? order by id",$file_id);
  #                 ,              

  my $view_info;

  if ($u) {
    $view_info = $self->_getUserViewInfo($u->Get('id'));
    $file->{on_the_photo} = db()->
      SuperSelectAndFetch(qq(select * from files_persons
                           where file_id=? and user_id=?),
                          $file_id, $u->Get('id'));
    $file->{user_rate}=db()->
      SuperSelectAndFetch(qq(select * from file_rating
                           where file_id=? and user_id=?),
                          $file_id, $u->Get('id'));
  }
	
	$file->{raters_users}=db()->
		SuperSelectAndFetchAll(qq(select *, $dpl::Web::Forum::user_fields
                    from file_rating
                    left join fuser on fuser.id=file_rating.user_id
                           where file_id=? order by rating desc),
													 $file_id);
	
  $file->{comments_tree} =
    $self->
      GetCommentsTree($view_info,$file_id);
  $file->{files} = $self->GetTopicFiles();
  return $file;
}



# sub ListComments {
#   my $self = shift;
#   fatal("Topic's ID is not defined")
#     unless $self->{id};
#   my $list = SuperSelectAndFetchAll(qq(select comment.*, fuser.name as user_name
#                                        from comment
#                                        left join fuser on fuser.id=comment.user_id
#                                        where comment.topic_id=? order by comment.create_time),
#                                     $self->{id});
#   return $list;
# }



# ACCESS

sub HasAccess {
  my ($self,$key,$j) = @_;
  return $self->GetTopicAccess($key,$j);
}

sub CheckAccess {
  my ($self,$access,$j) = @_;
  my $res = $self->GetTopicAccess($access,$j);
  return $res || fatal("No topic access $access");
}

sub GetTopicAccess {
  my ($self,$key,$j) = @_;
  my %a;
  my $u = getUser() ? getUser()->Get() : undef;
  fatal("No topic is loaded for access") unless $self->Get('id');
  my $uid = $u ? $u->{id} : undef;
  my $is_admin = getUser() &&
    (getUser()->HasAccess('admin')
     || ($j && $j->Get('user_id')==$uid));
  die 'topic is removed' if $self->Get('is_removed') && !$is_admin;
  
  $a{can_view} = $self->Get('user_id')==$uid || ($j && $j->GetJournalAccess('can_view'));
  #  die $self->journal()->GetJournalAccess('can_view');
  if ($uid) {
    $a{foto_moderator} =
      getUser()->HasAccess('admin')
        || getUser()->HasAccess('gallery')      
          || getUser()->Get('is_fotocor')
            || getUser()->Get('is_academic');
    $a{can_edit} = $is_admin
      || $self->Get('user_id')==$uid;
    $a{can_upload} = $a{can_edit}
      || $self->Get('upload_access')>=4
        || ($self->Get('upload_access')>=2 && $u->{level}>=1) #          
          || ($self->Get('upload_access')>=3 && $u); #           ;
    $a{can_delete} = $is_admin || $self->Get('user_id')==$uid;

    $a{can_comment} = (($j && $j->GetJournalAccess('can_comment')) || !$j)
      && !getUser()->IsBlacker($self->Get('user_id'));
    #context.user.mobile_checked
    #$a{can_rate}=getUser()->Get('mobile_checked') && $a{can_comment};
    $a{can_rate}=getUser()->Get('level') && $a{can_comment};
    $a{has_any_admin} = $a{can_edit} || $a{can_delete};
  }

  return $key ? $a{$key} : \%a;
}

sub Subscribe {
  my ($self,$uid) = @_;
  fatal("No topic is loaded") unless $self->Get('id');
  unless ($uid) {
    fatal("User it not loade") unless getUser();
    $uid = getUser()->Get('id');
  }
  db()->Begin('set transaction isolation level serializable');
  $self->LockTopic();
  my $res = db()->Query('select * from fuser where id=? for update',$uid);
  my $view = $self->_getUserViewInfo($uid,1);

  if ($view) {
    unless ($view->{is_subscribed}) {
      db()->
        Query('update topic_views set is_subscribed=?, subscribe_time=now() where topic_id=? and user_id=?',
              1,$self->Get('id'),$uid);
      db()->
        Query('update topic set subscribers=subscribers+1 where id=?',
              $self->Get('id'));
      db()->
        Query('update fuser set fresh_topics=fresh_topics+1 where id=?',
              $uid)
          if $view->{is_freshed};
    }
  } else {
    db()->
      Query("insert into topic_views (topic_id, user_id, is_subscribed, subscribe_time) values (?,?,?,now())",
            $self->Get('id'),$uid,1);
    db()->Query('update topic set subscribers=subscribers+1 where id=?',$self->Get('id'));
  }
  db()->Commit();
}

sub Unsubscribe {
  my ($self,$uid) = @_;
  fatal("No topic is loaded") unless $self->Get('id');
  unless ($uid) {
    fatal("User it not loade") unless getUser();
    $uid = getUser()->Get('id');
  }
  db()->Begin('set transaction isolation level serializable');
  $self->LockTopic();
  my $res = db()->Query('select * from fuser where id=? for update',$uid);
  my $view = $self->_getUserViewInfo($uid,1);
  if ($view && $view->{is_subscribed}) {
    db()->
      Query('update topic_views set is_subscribed=? where topic_id=? and user_id=?',
            0,$self->Get('id'),$uid);
    db()->Query('update topic set subscribers=subscribers-1 where id=?',$self->Get('id'));
    db()->
      Query('update fuser set fresh_topics=fresh_topics-1 where id=?',
            $uid)
        if $view->{is_freshed};

  }
  db()->Commit();
}


sub CheckMessageAccess {
  my ($self,$message,$access) = @_;
  my $res = $self->GetMessageAccess($message)->{$access};
  return $res || fatal("No message access $access");
}



sub GetMessageAccess {
  my ($self,$message,$j) = @_;
  my %a;
  return {} unless getUser();
  my $uid = getUser()->Get('id');
  my $is_admin = getUser()->HasAccess('admin');
	
#    || $self->HasAccess('can_edit')
#      || ($j && $j->Get('user_id')==$uid);
  $a{can_edit} = $is_admin || $message->{user_id}==$uid;
  $a{can_delete} = $is_admin || $self->HasAccess('can_edit') || $message->{user_id}==$uid;
  $a{can_delete_thread} = $is_admin;
  foreach (keys %a) {
    if ($a{$_}) {
      $a{has_any}=1;
      last;
    }
  }
  return \%a;
}



1;
