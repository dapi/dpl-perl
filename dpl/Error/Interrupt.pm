package dpl::Error::Interrupt;
use Exporter;
use vars qw(
            @EXPORT
            $IS_INTERRUPTED
           );

@dpl::Error::Interrupt::ISA = qw(Exporter
                                 Error);

@EXPORT=qw(IsInterrupted
           ClearInterrupted);

sub IsInterrupted {
  return $IS_INTERRUPTED;
}

sub ClearInterrupted {
  return $IS_INTERRUPTED=undef;
}

sub throw {
  my ($self,$is_soft) = @_;
  if ($IS_INTERRUPTED || !$is_soft) {
    #    if ($Error::THROWN == $self) {
    #      die $self;
    #    } else {
    if ($IS_INTERRUPTED) {
      print STDERR "\nПовторное прерывание с клавиатуры..\n"
        unless $self->{is_interrupted} || $self eq 'Died';
    } else {
      print STDERR "\nПрерывание с клавиатуры..\n";
    }
    $IS_INTERRUPTED=1; $self->{is_interrupted}=1;
    return $self->SUPER::throw()
      unless $is_soft;
    # local $Error::Depth = $Error::Depth + 1;
    # $self = $self->new(@_) unless ref($self);
    # die $Error::THROWN = $self;
    # }
  } else {
    $IS_INTERRUPTED=1; $self->{is_interrupted}=1;
    print STDERR "\nПрерывание с клавиатуры..\n";
  }
}

1;
