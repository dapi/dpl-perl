package dpl::Web::Forum::Escape;
use strict;
use Date::Parse;
use Exporter;
use URI::Escape;
use URI::Split  qw(uri_split uri_join);
use Number::Format qw(:subs);
use dpl::Db::Database;
use dpl::Db::Filter;
use HTTP::Date;
use dpl::Db::Table;
use dpl::Context;
use dpl::System;
use dpl::Error;
use dpl::DataType::DateTime;
use Template::Plugin::Gravatar;
use vars qw(@ISA
            %leftmenu
            @EXPORT);


@ISA = qw(Exporter
         );

@EXPORT = qw(
              filter_seconds
              filter_mobile
              filter_comments
              filter_escape_short_text
              filter_escape_text
              filter_escape_subject
              filter_escape
              filter_bbcode
              filter_escape_subject_short
              filter_date
              filter_date_human
              atom_date
              atom_datetime
              atom_today
              filter_date_short
              filter_date_afisha
              filter_date_afisha2
              filter_date_time
              filter_timestamp
              filter_time
              filter_is_weekend
              filter_is_today
              filesize_filter
              uri_filter
              unicode_filter
              unicode_filter2
              http_date
              percent_filter
              right_cut_filter
           );

#              show_gravatar

my %smiles=(lol=>'lol.gif', # :lol:

            cool=>'cool.gif', # :)
            rofl=>{file=>'rofl.gif',width=>28,height=>23}, # :)
            '8)'=>'cool.gif', # :)

            kiss=>{file=>'kiss.png',width=>22,height=>22},
            'k)'=>{file=>'kiss.png',width=>22,height=>22},
            'K)'=>{file=>'kiss.png',width=>22,height=>22},

            smile=>'smile.gif', # :)
            ':)'=>'smile.gif', # :)
            biggrin=>'biggrin.gif', # :D
            ':D'=>'biggrin.gif', # :D
            ';D'=>'biggrin.gif', # ;D
            sad=>'sad.gif', # :(
            ':('=>'sad.gif', # :(
            ';('=>'sad.gif', # ;(
            wink=>'wink.gif', # ;)
            ';)'=>'wink.gif', # ;)

            yahoo=>{file=>'yahoo.gif', width=>42, height=>27},

            take_exam=>{file=>'take_example.gif', width=>86, height=>36}
           );

# sub show_gravatar {
#   my $user = shift;
#   my $email = lc($user->{email});
#   print STDERR "GRAVATAR: $user->{login}: $email\n";
#   my $gravatar=length($email)>0 ? Gravatar( email => $email, size=>80 ) : '/pic/nofoto.gif';
#   return "<img src=\"$gravatar\" width=\"80\" height=\"80\" class=\"avatar\" alt=\"\" />"
# }

sub filter_seconds {
  my $t = shift;
  return '*' unless $t;

  my $s = $t % 60;
  my $m = ($t-$s)/60;
  $s="0$s" if $s<10;
  $m="0$m" if $m<10;
  return "${m}:${s}";
}

sub filter_mobile {
  my $t = shift;
  return 'не указан' unless $t;
  my ($a,$c,$n1,$n2,$n3)=($t=~/^(\d+)(\d\d\d)(\d\d\d)(\d\d)(\d\d)$/);
  return "+$a ($c) $n1-$n2-$n3";
}

sub filter_comments {
  my $count = shift;
  my $s = {1=>'комментарий',
           2=>'комментария',
           5=>'комментариев'};
  my $l = $count;
  $l=~s/(\d+)(\d)/$2/;
  return "нет комментариев" unless $count;
  my $str;
  if ($count>=10 && $count<=14) {
    $str=$s->{5};
  } else {
    if ($l>5 || !$l) {
      $l=5;
    } elsif ($l<5 && $l>1) {
      $l=2;
    }
    $str=$s->{$l};
  }
  return "$count $str";
}

sub filter_mobile {
	my $text = shift;
	$text=~/(\d)(\d{3})(\d+)/;
	return "+$1 ($2) $3";
}

sub filter_escape {
  my $text = shift;
#  return $text;
#  $text =~ s{&(#[0-9]+;)}{&amp;}gso;
  #  $text =~ s/&[^#]/\&amp;$1/gsmo;
#  $text =~ s/&()/\&amp;$1/gsmo;
  
  #  die "$text" if $text=~/&/;
  $text =~ s{<}{&lt;}gso;
  $text =~ s{>}{&gt;}gso;
  $text =~ s{\"}{&quot;}gso;
  $text =~ s{\(c\)}{&copy;}gso;
  $text =~ s{\x85}{&hellip;}gso;
  $text =~ s{\x96}{&ndash;}gso;
  $text =~ s{\xab}{&laquo;}gso;
  $text =~ s{\xbb}{&raquo;}gso;
  return $text;
}

sub filter_bbcode {
  my $text = shift;
  my $parser = BBCode::Parser->new();
  $parser->set(follow_links=>1);
  my $tree = $parser->parse($text);
  my $conv =Text::Iconv->new("utf-8", "koi8-r");
  my $t = $tree->toHTML();
#  return ;
  return $t ? $conv->convert($t) : $t;
}

sub filter_escape_short_text {
  return filter_escape_text($_[0],500,10,1);
}

sub filter_escape_text {
  my ($text,$length,$lines,$dont_process_image) = @_;

  $text =~ s{\<([\/])?([ibu])\>}{\[$1$2\]}gso;
  $text =~ s{(^|\W)\*([^*\n]+)\*($|\W)}{$1\[b\]$2\[\/b\]$3}gmso;
  # в таком виде она портит ссылки - убирает //
  #  $text =~ s{(^|\W)\/([^\/\n]+)\/($|\W)}{$1\[i\]$2\[\/i\]$3}gmso;
  #  $text =~ s{([^\/]|^|\s)\/([^\/\n]+)\/([^\/]|$|\s)}{$1\[i\]$2\[\/i\]$3}gmso;
  $text =~ s{(^|\s)\/([^\/\n]+)\/($|\s)}{$1\[i\]$2\[\/i\]$3}gmso;
  $text =~ s{(^|\W)_([^_\n]+)_($|\W)}{$1\[u\]$2\[\/u\]$3}gsmo;
  $text =~ s{<br>}{\n}gsmo;

  # с другого спорта
  $text =~ s{<!--emo&[^-]+-->.+<!--endemo-->}{$1}gsmo;
  $text =~ s{<!--QuoteBegin-->[^!]+<!--QuoteEBegin-->([^!]+)<!--QuoteEnd-->[^!]+<!--QuoteEEnd-->}{\[q\]$1\[\/q\]}gsmo;

  $text =~ s{<a href='(.+)'\s+[^<]+</a>}{$1}gsmo;

  $text = filter_escape($text);


  $text =~ s{\[q\]}{<div class=quote>}gsmo;
  $text =~ s{\[\/q\]}{<\/div>}gsmo;

  # Подпись
  $text =~ s{\[\/s\]}{\</i\>}gso;
  $text =~ s{\[s\]}{\n\<i\>}gso;
  $text =~ s{\[\/s\]}{\</i\>}gso;

  $text =~ s{\[hr\]}{<hr>}gso;

  if ($length) {
    $text =~ s/(\n|<br>|\s)+/$1/gm;
    $text =~ s/((.|\s)+\n){$lines}(.|\n|\s|\r)+/$1 \&\#8230;/gm if $lines;
    $text =~ s{\[(\/)?([ibu])\]}{}gso;
  } else {
    $text =~ s{\[(\/)?([ibu])\]}{\<$1$2\>}gso;
  }
  
  $text =~ s/\n/<br\/>\n/gm;    # style="clear: none"\

  $text=~s/((((http|https|ftp):\/\/)|(www\.))([^\/][\@a-z0-9\._\+\-\=\?\&\%\,\/\#\(\)\;\:\~]+))/ProcessLink($1,$dont_process_image)/igme;

  #  die $length;
  if ($length) {
  	# $text=~s/<.+>//mg;
    $text=~s/^(((.|\s|\n){$length}))(.|\s|\n|\r)*/$2 ../mg; #\&\#8230;
  }

  if ($dont_process_image) {
    $text=~s/(^|[^\\])\[img\#(\d+)\]/$1 /mge;
#    $text=~s/\[user\#([0-9._a-z]+)\]//imge;
  } else {
    $text=~s/(^|[^\\])\[img\#(\d+)\]/$1.ReplaceIMG($2)/mge;
  }

  $text=~s/(^|.)\[user\#([0-9\-._a-zйцукенгшщзхъфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪЖЭДЛОРПАВЫФЯЧСМИТЬБЮ]+)\]/render_user($1,$2)/imge;

  # Если смайл встречается в теге - задница

  $text=~s|(\S*)([:;8k]-?[\(\)D])|smile($1,$2)|emg;
  $text=~s|(\S*)(\:([a-z_]+)\:)|smile($1,$2)|emg;


  return $text;
}

sub smile {
  my ($pre,$smile) = @_;
#  print STDERR "smile '$pre' $smile\n";
  if ($pre) {
    return $smile if $pre eq '\\';
    return $pre.$smile if $pre=~/\&[a-z]+$/i;
  }

  my $user = getUser();

  return "$pre $smile" if $user && $user->IsLoaded() && !$user->Get('use_smile');

  $smile=~s/^:(.+):/$1/;
  $smile=~s/-//;
  my $pic = $smiles{$smile};
  if ($pic) {
    my ($w,$h)=(20,20);
    if (ref($pic)) {
      ($w,$h)=($pic->{width},$pic->{height});
      $pic=$pic->{file};
    }
    return "$pre <img title=\"$smile\" alt=\"$smile\" src=\"/pic/smile/default/$pic\" width=\"$w\" height=\"$h\" />";
  } else {
    print STDERR "Unknown smile '$smile'\n";
    return "$pre $smile";
  }
}


sub ProcessLink {
  my ($uri,$dont) = @_;
#  die "'$uri'";
  $uri="http://$uri" unless $uri=~m{(http[s]?|ftp)://};
  my ($scheme, $auth, $path, $query, $frag) = uri_split($uri);
#  my($scheme, $authority, $path, $query, $fragment) =
#    $uri =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;
  #  die "($scheme, $authority, $path, $query, $fragment)";
  my $p = $path eq '/' ? '' : $path;

  # TODO удалять путь, оставлять только имя файла
  if (length($p)>30) {
    $p=~s/.+\/(.+)/$1/g;
    $p="/&hellip;/$p";# if length($p)>30;
  }
  $p='/&hellip;' if length($p)>30;

  if ($auth=~/(zhazhda\.ru)$/) {
    my $h = $1;
    if ($path=~/\/topics\/(\d+)\.html/) {
      my $t = table('topic')->Load($1) ||
        return $dont ? "$auth$p" : "<a href='$uri'>$auth$p</a>";
      #    my $u = table('fuser')->Load($t->{user_id});
      #render_user($u->{login})."
      my $subject = filter_escape_subject($t->{subject});
      my $id = 'l';
      $id="ld" if $auth=~/drugoisport/;
      return $dont ? $subject : "<a href='$uri' class='topic' id='$id'>$subject</a>";
      # Ссылка на файл/фото?
    } elsif ($path=~/\/holder\/(\d+)\.html/) {
      return ReplaceIMG($1,1);
      # TODO
    } elsif ($path=~/\/rate_topic/) {
      return $dont ? '' : '<a href="#rating">Отрейтингуйте, пожалуйста, мой топик</a>';
      # TODO
    } elsif ($path=~/\/user\/(.+)\/$/) {
      return render_user('',$1);
    }
    return  $dont ? "$auth$p" : "<a href='$uri'>$auth$p</a>";
		
		# http://rutube.ru/tracks/1331141.html?v=431f1c37cc40953e4eed0ec5692f9562
  } elsif ($auth=~/rutube\.ru$/ && $path=~/tracks/ && $query=~/^v=(.+)$/) {
    return $uri if $dont;
    my $vid = $1;
    #    die "$path $query";
				
    #http://www.youtube.com/watch?v=tMANZ2iKRcQ
    my $code=qq(<div class="youtube"><object width="470" height="353"><param name="movie" value="http://video.rutube.ru/$vid"></param><param name="wmode" value="window"></param><param name="allowFullScreen" value="true"></param><param name="flashVars" value="uid=2328281"></param><embed src="http://video.rutube.ru/$vid" type="application/x-shockwave-flash" wmode="window" width="470" height="353" allowFullScreen="true" flashVars="uid=2328281"></embed></object><br/><div class="youtube_link"><a href="$uri">Смотреть на rutube.ru &hellip;</a></div></div>);
    return "$code";
		
  } elsif ($auth=~/youtube\.com$/ && $path eq '/watch' && $query=~/^v=(.+)$/) {
    return $uri if $dont;
    my $vid = $1;
    #    die "$path $query";
    #http://www.youtube.com/watch?v=tMANZ2iKRcQ
    my $code=qq(<div class="youtube"><object width="425" height="350"><param name="movie" value="http://www.youtube.com/v/$vid"></param><embed src="http://www.youtube.com/v/$vid" type="application/x-shockwave-flash" width="425" height="350"></embed></object><br/><div class="youtube_link"><a href="$uri">Смотреть на youtube.com &hellip;</a></div></div>);
    return "$code";

		#http://vimeo.com/2030361
		#600x450
	} elsif ($auth=~/vimeo\.com$/ && $path=~/^\/(\d+)$/) {
		my $vid = $1;
		#		my ($w,$h)=(480,360);
		my ($w,$h)=(504,378);
		
		my $code=qq(<div class="youtube"><object width="$w" height="$h">
<param name="allowfullscreen" value="true" />
<param name="allowscriptaccess" value="always" />
<param name="movie" value="http://vimeo.com/moogaloop.swf?clip_id=$vid&amp;server=vimeo.com&amp;show_title=0&amp;show_byline=0&amp;show_portrait=0&amp;color=ff0179&amp;fullscreen=1"/>
<embed src="http://vimeo.com/moogaloop.swf?clip_id=$vid&amp;server=vimeo.com&amp;show_title=0&amp;show_byline=0&amp;show_portrait=0&amp;color=ff0179&amp;fullscreen=1" type="application/x-shockwave-flash" allowfullscreen="true" allowscriptaccess="always" width="$w" height="$h"></embed></object>
</div>
);
			return $code;
  }
  my $db = db();
  $path='' unless $path;
  $query='' unless $query;
  my $res = $db->
    SelectAndFetchOne("click_counter",'sum(counter) as counter',
                      {host=>$auth});
  my $res2 = $db->
    SelectAndFetchOne("click_counter",'sum(counter) as counter',
                      {host=>$auth,path=>$path,query=>$query});
  my $title = "Кликов по ссылке $res2->{counter}";
  $title="$title, в общем на хост $res->{counter}"
    unless $res->{counter}==$res2->{counter};
  return $dont ? "$auth$p" : "<a href=\"$uri\" class=\"away\" title=\"$title\" >$auth$p</a>"
    if $uri=~/ftp:\//;
  $uri=uri_escape($uri);
  return $dont ? "$auth$p" : "<a href=\"http://zhazhda.ru/redir?l=$uri\" class=\"away\" title=\"$title\" >$auth$p</a>";
}

sub render_user {
  my ($pre,$login) = @_;
  return "[user#$login]" if $pre eq '\\';
  my $is_online = context('online') ? context('online')->{logins}->{$login} : undef; #
  return "$pre<a href='/user/".uri_escape($login)."/' class=\"u\">$login</a>";
}

sub ReplaceIMG {
  my $num = shift;
  my $e = shift;
  $num=0 if $num>9999999;
  my $home = setting('uri')->{home};
  my $pic_home = setting('uri')->{pic};
  my $w = 'align="left" vspace="2" hspace="3"';
  my $i = table('filesholder_file')->Load($num)
    || return $e ? undef : "<img src=${pic_home}nofoto.gif $w width=80 height=80 alt=\"No such foto\"/>";
  my $a = filter_escape("$i->{title}: $i->{comment}");
  $a=~s|([^\\])([:;8]-?[\(\)D])|$1."\\".$2|emg;
  $a=~s|([^\\])(\:([a-z_]+)\:)|$1."\\".$2|emg;

  return qq(
            <a href="${home}holder/$i->{id}.html#photo"><img style="border: solid 5px white; " src="${pic_home}$i->{path}/$i->{gallery_file}" width="$i->{gallery_width}" height="$i->{gallery_height}" $w alt="$a"/></a>
           )
}


sub filter_escape_subject {
  my $text = shift;
  #  ([a-z0-9\.\/])([\?:&%=_:\-!~*\',\;\#\+]+)
  $text=~s/(\S+:\/\/)([^\?]+)(\?\S+)/$2/igm;
  $text = filter_escape($text);

  
#   $text =~ s{<}{&lt;}gso;
#   $text =~ s{>}{&gt;}gso;
#   $text =~ s{\"}{&quot;}gso;

  $text =~ s/\n/ /gm;

  $text =~ s/^\s+//gm;
  $text =~ s/\s+$//gm;

  #  $text=~s/([^\\])\[((http|ftp):\/\/[a-z0-9\.\/\?:&%=_:\-!~*\'(),\;\#\+]+)\s+([^\]]+)\]/<a href="$1">$3</a>/igm;
  #  $text=~s/([^\\]|^)((http|ftp):\/\/[a-z0-9\.\/\?:&%=_:\-!~*\'(),\;\#\+]+)/<a href="$1">$a</a>/igm;
  #  $text=~s/(^|\s+)(www\.[a-z0-9\.\/\?:&%=_:\-!~*\'(),\;\#\+]+)/<a href="$1">$a</a>/igm;

  return "$text";
}


sub filter_escape_subject_short {
  my $text = shift;
  my $length=20;
  if ($length) {
    $text=~s/^((.{$length})[^.\s]).*/$2&\#8230;/m;
  }

  $text = filter_escape_subject($text);
  return "$text";
}


sub filter_date {
  my $date = shift;
  $date = filter('date')->FromSQL($date) || return undef;
  return $date->human();
}

sub filter_human {
  my $date = shift;
  $date = filter('datetime')->FromSQL($date) || return undef;
  return $date->human();
}

sub filter_date_human {
  my $date = shift;
  $date = filter('date')->FromSQL($date) || return undef;
  return $date->human(1);
}



sub filter_timestamp {
  my $date = shift;
  $date = filter('timestamp')->FromSQL($date) || return undef;
  return $date->Epoch();
}

sub filter_date_short {
  my $date = shift;
  $date = filter('datetime')->FromSQL($date) || return '???';
  return $date->TimeFormat('%e %B');
}


sub filter_date_afisha {
  my $date = shift;
  $date = filter('datetime')->FromSQL($date) || return '???';
  my $str = $date->TimeFormat('%e %B, %A');
  $str="Сегодня, $str"
    if $date->IsToday();
  $str="Завтра, $str"
    if $date->IsTomorrow();
  return $str;
}

sub filter_date_afisha2 {
  my $date = shift;
  $date = filter('datetime')->FromSQL($date) || return '???';
  my $str = $date->TimeFormat('%e %B, %a');
  return $str;
}


sub filter_is_weekend {
  my $date = shift;
  $date = filter('datetime')->FromSQL($date) || return undef;
  my $w = $date->TimeFormat('%w');
  return $w==0 || $w==6;
}

sub filter_is_today {
  my $date = shift;
  $date = filter('datetime')->FromSQL($date) || return undef;
  return $date->TimeFormat('%Y-%m-%d') eq today('%Y-%m-%d');
}



sub filter_date_time {
  my $date = shift;
  $date = filter('datetime')->FromSQL($date) || return undef;
  my $str = $date->human();
  $str=~s/(\d+)\s+/$1 /g;
  return $str;
}

sub filter_time {
  my $date = shift;
  if ($date=~/(\d+):(\d+):(\d+)/) {
    return "$1:$2";
  }
  
  $date = filter('datetime')->FromSQL($date) || return undef;
  return $date->TimeFormat('%R');
}


sub user_filter {
  my $nick = shift;
  my $pic='user1';
  my $home="/user/$nick/";
  my $title;# = "Домашняя страница $u->{login}, личная переписка";
  return "<img class=u src=/pic/icon/$pic.png width=14 height=15 alt='$nick'/><a href='$home' class=\"u\">$nick</a>";
}

sub uri_filter {
  my $s = shift;
#  $s =~ s{&}{&amp;}gso;
  return uri_escape($s);
}

sub http_date {
my $date = shift;
$date = Date::Parse::str2time($date);
return HTTP::Date::time2str($date);
}

sub atom_date {
	my $date = shift;
	$date = filter('date')->FromSQL($date) || today();
	$date->TimeFormat('%Y-%m-%d');
	
}

sub atom_today {
	today()->TimeFormat('%Y-%m-%dT%T+03:00');
}

sub atom_datetime {
	my $date = shift;
	$date = filter('date')->FromSQL($date) || today();
	$date->TimeFormat('%Y-%m-%dT%T+03:00');
}


sub unicode_filter {
my $text = shift;
  $text =~ s{&}{&amp;}gso;
  $text =~ s{<}{&lt;}gso;
  $text =~ s{>}{&gt;}gso;
# return XML::LibXML::encodeToUTF8('koi8-r',$text);
  my $conv =Text::Iconv->new("koi8-r","utf-8");
  $conv->raise_error(0);
  $text=~s/[^0-9\-.\?\[\]\{\};:\'\"\,\<\>\!\@\#\$\%\^\&\*\(\)\\ \/\-\=\+|_a-zйцукенгшщзхъфывапролджэячсмитьбю╗ЙЦУКЕНГШЩЗХЪЖЭДЛОРПАВЫФЯЧСМИТЬБЮ╦]/_/ig;
  return $conv->convert($text);
}

sub unicode_filter2 {
  my $text = shift;
  my $conv =Text::Iconv->new("koi8-r","utf-8");
  $conv->raise_error(0);
#  $text=~s/[^0-9\-.\?\[\]\{\};:\'\"\,\<\>\!\@\#\$\%\^\&\*\(\)\\ \/\-\=\+|_a-zйцукенгшщзхъфывапролджэячсмитьбю╗ЙЦУКЕНГШЩЗХЪЖЭДЛОРПАВЫФЯЧСМИТЬБЮ╦]/_/ig;
  return $conv->convert($text);
}


sub percent_filter {
  my $p = shift;
  $p=~s/\,/\./;
  return round($p*100,0).'%';
}

sub right_cut_filter {
  my $p = shift;
  return $p if length($p)<17;
  if ($p=~/^(.{10,20}[0-9a-z])[^0-9a-z]/i) {
    return "$1&#8230;";
  } else {
    return substr($p,0,20).'&#8230;';
  }


}


sub filesize_filter {
  my $s =format_bytes(shift);
  return "$s";
#   $s=~s/\..*//;
#   $s=~s/M/Мб/;
#   $s=~s/K/Кб/;
#   return $s;
}

1;
