package dpl::Web::Forum::Image;
use strict;
use dpl::Error;
use GD;
use Exporter;
use Number::Format qw(:subs);
use base qw(Exporter);
use vars qw(@ISA
            @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(LoadImage);

my @bounds_thumb = (90,60);
my @bounds_normal = (600,400);

sub LoadImage {
  my ($self,$dir,$filename,$field_name) = @_;
  $field_name='file' unless $field_name;

  my $fn = ParseFileName($self->param($field_name));
  $fn->{name}=$filename if $filename;
  my $source_filename = "$fn->{name}-src.$fn->{ext}";
  my $sf = "$dir$source_filename";
  my $file = $self->param($field_name);
  open(W, "> $sf") || fatal("Can't open file $sf to write");
  while (<$file>) {  print W $_; }
  close(W) || fatal("Can't close file $sf");
  my $src = GD::Image->new("$sf") || fatal("Error open file: $sf");
#  die join(',',$src);
  my ($w, $h) = $src->getBounds();
  my ($tw,$th) = ScaleAndSave($src,$sf,"$dir$fn->{name}-thumb.$fn->{ext}",@bounds_thumb);
  my ($nw,$nh) = ScaleAndSave($src,$sf,"$dir$fn->{name}.$fn->{ext}",@bounds_normal);

  return {thumb=>{file=>"$fn->{name}-thumb.$fn->{ext}",
                  width=>$tw, height=>$th},
          normal=>{file=>"$fn->{name}.$fn->{ext}",
                   width=>$nw, height=>$nh},
          source=>{file=>$source_filename,
                   width=>$w, height=>$h}};
}


sub ParseFileName {
  my $file = shift;
  my $f = tran($file);
  $f=~s/^.*[\/\\]//g;
  #  $f=tran($f) if $self->param('charset') ne 'русский';
  #АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюяЁё
  $f=~s/[^a-z_0-9\-.]/_/ig;
  $f=~s/\.\.//;
  my ($name,$ext)=($f=~/^(.+)\.(.+)$/i);
  $ext=lc($ext);

  return {name=>$name,ext=>$ext};

}

sub ScaleAndSave {
  my ($src,$sf,$file,$width,$height) = @_;
  my ($w, $h) = $src->getBounds();
  if ($w>$width) {
    my $nw = $width;
    my $nh = round($h*$width/$w,0);
    my $new_src = new GD::Image($nw,$nh);
    $new_src->copyResampled($src,0,0,0,0,$nw,$nh,$w,$h);
    $w=$nw; $h=$nh;
    open (FILE,"> $file") || fatal("Не могу сохранить снимок в файл $file");
    binmode FILE;
    print FILE $new_src->jpeg(80);
    close FILE;
    return ($nw,$nh);
  } else {
    `cp $sf $file`;
    return ($w,$h);
  }

}


sub SaveImage {
  my ($image,$dir,$filename,$ext)=@_;
  my $f="$dir$filename.$ext";
  my $data;
  if ($ext eq 'jpg') {
    $data = $image->jpeg(80);
  } elsif ($ext eq 'png') {
    $data = $image->png();
  } elsif ($ext eq 'gif') {
    $data = $image->gif();
    $ext='gif';
  } else {
    fatal("Неизвестное расширение $ext");
  }
  open (FILE,"> $f") || fatal("Не могу сохранить снимок в файл $f");
  binmode FILE;
  print FILE $data;
  close FILE;
  return "$filename.$ext";
}

sub tran {
  my $str = shift;
  $str=~tr/юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ\xA8\xB8/АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюяЁё/;
  return $str;
}


1;
