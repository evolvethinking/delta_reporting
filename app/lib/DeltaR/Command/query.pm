package DeltaR::Command::query;
use DeltaR::Validator;
use Mojo::Base qw( Mojolicious::Command );
use Getopt::Long 'GetOptionsFromArray';
use POSIX qw( strftime );
use Pod::Usage;

our @row;

#
# Formats
#

format INVENTORY_TABLE_TOP=
Class                                                                       Count
----------------------------------------------------------------------------------
.

format INVENTORY_TABLE=
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @* 
$row[0], $row[1]
.

format INVENTORY_CSV_TOP=
Class, Count
.

format INVENTORY_CSV=
@*, @* 
$row[0],$row[1]
.

format CLASS_TABLE_TOP=
Class                    Time                      Hostname                 IP Address          Policy Server
------------------------------------------------------------------------------------------------------------------------
.

format CLASS_TABLE=
^<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<
$row[0], $row[1], $row[2], $row[3], $row[4]
.

format CLASS_CSV_TOP=
Class, Time, Hostname, IP Address, Policy Server
.

format CLASS_CSV=
@*, @*, @*, @*, @*
$row[0], $row[1], $row[2], $row[3], $row[4]
.

format PROMISE_TABLE_TOP=
Promiser                 Promisee            Promise handle             Promise outcome Timestamp              Hostname                 IP address               Policy server
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
.

format PROMISE_TABLE=
^<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<
$row[0], $row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7]
.

format PROMISE_CSV_TOP=
Promiser, Promisee, Promise handle, Promise outcome, Timestamp, Hostname, IP address, Policy server
.

format PROMISE_CSV=
@*, @*, @*, @*, @*, @*, @*, @*
$row[0], $row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7]
.


sub run
{
   my ( $self, @args ) = @_;
   my ( $rows, $report_type );
   my $dq = $self->app->dr;

   my $gmt_offset =
      strftime( '%z', localtime ) or die;
   my $timestamp  =
      strftime( '%Y-%m-%d %H:%M:%S', localtime) or die;
   #
   # Defaults
   #
   my %query_params = (
      hostname        => '%',
      ip_address      => '%',
      gmt_offset      => $gmt_offset,
      timestamp       => $timestamp,,
      latest_record   => 0,
      delta_minutes   => -30,
      policy_server   => '%',
      promiser        => '%',
      promisee        => '%',
      promise_handle  => '%',
      promise_outcome => '%',
      output          => 'default',
   );

   GetOptionsFromArray (
      \@args, \%query_params,
      'help|?',
      'class=s',
      'delta_minutes=s',
      'gmt_offset=s',
      'hostname=s',
      'inventory',
      'ip_address=s',
      'latest_record',
      'output=s',
      'policy_server|ps=s',
      'promise_handle|ph=s',
      'promise_outcome|po=s',
      'promisee|pe=s',
      'promiser|pr=s',
      'timestamp=s',
   );

   if ( $query_params{timestamp} )
   {
      if ( $query_params{timestamp} =~ m/^(.*)([-+]\d+)$/ )
      {
         $query_params{timestamp} = $1;
         $query_params{gmt_offset} = $2;
      }
   }

   #
   # Help and validate
   #
   my $delta_validator
      = DeltaR::Validator->new({ input => \%query_params });
   my @validator_errors;

   if ( $query_params{class} ) {
      @validator_errors = $delta_validator->class_query_form();
   }
   elsif ( $query_params{promiser} ) {
      @validator_errors = $delta_validator->promise_query_form();
   }

   if ( (scalar @validator_errors) > 0 ) {
      my $msg = join ' ', @validator_errors;
      usage( $self, $msg );
      exit 1;
   }

   # Truncate long fields to guard against overflow.
   for my $next_field ( keys %query_params ) {
      $query_params{ $next_field }
         = substr( $query_params{ $next_field }, 0, 250 );
   }

   #
   # Perform query
   #
   if ( $query_params{inventory} ) {
      $report_type = 'inventory';
      $rows = $dq->query_inventory;
   }
   elsif ( $query_params{class} ) {
      $report_type = 'class';
      $rows = $dq->query_classes( \%query_params );
   }
   elsif ( $query_params{promiser} ) {
      $report_type = 'promise';
      $rows = $dq->query_promises( \%query_params );
   }
   else {
      usage( $self, "No query type given (e.g. class, promise, inventory)" );
      exit 1;
   }

   #
   # Determine and set output format
   #
	my $fh = get_output_format( 
      output      => $query_params{output},
      report_type => $report_type
   );
	local $~ = $fh;
	local $^ = $fh. "_TOP";

   #
   # Generate output
   #
   for my $row ( @{$rows} )
   {
      @row  = @{$row};
      write;
   }
}

sub get_output_format
{
   my %args = @_;

	my $REPORT_TYPE = uc( $args{report_type} );

	if ( $args{output} eq 'csv' )
	{
		$REPORT_TYPE = $REPORT_TYPE."_CSV";
	}
	else
	{
		$REPORT_TYPE = $REPORT_TYPE."_TABLE";
	}
	return $REPORT_TYPE;
}

sub usage
{
   my ( $self, $msg ) = @_;
   say $msg if ( defined $msg );
   say $self->extract_usage;
}

1;

##########################
# POD
=pod

=head1 SYNOPSIS

query
[ -he | --help ] help

[ -o | --output csv

[ -ho | --hostname ] hostname of agent host

[ -ip | --ip_address ] IP address of agent host

[ -t | --timestamp ] timestamp of record in the form of 'yyyy-mm-dd hh:mm:ss[+-]zzzz'

[ -d | --delta_minutes ] delta time in minutes from timestamp. 

[ -l | --latest_record ] Report latest matching entries rather than time range.

[ -ph | --promise_handle ] promise handle

[ -po | --promise_outcome[ kept|notkept|repaired ]

[ -ps | --policy_server ] policy server name or IP

[ -pr | --promiser ] promiser

[ -pe | --promisee ] promisee

[ -c | --class ] CFEngine class

[ -in | --inventory] report inventory (hard classes)

Use perldoc to see full documentation.

=head1 DETAILED OPTIONS

=over

=item [ -h | --help ]

Print help and exit.

=item [ -ho | --hostname ]

hostname of agent host

=item [ -ip | --ip_address ]

IP address of agent host

=item [ -t | --timestamp ]

timestamp of record in the form of 'yyyy-mm-dd hh:mm:ss[+-]zzzz'. Defaults to the current time.

=item [ -d | --delta_minutes ]

delta time in minutes from timestamp. Used to report between a time range, timestamp plus or minus delta minutes. If no timestamp is given then delta is taken from the current time. Defaults to -30 minutes.

=item [ -ph | --promise_handle ]

promise handle

=item [ -r | --promise_outcome]

[ %|kept|notkept|repaired ]

=item [ -ps | --policy_server ]

policy server name or IP

=item [ -pr | --promiser ]

promiser

=item [ -pe | --promisee ]

promisee

=item [ -in | --inventroy]

Ignore all other options and perform hard class inventory report.

=back

=head1 DESCRIPTION

Query can query both class membership and promise results. In most cases the queries can accept the SQL '%' wild card.

=head1 CAVEATS

The number of records returned is limited by the record limit in DeltaR.conf.

Reporting latest entries is more time comsuming for the database than using a range.

=head1 EXAMPLES

=over

=item Report inventory from the past 60 minutes

  query --inventory

   Class                                                                       Count
   ----------------------------------------------------------------------------------
   am_policy_hub                                                               1
   any                                                                         1
   centos                                                                      1
   centos_6                                                                    1
   centos_6_5                                                                  1
   cfengine_3                                                                  1
   cfengine_3_6                                                                1
   cfengine_3_6_0rc                                                            1
   cfengine_3_6_0rc_59ca863                                                    1
   community_edition                                                           1
   ipv4_127                                                                    1
   ipv4_127_0                                                                  1
   ipv4_127_0_0                                                                1
   ipv4_127_0_0_1                                                              1
   ipv4_172                                                                    1
   ipv4_172_16                                                                 1
   ipv4_172_16_100                                                             1
   ipv4_172_16_100_11                                                          1
   linux                                                                       1
   linux_2_6_32_431_5_1_el6_x86_64                                             1
   linux_x86_64                                                                1
   linux_x86_64_2_6_32_431_5_1_el6_x86_64                                      1
   linux_x86_64_2_6_32_431_5_1_el6_x86_64__1_SMP_Wed_Feb_12_00_41_43_UTC_2014  1
   policy_server                                                               1
   redhat                                                                      1
   redhat_derived                                                              1

=item Report latest know members of the redhat class

 query -c redhat 

   Class                    Time                      Hostname                 IP Address          Policy Server
   ------------------------------------------------------------------------------------------------------------------------
   redhat                   2014-05-22 10:01:23-04    frodo.watson-wilson.ca.  2001:470:1d:a2f::9  frodo.watson-wilson.ca

=item Report members of classes like ipv4_172_16 between 2014-05-20 09:00:00-05 and 0800 which is a delta of -60 minutes

 query -c 'ipv4_172_16%' -t '2014-05-20 09:00:00-05' -d -60 

   Class                    Time                      Hostname                 IP Address          Policy Server
   ------------------------------------------------------------------------------------------------------------------------
   ipv4_172_16              2014-05-20 08:56:30-04    frodo.watson-wilson.ca.  2001:470:1d:a2f::9  frodo.watson-wilson.ca
   ipv4_172_16_100_11       2014-05-20 08:56:30-04    frodo.watson-wilson.ca.  2001:470:1d:a2f::9  frodo.watson-wilson.ca
   ipv4_172_16_100          2014-05-20 08:56:30-04    frodo.watson-wilson.ca.  2001:470:1d:a2f::9  frodo.watson-wilson.ca
   ipv4_172_16_100          2014-05-20 08:50:59-04    frodo.watson-wilson.ca.  2001:470:1d:a2f::9  frodo.watson-wilson.ca
   ...

=item Report latest promise results where the promiser is /etc/passwd

 query -pr '/etc/passwd'

   Promiser     Promisee            Promise handle             Promise outcome Timestamp              Hostname                 IP address         Policy server
   -------------------------------------------------------------------------------------------------------------------------------------------------------------
   /etc/passwd  nsa_rhel5 v4.2 sec  efl_file_perms_files_posit kept            2014-05-22 14:01:14-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9 frodo.watson-wilson.ca

=item Report promise outcome that were repaired between 2014-05-20 09:00:00-05 and 0800 which is a delta of -60 minutes
 
 query -po repaired -t '2014-05-20 09:00:00-05' -d -60 promise
 
   Promiser       Promisee            Promise handle             Promise outcome Timestamp              Hostname                 IP address               Policy server
   -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:56:30-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:50:59-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:46:29-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:36:26-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:30:55-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:26:24-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:20:53-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:16:22-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:06:20-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca
   /bin/true     efl testing          efl_command_commands       repaired        2014-05-20 08:00:49-04 frodo.watson-wilson.ca.  2001:470:1d:a2f::9       frodo.watson-wilson.ca

=back

=head1 SEE ALSO

=head1 LICENSE

Delta Reporting is a central server compliance log that uses CFEngine.

Copyright (C) 2016 Neil H. Watson http://watson-wilson.ca

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

