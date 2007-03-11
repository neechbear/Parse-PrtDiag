############################################################
#
#   $Id: Constants.pm 976 2007-03-04 20:47:36Z nicolaw $
#   Parse::PrtDiag::Constants - SMBIOS Constants
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

package Parse::PrtDiag::Constants;
# vim:ts=4:sw=4:tw=78

use strict;
require Exporter;
use vars qw($VERSION $DEBUG
		@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
		@TYPES %GROUPS %TYPE2GROUP);

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(@TYPES %GROUPS %TYPE2GROUP);
%EXPORT_TAGS = (all => \@EXPORT_OK);

$VERSION = '0.03' || sprintf('%d', q$Revision$ =~ /(\d+)/g);
$DEBUG ||= $ENV{DEBUG} ? 1 : 0;

@TYPES = ( # Description                    Index Group(s)
		'CPUs',
		'Environmental Status',
		'FRU Operational Status',
		'FRU Status',
		'HW Revisions',
		'IO Cards',
		'IO Devices',
		'Memory',
		'Memory Configuration',
		'Memory Device Sockets',
		'On-Board Devices',
		'Processor Sockets',
		'Upgradeable Slots',
	);

%GROUPS = (
		'bios'      => [ qw(0 13) ],
		'system'    => [ qw(1 12 15 23 32) ],
		'baseboard' => [ qw(2 10) ],
		'chassis'   => [ qw(3) ],
		'processor' => [ qw(4) ],
		'memory'    => [ qw(5 6 16 17) ],
		'cache'     => [ qw(7) ],
		'connector' => [ qw(8) ],
		'slot'      => [ qw(9) ],
	);

%TYPE2GROUP = ();
for my $group (keys %GROUPS) {
	for my $dmitype (@{$GROUPS{$group}}) {
		$TYPE2GROUP{$dmitype} = $group;
	}
}


1;


=pod

=head1 NAME

Parse::PrtDiag::Constants - SMBIOS Constants

=head1 SYNOPSIS

 use strict;
 use Parse::PrtDiag::Constants qw(@TYPES %GROUPS);
 
=head1 DESCRIPTION

This module provides constants relating to prtdiag output.

=head1 EXPORTS

=head2 @TYPES

=head2 %GROUPS

=head1 SEE ALSO

L<Parse::PrtDiag>

=head1 VERSION

$Id: Constants.pm 976 2007-03-04 20:47:36Z nicolaw $

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



