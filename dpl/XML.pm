package dpl::XML;
use strict;
use Exporter;
use dpl::Error;
use dpl::Log;
use dpl::Context;
use XML::LibXSLT;
use XML::LibXML;
use base qw(Exporter);

use vars qw(@EXPORT);

@EXPORT = qw(
	     xmlText

	     xmlFile
	     xmlWrite

	     xmlDecode
	     xmlEncode

	     xmlAttrToHash
             xmlChildToHash

             xmlToString

	    );

#	     htmlRead
#	     xsltRead

sub xmlAttrToHash {
  my $node = shift;
  my %h;
  foreach ($node->attributes()) {
    $h{$_->nodeName()} = xmlDecode($_->value());
  }
  return \%h;
}

sub xmlChildToHash {
  my $node = shift;
  my %hash;
  foreach ($node->findnodes("./node()")) {
    my $type = $_->nodeType();
    next unless $type==1; # next if this is text or comment
    my $name=xmlDecode($_->nodeName());
    $hash{$name}=xmlText($_);
  }
  return \%hash;
}

sub xmlDecode {
  my $text =  shift;
  $text = XML::LibXML::decodeFromUTF8(setting('xml.encode'),$text) if setting('xml.encode');
  die("xml.encode is not defined for text '$text'") unless setting('xml.encode');
  return $text;
}

sub xmlEncode {
  my $text =  shift;
  $text = XML::LibXML::encodeToUTF8(setting('xml.encode'),$text) if setting('xml.encode');
  die("xml.encode is not defined for text '$text'") unless setting('xml.encode');
  return $text;
}

sub xmlWrite {
  my ($doc,$file) = @_;
  $doc->toFile($file) || fatal("Can not open '$file' for writing");
  #  my $mtime=((stat $file)[9]);
  setContext('xmlfile',$file,$doc);
}


sub xmlFile {
  my $file = shift;
  return context('xmlfile',$file) || setContext('xmlfile',$file,xmlRead($file));
}

sub xmlRead    {
  my $file=shift;
#  my $mtime=(stat($file))[9];
  return xmlParser()->parse_file($file);
}


sub xmlParser  {
  return context('xmlparser') || setContext('xmlparser',XML::LibXML->new());
}
sub xsltParser {
  return context('xsltparser') || setContext('xsltparser',XML::LibXSLT->new());
}

sub xmlText {
  my ($element,$path)=@_;
  $path='.' unless $path;
  my $text;
  foreach ($element->findnodes($path)) {
    $text.=xmlDecode($_->textContent());
  }
  return $text;
}

sub xmlToString {
  my ($element,$path)=@_;
  $path='.' unless $path;
  my $text;
  foreach ($element->findnodes($path)) {
    $text.=xmlDecode($_->toString());
  }
  return $text;

}


1;
