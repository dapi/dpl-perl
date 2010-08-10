package dpl::Web::Utils;
use strict;
#use Apache;
#use dpl::Log;
#use dpl::Config;
#use dpl::XML;
use dpl::Error;
use Exporter;
use dpl::Context;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(Exporter);
#@EXPORT = qw(param);


sub param {
  my $key = shift;
  my $q = setting('uri')->{query};
  my %params;
  foreach (split('&',$q)) {
    my ($k,$v)=split('=',$_);
    $params{$k}=$v;
  }
  my $s = $params{$key};
  $s=~s/\+/ /g;
  return Apache2::URI::unescape_url($s);
}


sub parse_args {
  my ($string) = @_;
  return $string unless defined $string and $string;
  map {
    tr/+/ /;
    s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;
    $_;
  } split /[=&;]/, $string, -1;

}

sub resampleImage {
  my ($src_file,$dir,$filename,$ext,$image,$width_max,$height_max,$opt) = @_;
  $opt={} unless $opt;
  my ($w, $h) = $image->getBounds();
  my ($nw,$nh)=($w,$h);
  if ($w<=$width_max && $h<=$height_max) {
    if ($opt->{logo}) {
      my $new_image = new GD::Image($nw,$nh,1);
      $new_image->copyResampled($image,0,0,0,0,$nw,$nh,$w,$h);

      my ($lw,$lh) = $opt->{logo}->getBounds();
      if ($opt->{put_logo} eq 'br') {
        $new_image->copy($opt->{logo},$nw-$lw,$nh-$lh,0,0,$lw,$lh);
      } elsif ($opt->{put_logo} eq 'bl') {
        $new_image->copy($opt->{logo},0,$nh-$lh,0,0,$lw,$lh);
      } elsif ($opt->{put_logo} eq 'tr') {
        $new_image->copy($opt->{logo},$nw-$lw,0,0,0,$lw,$lh);
      } elsif ($opt->{put_logo} eq 'tl') {
        $new_image->copy($opt->{logo},0,0,0,0,$lw,$lh);
      } else {
        fatal("Unknown logo position $opt->{put_logo}");
      }
      saveImage($new_image,$dir,$filename,$ext);
    } else {
      print STDERR "copy file: cp $src_file $dir/$filename.$ext\n"; 
      `cp "$src_file" $dir/$filename.$ext`;
    }
  } else {
    if ($opt->{width_first}) {
      if ($nw>$width_max) {
        $nw = $width_max;
        $nh = int($h*$width_max/$w);
      }
      if ($nh>$height_max) {
        $nh = $height_max;
        $nw = int($w*$height_max/$h);
      }
    } else {
      if ($nh>$height_max) {
        $nh = $height_max;
        $nw = int($w*$height_max/$h);
      }
      if ($nw>$width_max) {
        $nw = $width_max;
        $nh = int($h*$width_max/$w);
      }
    }
    my $new_image = new GD::Image($nw,$nh,1);
    $new_image->copyResampled($image,0,0,0,0,$nw,$nh,$w,$h);
    
    if ($opt->{logo}) {
      my ($lw,$lh) = $opt->{logo}->getBounds();
      if ($opt->{put_logo} eq 'br') {
        $new_image->copy($opt->{logo},$nw-$lw,$nh-$lh,0,0,$lw,$lh);
      } elsif ($opt->{put_logo} eq 'bl') {
        $new_image->copy($opt->{logo},0,$nh-$lh,0,0,$lw,$lh);
      } elsif ($opt->{put_logo} eq 'tr') {
        $new_image->copy($opt->{logo},$nw-$lw,0,0,0,$lw,$lh);
      } elsif ($opt->{put_logo} eq 'tl') {
        $new_image->copy($opt->{logo},0,0,0,0,$lw,$lh);
      } else {
        fatal("Unknown logo position $opt->{put_logo}");
      }
    }
    saveImage($new_image,$dir,$filename,$ext);
  }
  my @s = stat("$dir/$filename.$ext");
  #  print STDERR "$dir/$filename.$ext $s[7],$nw,$nh\n";
  return ($s[7],$nw,$nh);
}

sub saveImage {
  my ($image,$dir,$filename,$ext)=@_;
  my $f="$dir/$filename.$ext";
  my $data;
  if ($ext eq 'jpg' || $ext eq 'jpeg') {
    $data = $image->jpeg(80);
  } elsif ($ext eq 'png') {
    $data = $image->png();
  } elsif ($ext eq 'gif') {
    $data = $image->gif();
  } else {
    fatal("Unknown extenstion for saving image $ext");
  }
  open (FILE,"> $f") || fatal("Can't save image file $f");
  binmode FILE;
  print FILE $data;
  close FILE;
  return "$filename.$ext";
}



sub receiveFile {
  my ($dir,$file) = @_;
  return undef unless $file;
  my $newfile = $file;
  $newfile=~s/^.*[\/\\]//g; $newfile=~s/\.\.//;  #    $newfile=~s/[^a-z_0-9\-.]/_/ig;
  $newfile=~s/\s/_/g;
  $newfile=~s/[^a-z_0-9\-\(\)\+.]/_/ig;
  $newfile=~s/\.(.+)$/.\L$1\E/; # lower case extenstion
  open(W, "> $dir/$newfile") || fatal("Can't open file $dir/$newfile to write");
  while (<$file>) {
    print W $_;
  }
  close(W) || fatal("Can't close file $dir/$newfile");
  return "$dir/$newfile";
}



1;
