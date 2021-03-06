package Ctypes::Type::Field;
use Ctypes::Util qw|_debug|;
use Ctypes::Type::Struct;
use Carp;
use Data::Dumper;
use overload
  '""'     => \&_string_overload,
  '@{}'    => \&_array_overload,
  '%{}'    => \&_hash_overload,
  '&{}'    => \&_code_overload,
  fallback => 'TRUE';

sub _array_overload {
  return \@{$_[0]->{_rawcontents}->{VALUE}};
}

sub _hash_overload {
  if( caller =~ /^Ctypes::Type/ ) {
    return $_[0];
  }
  my( $self, $key ) = ( shift, shift );
  my $class = ref($self);
  bless $self => 'overload::dummy';
  my $ret = $self->{_rawcontents};
  bless $self => $class;
  return $ret;
}

sub _string_overload {
  return $_[0]->info;
}
sub _code_overload {
  my $self = shift;
  return sub { $self->{_rawcontents}->{VALUE} };
}

sub new {
  my $class = ref($_[0]) || $_[0];  shift;
  my( $key, $val, $offset, $obj ) = ( shift, shift, shift, shift );
  my $self  = {
                _obj         => $obj,
                _index       => $offset,
                _key         => $key,
                _contents    => $val,
                _rawcontents => undef,
              };
  $self->{_rawcontents} = tie $self->{_contents},
    'Ctypes::Type::Field::contents', $self;
  $self->{_contents} = $val;
  return bless $self => $class;
}

#
# Accessor generation - DIFFERENT to most!
#
my %access = (
  typecode          => ['_typecode'],
  name              => ['_name'],
  size              => ['_size'],
  'index'           => ['_index'],
  owner             => ['_owner'],
);
for my $func (keys(%access)) {
  no strict 'refs';
  my $key = $access{$func}[0];
  *$func = sub {
    my $self = shift;
    my $arg = shift;
    _debug( 5, "In $func accessor\n"  );
    croak("The $key method only takes one argument") if @_;
    if($access{$func}[1] and defined($arg)){
      eval{ $access{$func}[1]->($arg); };
      if( $@ ) {
        croak("Invalid argument for $key method: $@");
      }
    }
    if($access{$func}[2] and defined($arg)) {
      $self->{_rawcontents}->{VALUE}->{$key} = $arg;
    }
    _debug( 5, "    $func returning $key...\n"  );
    return $self->{_rawcontents}->{VALUE}->$func;
  }
}

sub contents {
  return $_[0]->{_contents};
}

sub key {
  return $_[0]->{_key};
}

sub info {
  my $self = shift;
  return "<Field type=" . $self->name . ", ofs=" .
    $self->index . ", size=" . $self->size . ">";
}

sub STORE {
  $_[0]->{_contents} = $_[1];
}

sub FETCH {
  return $_[0]->{_contents};
}

sub AUTOLOAD {
  our $AUTOLOAD;
  if ( $AUTOLOAD =~ /.*::(.*)/ ) {
    return if $1 eq 'DESTROY';
    my $func = $1;
    _debug( 5, "Trying to AUTOLOAD for $func in FIELD\n"  );
    my $self = shift;
    _debug( 5, "args: ", @_, "\n") if @_;
    return $self->{_rawcontents}->{VALUE}->$func(@_);
  }
}

package Ctypes::Type::Field::contents;
use strict;
use warnings;
use Carp;
use Ctypes::Util qw|_debug|;
use Data::Dumper;
use Scalar::Util qw|blessed|;

sub TIESCALAR {
  my $class = shift;
  my $object = shift;
  my $self = { _obj  => $object,
               VALUE => undef,
             };
  return bless $self => $class;
}

sub STORE {
  croak("Field's STORE must take an argument") if scalar @_ < 2;
  my( $self, $val ) = ( shift, shift );
  _debug( 5, "In ", $self->{_obj}{_obj}{_name}, "'s Field::STORE with arg '$val',\n"  );
  _debug( 5, "    called from ", (caller(1))[0..3], "\n"  );
  croak("Fields can only be assigned single values") if @_;
  my $need_manual_update = 0;
  if(!ref($val)) {
    _debug( 5, "    \$val had no ref\n"  );
    if( not defined $val ) {
      _debug( 5, "    \$val not defined\n"  );
      if( not defined $self->{VALUE} ) {
        croak( "Fields must be initialised with a Ctypes object" );
      } else {
        _debug( 5, "    setting {VALUE} to undef\n"  );
        ${$self->{VALUE}} = undef;
      }
    }
    if( not defined $self->{VALUE} ) {
      _debug( 5, "    Initialising {VALUE} with plain scalar...\n"  );
      my $tc = Ctypes::Util::_check_type_needed( $val );
      $val = Ctypes::Type::Simple->new( $tc, $val );
      $self->{VALUE} = $val;
      $need_manual_update = 1;
    } else {
      if( $self->{VALUE}->isa('Ctypes::Type::Simple') ) {
        _debug( 5, "    Setting simple type to \$val\n"  );
        ${$self->{VALUE}} = $val;
      } else {
        croak( "Tried to squash ", $self->{VALUE},
               " object with value $val" );
      }
    }
  } else {  # $val is a ref
    _debug( 5, "    \$val is a ref\n"  );
    if( blessed($val) ) {
      if ( $val->isa('Ctypes::Type') ) {
        $val = $val->copy;
        _debug( 5, "    \$val copied successfully\n" ) if $val;
        $self->{VALUE}->_set_owner(undef) if defined $self->{VALUE};
        $self->{VALUE}->_set_index(undef) if defined $self->{VALUE};
        $self->{VALUE} = $val;
        $need_manual_update = 1;
      } else {
        croak( "Structs can only hold Ctypes objects" );
      }
    } else {  # hashref or arrayref
      if( defined $self->{VALUE} ) { # last-ditch attempt...
        my $newval = $self->{VALUE}->new($val);
        if( defined $newval ) {
          $self->{VALUE}->_set_owner(undef) if defined $self->{VALUE};
          $self->{VALUE}->_set_index(undef) if defined $self->{VALUE};
          $self->{VALUE} = $newval;
          $need_manual_update = 1;
        } else {                     # didn't work
          croak( "Couldn't make new ", $self->{VALUE}->name,
                 " object from input ", $val );
        }
      } else {
        # Not sure when this would crop up...
        croak( "Don't know what to do with input ", $val );
      }
    }
  }
  if( $need_manual_update == 1 ) {
    $self->{VALUE}->_set_owner(undef);
    my $datum = ${$self->{VALUE}->data};
    $self->{_obj}{_obj}->_update_( $datum,
                                   $self->{_obj}{_index} );
    $self->{VALUE}->_set_owner( $self->{_obj}{_obj} );
    _debug( 5, "    Setting index ", $self->{_obj}{_index}, " for $val\n"  );
    $self->{VALUE}->_set_index( $self->{_obj}{_index} );
    _debug( 5, "      Got index ", $self->{VALUE}->index, "\n"  );
  }
  return $self->{VALUE};
}

sub FETCH {
  my $self = shift;
  _debug( 5, "In ", $self->{_obj}{_obj}->name, "'s ", $self->{_obj}{_key},
    " field FETCH,\n\tcalled from ", (caller(1))[0..3], "\n");
  if( defined $self->{VALUE}
      and $self->{VALUE}->isa('Ctypes::Type::Simple') ) {
    return ${$self->{VALUE}};
  }
  return $self->{VALUE};
}

1;
