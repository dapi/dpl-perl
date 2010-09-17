package dpl::Web::Site;
use strict;
use dpl::Error;
use dpl::Log;
use dpl::Config;
use dpl::XML;
use dpl::Base;
use dpl::Context;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(dpl::Base);

sub init {
  my ($self,$node,$home,$path) = @_;
  $self->{home} = $home;
  $self->{config} = config()->root(); # short cut
  setContext('site',$self);
  return $self;
}

sub deinit {
  my ($self,$is_ok) = @_;
#  print STDERR "Site: deinit ($is_ok)\n";
  $self->{processor}->deinit($is_ok)
    if $self->{processor};
}

sub preparePaths {
  my ($self,$path) = @_;
  my $query;
  setting('uri')->{full_path}=$path;
  if ($path=~s/\?(.*)$//) {
    $query=$1;
  }
  setting('uri')->{query}=$query;
  $self->{query} = $query;
  $self->{site_node} = $self->lookupSiteNode() ||
    $self->fatal("Can't lookup site node: $self->{name}");
  $self->{page} = $self->lookupPage($self->{path} = $path) ||
    $self->lookupFolder($path) || return undef;
  $self->{page}->{query}=$query;

  setting('uri')->{page_path}=$self->{page}->{path};
  setting('uri')->{current_path}=setting('uri')->{home}.$self->{page}->{path};
  setting('uri')->{page_tail}=$self->{page}->{tail};
  return $self->{page};
}

sub lookup {
  my ($self,$path) = @_;

  $self->preparePaths($path) || return undef;

  unless ($self->{page}->{container}) {
    return 1 unless $self->{page}->{processor};
    $self->{processor} = $self->lookupProcessor($self->{page}->{processor});
    return $self->{processor}->lookup($self->{page}->{tail});
  }
  $self->{container} = $self->lookupContainer($self->{page}->{container});
  return $self->{object} = $self->{container}->lookup($self->{page}) || return undef;
}

sub lookupProcessor {
  my ($self,$name) = @_;
  my $s="\@site='$self->{name}'";
  $s="not(\@site) or $s" if $self->{name} eq 'default';
  my $node=$self->{config}->findnodes("./processors[$s]/processor[\@name='$name']")->pop() ||
    $self->{config}->findnodes("./processors/processor[\@name='$name' and ($s)]")->pop() ||
      $self->fatal("No specified processor ($name) is find");
  my $class = $node->hasAttribute('class') ? xmlDecode($node->getAttribute('class')) :  $self->fatal("No processor's class is defined");
  return $class->instance($name,
                          $node,
                          $self->{page})
    || $self->fatal("Can't init processor: $name");
}

sub lookupContainer {
  my ($self,$name) = @_;
  my $s="\@site='$self->{name}'";
  $s="not(\@site) or $s" if $self->{name} eq 'default';
  my $node=$self->{config}->findnodes("./containers[$s]/container[\@name='$name']")->pop() ||
    $self->{config}->findnodes("./containers/container[\@name='$name' and ($s)]")->pop() ||
      $self->fatal("No specified container ($name) is find");
  my $class = $node->hasAttribute('class') ? xmlDecode($node->getAttribute('class')) :  $self->fatal("No container's class is defined");
  return $class->instance($name,
                          $node,
                          $self->{page})
    || $self->fatal("Can't init container: $name");
}



sub lookupSiteNode {
  my ($self) = @_;
#  logger()->debug("Looking for site node");
  my $s="\@name='$self->{name}'";
  $s="not(\@name) or $s" if $self->{name} eq 'default';
  my $q="./site[$s]";
#  logger()->debug("Lookup site XPath: $q");
  my $node=$self->{config}->findnodes($q)->pop();
  return $node;
}

sub lookupPage {
  my ($self,$path) = @_;
#  logger()->debug("Looking for page with path: $path");
  my $q=".//page[\@path='$path']";
#  logger()->debug("Lookup page XPath: $q");
  my $node=$self->{site_node}->findnodes($q)->pop();
  return undef unless $node;
  return $self->getPageParams($node,$path);
}

sub lookupFolder {
  my ($self,$path) = @_;
#  logger()->debug("Looking for folder with path: $path");
  my $q=".//folder[starts-with('$path',\@path)]";
#  logger()->debug("Lookup folder XPath: $q");
  my $node;
  foreach ($self->{site_node}->findnodes($q)) {
    my $prev_path = ($node && $node->hasAttribute('path')) ? xmlDecode($node->getAttribute('path')) : '';
    my $path = $_->hasAttribute('path') ? xmlDecode($_->getAttribute('path')) : '';
    $node = $_ if !$node || length($path)>length($prev_path);
  }
  return undef unless $node;
  return $self->getPageParams($node,$path);
}

sub getPageParams {
  my ($self,$node,$p) = @_;
  my $path = $node->hasAttribute('path') ? xmlDecode($node->getAttribute('path')) : '';
  my $tail = substr($p,length($path));
  my $action = $node->hasAttribute('action') ? xmlDecode($node->getAttribute('action')) : 'default';
  my $processor = $node->hasAttribute('processor') ? xmlDecode($node->getAttribute('processor')) : undef;
  my $container = $node->hasAttribute('container') ? xmlDecode($node->getAttribute('container')) : undef;
  my $oid = $node->hasAttribute('oid') ? xmlDecode($node->getAttribute('oid')) : undef;
  my $template  = $node->hasAttribute('template') ? xmlDecode($node->getAttribute('template')) : undef;
#  logger()->debug("Page is found. Path: $path, tail: $tail, processor: $processor, action: $action, template: $template");
  return {node=>$node,path=>$path,tail=>$tail,
          container=>$container,oid=>$oid,
	  processor=>$processor,template=>$template,action=>$action};
}

sub loadView {
  my ($self,$template,$template_file)=@_;
#  logger()->debug("Select template: $template");
  my $s="\@site='$self->{name}'";
  $s="not(\@site) or $s"
    if $self->{name} eq 'default';
  my $tnode = $self->{config}->
    findnodes("./templates[$s]/template[\@name='$template']")->pop() ||
      $self->fatal("Template '$template' is not found");
  my $view = $tnode->hasAttribute('view')
    ? xmlDecode($tnode->getAttribute('view'))
      : return dpl::Web::View::Internal->instance('template_not_found',$tnode);
  my $vnode = $self->{config}->
    findnodes("./views[$s]/view[\@name='$view']")->pop();
  unless ($vnode) {
    $vnode = $self->{config}->
      findnodes("./views/view[\@name='$view']")->pop()
        if $self->{name};
    $self->fatal("View '$view' is not found")
      unless $vnode;
  }
  my $class = $vnode->hasAttribute('class') ?
    xmlDecode($vnode->getAttribute('class')) :
      $self->fatal("'$view' view class for is not defined");
  return $class->instance($view,$tnode,$vnode); #,     $self->{processor}
}


sub execute {
  my $self = shift;
  my $o = $self->{object};

  my $action;
  if ($self->{container}) {
    fatal("No object from container when execute") unless $o;
    my $p = $o->GetProcessor() || $self->{page}->{processor};
    return $o->GetDataToView() unless $p;
    $self->{processor} = $self->lookupProcessor($p);
    $action = $o->GetAction();
  } elsif (!$self->{processor}) {
    return undef;
  }
  my $res = $self->{processor}->execute($action,$o);
  #print STDERR "Execute: $res\n";
  return $res;
  #    || return Apache::DECLINED;
}

sub data {
  my $self = shift;
  return {page=>$self->{page}, name=>$self->{name},
	  path=>$self->{path}, home=>$self->{home}};
}

sub show {
  my ($self, $result) = @_;
#  print STDERR "show\n";
  my %output = (result=>$result,
                set=>getSettings(),
                context=>getContext(),
                site=>$self->data()
               );
  my $view;
  my $template = $self->{object} ? $self->{object}->GetTemplate() : undef;
  $template = $self->{page}->{template} unless $template;
  my $template_file = $self->{page}->{template_file};
  if ($self->{processor}) {
    $output{data}    = $self->{processor}->data();
    $output{set_cookie} = $self->{processor}->getCookies();
    $output{options} = $self->{processor}->viewOptions();
    #    $output{params} = $self->{processor}->param();
    $view = $self->loadView($self->{processor}->template() || $template);
    $template_file = $self->{processor}->template_file() || $template_file;
  } else {
    $view = $self->loadView($template);

  }
  return $view->show(\%output,$template_file);
}


sub fatal {
  my $self = shift;
  unshift @_,"site:$self->{name}" if $self=~/HASH/;
  dpl::Error::fatal(@_);
}

1;
