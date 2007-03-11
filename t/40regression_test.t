# $Id: 40regression_test.t 976 2007-03-04 20:47:36Z nicolaw $

chdir('t') if -d 't';

use strict;
use warnings;
use Test::More;
use lib qw(./lib ../lib);
use Parse::PrtDiag qw();

plan skip_all => 'Code is not complete yet';

my @files = glob('testdata/*');
plan tests => (scalar(@files)*21) + 1;

my $prtdiag;
ok($prtdiag = Parse::PrtDiag->new(nowarnings => 1),'new');

for my $file (@files) {
	ok($prtdiag->parse(slurp($file)),$file);

	ok($prtdiag->smbios_version >= 2.0,"$file \$prtdiag->smbios_version");
	#ok($prtdiag->dmidecode_version >= 2.0,"$file \$prtdiag->dmidecode_version");
	ok($prtdiag->table_location,"$file \$prtdiag->table_location");

	my @handle_addresses = $prtdiag->handle_addresses;
	my @uniq_handle_addresses = uniq(@handle_addresses); 
	ok(scalar(@handle_addresses) >= $prtdiag->structures,"$file \$prtdiag->handle_addresses >= \$prtdiag->handle_structures");
	ok(scalar(@uniq_handle_addresses) == $prtdiag->structures,"$file unique handle address == \$prtdiag->handle_structures");

	for my $prtdiagtype (qw(0 1 2 3)) {
		my @handles;
		ok(
			@handles = $prtdiag->get_handles( dmitype => $prtdiagtype ),
			"$file \$prtdiag->get_handles(dmitype => $prtdiagtype)"
		);
		ok($handles[0]->dmitype == $prtdiagtype,"$file \$handle->dmitype");
		ok($handles[0]->bytes =~ /^\d+$/,"$file \$handle->bytes");
		ok($handles[0]->description =~ /^\S.{4,64}$/,"$file \$handle->description");
	}
}

sub uniq {
	my %uniq;
	$uniq{$_} = undef for @_;
	return sort keys %uniq;
}

sub slurp {
	my $file = shift;
	my $data = '';
	if (open(FH,'<',$file)) {
		local $/ = undef;
		$data = <FH>;
		close(FH);
	}
	return $data;
}

1;

