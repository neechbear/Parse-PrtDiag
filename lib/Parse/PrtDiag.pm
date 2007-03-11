############################################################
#
#   $Id: PrtDiag.pm 1004 2007-03-11 12:43:25Z nicolaw $
#   Parse::PrtDiag - Interface to prtdiag
#
#   Copyright 2007 Nicola Worthington
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
############################################################

package Parse::PrtDiag;
# vim:ts=4:sw=4:tw=78

use strict;
#use Scalar::Util qw(refaddr);
use Parse::PrtDiag::Handle;
use Parse::PrtDiag::Constants qw(@TYPES %GROUPS);
use Carp qw(croak cluck carp);
use vars qw($VERSION $DEBUG);

$VERSION = '0.03' || sprintf('%d', q$Revision$ =~ /(\d+)/g);
$DEBUG ||= $ENV{DEBUG} ? 1 : 0;

my $objstore = {};


#
# Methods
#

sub new {
	ref(my $class = shift) && croak 'Class name required';
	croak 'Odd number of elements passed when even was expected' if @_ % 2;

	my $self = bless \(my $dummy), $class;
	$objstore->{_refaddr($self)} = {@_};
	my $stor = $objstore->{_refaddr($self)};

	$stor->{commands} = [qw(prtdiag)];
	my $validkeys = join('|','nowarnings',@{$stor->{commands}});
	my @invalidkeys = grep(!/^$validkeys$/,grep($_ ne 'commands',keys %{$stor}));
	delete $stor->{$_} for @invalidkeys;
	cluck('Unrecognised parameters passed: '.join(', ',@invalidkeys))
		if @invalidkeys && $^W;

	for my $command (@{$stor->{commands}}) {
		croak "Command $command '$stor->{$command}'; file not found"
			if defined $stor->{$command} && !-f $stor->{$command};
	}

	DUMP('$self',$self);
	DUMP('$stor',$stor);
	return $self;
}


sub probe {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);

	my $stor = $objstore->{_refaddr($self)};
	eval {
		if (!defined $stor->{prtdiag}) {
			require File::Which;
			for my $command (@{$stor->{commands}}) {
				$stor->{$command} = File::Which::which($command)
					if !defined $stor->{$command};
			}
		}
	};
	croak $@ if $@;

	my ($cmd) = $stor->{prtdiag} =~ /^([\/\.\_\-a-zA-Z0-9 ]+)$/;
	TRACE($cmd);
	croak "prtdiag command '$cmd' does not exist; bum!" if !-f $cmd;

	my $fh;
	local %ENV = %ENV;
	delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};
	open($fh,'-|',$cmd) || croak "Unable to open file handle for command '$cmd': $!";
	while (local $_ = <$fh>) {
		$stor->{raw} .= $_;
	}
	close($fh) || carp "Unable to close file handle for command '$cmd': $!";

	return $self->parse($stor->{raw});
}


sub parse {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);

	my $stor = $objstore->{_refaddr($self)};
	my %data = (handles => []);

	my @lines;
	for (@_) {
		push @lines, split(/\n/,$_);
	}

	my $i = 0;
	for (; $i < @lines; $i++) {
		local $_ = $lines[$i];
		if (/^Handle [0-9A-Fx]+/) {
			last;
		} elsif (/^SYSID present\.\s*/) {
			# No-op
		} elsif (/^# prtdiag ([\d\.]+)\s*$/) {
			$data{prtdiag} = $1;
		} elsif (/^(\d+) structures occupying (\d+) bytes?\.\s*$/) {
			$data{structures} = $1;
			$data{bytes} = $2;
		} elsif (/^DMI ([\d\.]+) present\.?\s*$/) {
			$data{dmi} = $1;
		} elsif (/^SMBIOS ([\d\.]+) present\.?\s*$/) {
			$data{smbios} = $1;
		} elsif (/^(?:DMI )?[Tt]able at ([0-9A-Fx]+)\.?\s*$/) {
			$data{location} = $1;
		}
	}

	for (qw(prtdiag structures bytes dmi smbios location)) {
		$data{$_} = undef if !exists $data{$_};
	}

	my $raw_handle_data = '';
	for (; $i < @lines; $i++) {
		if ($lines[$i] =~ /^Handle [0-9A-Fx]+/) {
			push @{$data{handles}}, Parse::PrtDiag::Handle->new(
					raw => $raw_handle_data,
					nowarnings => $stor->{nowarnings}
				) if $raw_handle_data;
			$raw_handle_data = "$lines[$i]\n";
		} else {
			$raw_handle_data .= "$lines[$i]\n";
		}
	}

	push @{$data{handles}}, Parse::PrtDiag::Handle->new(
			raw => $raw_handle_data,
			nowarnings => $stor->{nowarnings}
		) if $raw_handle_data;

	carp sprintf("Only parsed %d structures when %d were expected",
			scalar(@{$data{handles}}), $data{structures}
		) if scalar(@{$data{handles}}) < $data{structures};

	$stor->{parsed} = \%data;
	DUMP('$stor->{parsed}',$stor->{parsed});

	return $stor->{parsed}->{structures};
}


sub get_handles {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);

	croak 'Odd number of elements passed when even was expected' if @_ % 2;
	my %param = @_;
	my $stor = $objstore->{_refaddr($self)};
	my @handles;
	my $getall = !keys(%param);

	for my $handle (@{$stor->{parsed}->{handles}}) {
		if ($getall ||
			(defined $param{address} && $handle->address eq $param{address}) ||
			(defined $param{dmitype} && $handle->dmitype == $param{dmitype}) ||
			(defined $param{group} && defined $GROUPS{$param{group}} &&
			 grep($_ == $handle->dmitype,@{$GROUPS{$param{group}}}))
			) {
			push @handles, $handle;
		}
	}

	return @handles;
}


sub structures {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);
	return $objstore->{_refaddr($self)}->{parsed}->{structures};
}


sub table_location {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);
	return $objstore->{_refaddr($self)}->{parsed}->{location};
}


sub smbios_version {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);
	return $objstore->{_refaddr($self)}->{parsed}->{smbios};
}


sub handle_addresses {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);
	return map { $_->handle }
		@{$objstore->{_refaddr($self)}->{parsed}->{handles}};
}


sub keywords {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);

	my %keywords;
	my $stor = $objstore->{_refaddr($self)};
	for my $handle (@{$stor->{parsed}->{handles}}) {
		for my $keyword ($handle->keywords) {
			$keywords{$keyword} = 1;
		}
	}

	return sort(keys(%keywords));
}


sub keyword {
	my $self = shift;
	croak 'Not called as a method by parent object'
		unless ref $self && UNIVERSAL::isa($self, __PACKAGE__);
	croak sprintf('%s elements passed when one was expected',
		(@_ > 1 ? 'Multiple' : 'No')) if @_ != 1;

	my $stor = $objstore->{_refaddr($self)};
	for my $handle (@{$stor->{parsed}->{handles}}) {
		if (grep($_ eq $_[0],$handle->keywords)) {
			return $handle->keyword($_[0]);
		}
	}
}


no warnings 'redefine';
sub UNIVERSAL::a_sub_not_likely_to_be_here { ref($_[0]) }
use warnings 'redefine';


sub _blessed ($) {
	local($@, $SIG{__DIE__}, $SIG{__WARN__});
	return length(ref($_[0]))
			? eval { $_[0]->a_sub_not_likely_to_be_here }
			: undef
}


sub _refaddr($) {
	my $pkg = ref($_[0]) or return undef;
	if (_blessed($_[0])) {
		bless $_[0], 'Scalar::Util::Fake';
	} else {
		$pkg = undef;
	}
	"$_[0]" =~ /0x(\w+)/;
	my $i = do { local $^W; hex $1 };
	bless $_[0], $pkg if defined $pkg;
	return $i;
}


sub DESTROY {
	my $self = shift;
	delete $objstore->{_refaddr($self)};
}


sub TRACE {
	return unless $DEBUG;
	carp(shift());
}


sub DUMP {
	return unless $DEBUG;
	eval {
		require Data::Dumper;
		local $Data::Dumper::Indent = 2;
		local $Data::Dumper::Terse = 1;
		carp(shift().': '.Data::Dumper::Dumper(shift()));
	}
}

1;



=pod

=head1 NAME

Parse::PrtDiag - Interface to prtdiag

=head1 SYNOPSIS

 use strict;
 use Parse::PrtDiag ();
 
 my $decoder = Parse::PrtDiag->new(
                     prtdiag => "/usr/platform/sun4u/sbin/prtdiag",
                     nowarnings => 1,
                 );
 $decoder->probe; # Actively probe using prtdiag
  
 # Manually supply your own prtdiag output to be parsed
 # $decoder->parse(qx(sudo /usr/platform/sun4u/sbin/prtdiag));
  
 printf("System: %s, %s",
         $decoder->keyword("system-manufacturer"),
         $decoder->keyword("system-product-name"),
     );

=head1 DESCRIPTION

This module provides an OO interface to diagnostic information through
the I<prtdiag> under Solaris.

=head1 METHODS

=head2 new

 my $decoder = Parse::PrtDiag->new(
                     prtdiag => "/usr/platform/sun4u/sbin/prtdiag",
                     nowarnings => 1,
                 );

This is the constructor method to create a Parse::PrtDiag
object. It accepts two optional arguments; C<prtdiag> and
C<nowarnings>.

The C<prtdiag> argument specifies the full path and filename
of the I<prtdiag> command that should used by the C<probe>
method.

The C<nowarnings> argument instructs Parse::PrtDiag not to
emit any parser warnings.

=head2 probe

 $decoder->probe;

This method executes an active probe to gather information using the
I<prtdiag> command. It does not accept any arguments.

=head2 parse

 my $raw = qx(sudo /usr/platform/sun4u/sbin/prtdiag);
 $decoder->prase($raw);

This method is a passive alternative to the C<probe> method. It
accepts a single string argument which should contain output from
the I<prtdiag> command, which it will parse.

=head2 keyword

 my $serial_number = $decoder->keyword("system-serial-number");

=head2 keywords

 my @keywords = $decoder->keywords;
 my @bios_keywords = $decoder->keywords("bios");
 
 for my $keyword (@bios_keywords) {
     printf("%s => %s\n",
             $keyword,
             $decoder->keyword($keyword)
         );
 }

=head2 handle_addresses

 my @addresses = $decoder->handle_addresses;

=head2 get_handles

 use Parse::PrtDiag::Constants qw(@TYPES);
 
 # Available groups to query: bios, system, baseboard,
 #    chassis, processor, memory, cache, connector, slot
 for my $handle ($decoder->get_handles( group => "memory" )) {
     printf(">> Found handle at %s (%s):\n%s\n",
             $handle->address,
             $TYPES[$handle->dmitype],
             $handle->raw
         );
 }

See L<Parse::PrtDiag::Handle> for accessor method documentation
for handle objects.

=head2 smbios_version

 my $smbios_version = $decoder->smbios_version;

Returns the SMBIOS version number.

=head2 table_location

 my $memory_address = $decoder->table_location;

=head2 structures

 my $total_structures = $decoder->structures;

=head1 SEE ALSO

L<Parse::PrtDiag::Handle>,
L<Parse::PrtDiag::Constants>,
L<Parse::PrtDiag::Examples>,
examples/*.pl,
L<http://search.cpan.org/src/NICOLAW/Parse-PrtDiag-0.03/examples/>

=head1 VERSION

$Id: PrtDiag.pm 1004 2007-03-11 12:43:25Z nicolaw $

=head1 AUTHOR

Nicola Worthington <nicolaw@cpan.org>

L<http://perlgirl.org.uk>

If you like this software, why not show your appreciation by sending the
author something nice from her
L<Amazon wishlist|http://www.amazon.co.uk/gp/registry/1VZXC59ESWYK0?sort=priority>? 
( http://www.amazon.co.uk/gp/registry/1VZXC59ESWYK0?sort=priority )

=head1 COPYRIGHT

Copyright 2007 Nicola Worthington.

This software is licensed under The Apache Software License, Version 2.0.

L<http://www.apache.org/licenses/LICENSE-2.0>

=cut


__END__



