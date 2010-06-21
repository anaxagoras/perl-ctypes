#!perl

use Test::More tests => 6;

use Ctypes;
use DynaLoader;

my ($func, $sig, $ret);
my $libc = Ctypes::find_library("c");
ok( defined $libc, 'Load libc' ) or diag( DynaLoader::dl_error() );

# Testing toupper - integer argument & return type
$func = Ctypes::find_function( $libc, 'toupper' );
diag( sprintf("toupper addr: 0x%x", $func ));
ok( defined $func, 'Load toupper() function' );
$ret = Ctypes::call( $func, "cii", ord('y') );
is( chr($ret), 'Y', "toupper('y') => " . chr($ret) );

my $libm = Ctypes::find_library("m");
ok( defined $libm, 'Load libm' ) or diag( DynaLoader::dl_error() );

# Testing sqrt - double argument & return type
$func = Ctypes::find_function( $libm, 'sqrt' );
diag( sprintf("sqrt addr: 0x%x", $func ));
ok( defined $func, 'Load sqrt() function' );
$ret = Ctypes::call( $func, "cdd", 16.0 );
is( $ret, 4.0, "sqrt(16.0) => $ret" );
