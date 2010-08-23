#!perl

BEGIN { unshift @INC, './t' }

use Test::More tests => 1;
use Ctypes;
use Data::Dumper;
use t_POINT;
my $Debug = 0;

note( 'Simple construction (hashref)' );

my $struct = Struct({
  f1 => c_int(10),
  f2 => c_long(90000),
  f3 => c_char('P'),
});
subtest 'hashref initialisation' => sub {
  plan tests => 4;
  isa_ok( $struct, 'Ctypes::Type::Struct' );
  is( $struct->f1, 10 );
  is( $struct->f2, 90000 );
  is( $struct->f3, 'P' );
}

note( 'Ordered construction (arrayref)' );

my $ordstruct = Strct([
  o1 => c_int(20),
  o2 => c_long(180000),
  o3 => c_char('Q'),
]);
subtest 'arrayref initialisation' => sub {
  plan tests => 4;
  isa_ok( $struct, 'Ctypes::Type::Struct' );
  is( $struct->f1, 10 );
  is( $struct->f2, 90000 );
  is( $struct->f3, 'P' );
}

note( 'Positional parameterized construction' );

my $point = new t_POINT( 30, 40 );
isa_ok( $point, 't_POINT' );

$struct->foo->(7);
s( $$int, 7, 'Modify members without squashing' );

$struct->bar->(14);
my $data = pack('i',7) . pack('d',14);
is( ${$struct->data}, $data, '_data looks alright' );
my $twentyfive = pack('i',25);
my $dataref = $struct->data;
substr( ${$dataref}, 0, length($twentyfive) ) = $twentyfive;
is( $$int, 25, 'Data modifications percolate down' );

# Nesting is nice
subtest 'Arrays in structs' => sub {
  plan tests => 1;

  my $grades = Array( 49, 80, 55, 75, 89, 31, 45, 65, 40, 71 );
  my $class = Struct({ fields => [
    [ teacher => 'P' ],
    [ grades  => $grades ],
  ] });

  my $total;
  for( @{$$class->grades} ) { $total += $_ };
  my $average = $total /  scalar @{$$class->grades};
  is( $average, 60, "Mr Peterson's could do better" );
};

subtest 'Structs in structs' => sub {
  plan tests => 5;
  
  my $flowerbed = Struct({ fields => [
    [ roses => 3 ],
    [ heather => 5 ],
    [ weeds => 2 ],
  ] });
  
  my $garden = Struct({ fields => [
    [ fence => 30 ],
    [ flowerbed => $flowerbed ],
    [ lawn => 20 ],
  ] });
  
  #print '$garden->flowerbed: ',$garden->flowerbed, "\n";
  #print '$$garden->flowerbed: ', $$garden->flowerbed, "\n\n";
  
  #print '$garden->flowerbed->contents: ',$garden->flowerbed->contents, "\n";
  #print '$$garden->flowerbed->contents: ',$$garden->flowerbed->contents, "\n\n";
  
  #print '$garden->flowerbed->roses: ',$garden->flowerbed->roses, "\n";
  #print '$$garden->flowerbed->roses: ',$$garden->flowerbed->roses, "\n\n";
  
  #print '$garden->flowerbed->contents->roses: ',$garden->flowerbed->contents->roses, "\n";
  #print '$$garden->flowerbed->contents->roses: ', $$garden->flowerbed->contents->roses, "\n\n";
  
  is( $garden->flowerbed->contents->roses,
      '<Field type=c_short, ofs=0, size=2>',
      '$garden->flowerbed->contents->roses gives field (how nice...)' );
  is( $$garden->flowerbed->contents->roses,
      '3','$$garden->flowerbed->contents->roses gives 3' );
  
  my $home = Struct({ fields => [
    [ house => 40 ],
    [ driveway => 20 ],
    [ garden => $garden ],
  ] });
  
  # print $home->garden->contents->flowerbed->contents->heather, "\n";
  # print $$home->garden->contents->flowerbed->contents->heather, "\n";
  
  is( $home->garden->contents->flowerbed->contents->heather,
      '<Field type=c_short, ofs=2, size=2>',
      '$home->garden->contents->flowerbed->contents->heather gives field' );
  is( $$home->garden->contents->flowerbed->contents->heather,
      '5', '$$home->garden->contents->flowerbed->contents->heather gives 5' );
  $home->garden->contents->flowerbed->contents->heather->(500);
  is( $$garden->heather, 500, "That's a quare load o' heather - garden updated via \$home" );
};

