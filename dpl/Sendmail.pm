package dpl::Sendmail;
use Template;
use Template::Filters;
use strict;
use Error qw(:try);
use MIME::Lite;
use MIME::Words;
use IO::String;
#use openbill::Utils;
use dpl::Db::Table;
use dpl::Log;
use dpl::Error;
use dpl::Config;
use dpl::Context;
use dpl::System;
use dpl::XML;
use Email::Send;# qw[Sendmail];
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        dpl::Base);

@EXPORT=qw(SendMail);

sub SendMail {
  my ($email,$templ,$data,$options)=@_;
  $options={} unless $options;
  $data={} unless $data;
  fatal("Не указан шаблон") unless $templ;
  #  my $sender=xmlDecode(config()->root()->findnodes('./mailer/sender')->pop()->textContent());
  #  print "Посылаю письмо для абонента: ".$self->GetName()."\n" if setting('terminal');

  my $view = GetTemplateView($templ) || fatal("No such template $templ");

  $data->{email}=$email;
  my $output = $view->process($data);
  my $string = IO::String->new($output);
  my $is_text;
  my $text;
  my @keys;
  while (<$string>) {
    s/\n|\r//g;
    if ($is_text) {
      $text.="$_\n";
    } elsif (!$_) {
      $is_text=1;
    } else {
      my ($key,$value)=/^([^:]+):\s+(.*)$/;# || die "error";
      #      die "$key , $value";
      push @keys,[$key,$value];
#      print STDERR "$key: $value\n";
    }
  }
  $Email::Send::Qmail::QMAIL='/var/qmail/bin/qmail-inject';
  my $msg = MIME::Lite->build(TYPE=>'TEXT',
                              Data=>$text);
  $msg->attr('content-type','text/plain');
  $msg->attr('content-type.charset','koi8-r');
  foreach my $v (@keys) {
    $msg->add($v->[0],enc($v->[1]));
  }
  $msg->add("X-Sender","ORIONET");
  $msg->send();
  return 1;
#  die $msg->as_string();
}

sub enc {
  my $rawstr = shift;
  my $email;
  if ($rawstr=~s/(^[a-z0-9-_@.]+\s+)//i) {
    $email=$1;
  }
  my $NONPRINT = "\\x00-\\x1F\\x7F-\\xFF ";
  $rawstr =~ s{([$NONPRINT]{1,10})}{
    MIME::Words::encode_mimeword($1, 'B', 'koi8-r');
  }xeg;
  $email.$rawstr;
}

sub GetTemplateView {
  my $templ = shift;
  my $root = config()->root();
  my $tnode = $root->findnodes("./templates/mail[\@name='$templ']")->pop();
  return error("Шаблон письма '$templ' ненайден") unless $tnode;

  my $view = $tnode->hasAttribute('view')
    ? xmlDecode($tnode->getAttribute('view'))
      : return fatal('template_not_found',$tnode);
  my $vnode = $root->
    findnodes("./views/view[\@name='$view']")->pop();

  my $class = $vnode->hasAttribute('class') ?
    xmlDecode($vnode->getAttribute('class')) :
      fatal("'$view' view class for is not defined");
  return $class->instance($view,$tnode,$vnode);
}


1;
