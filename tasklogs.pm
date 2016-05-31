﻿######################################################################
# tasklogs.pm - sub-routines used by the tasklogs scripts
# See end of file for user documentation.
######################################################################

package tasklogs;

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);
@EXPORT = qw(get_taskdir get_timesheetsdir get_daily_script get_weekly_script get_endofday_filename backup_logfn rename_task get_logfn fmttimearr get_break_aliases redotime clear_daily_files printdebug);

use Math::Round qw(nearest);
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::Natural;

my $DEBUG = 0;

# change at your own risk -- some of the other scripts might not be forgiving
my $tasklogs_dirname   = 'tasklogs';  # main directory for all tasklogs
my $tasklog_filename   = '.hours';    # task log file, stored in $tasklogs_dirname
my $tasklogs_backupdir = 'backups';   # subdirectory of $tasklogs_dirname

######################################################################
# Get the name of the tasklogs directory
#
sub get_taskdir() {
    my $taskdir = "";

    # TODO: change this to something more robust for determining path separators
    if (defined $ENV{HOME}) {
        $taskdir = $ENV{HOME} . "/$tasklogs_dirname/";
    } elsif (defined $ENV{HOMEDRIVE} && defined $ENV{HOMEPATH}) {
        $taskdir = $ENV{HOMEDRIVE} . $ENV{HOMEPATH} . "$tasklogs_dirname\\";
    } else {
        die "Error: HOME or (HOMEDRIVE and HOMEPATH) environment variables not set\n";
    }

    if ( ! -d "$taskdir" ) {
        mkdir "$taskdir" or die "Error: $taskdir could not be created: $!";
    }
    die "Error: $taskdir is not accessable" unless ( -x $taskdir );
    die "Error: $taskdir is not readable"   unless ( -r $taskdir );
    die "Error: $taskdir is not writable"   unless ( -w $taskdir );

    return $taskdir;
}

######################################################################
# Get the name of the timesheets directory
#
sub get_timesheetsdir() {
    my $timesheetdir;
    my $taskdir = &get_taskdir();

    if (defined $ENV{HOME}) {
        $timesheetdir = $taskdir . "timesheets/";
    } elsif (defined $ENV{HOMEDRIVE} && defined $ENV{HOMEPATH}) {
        $timesheetdir = $taskdir . "timesheets\\";
    } else {
        die "Error: HOME or (HOMEDRIVE and HOMEPATH) environment variables not set\n";
    }
    die "Error: $timesheetdir does not exist" unless ( -d $timesheetdir );
    die "Error: $timesheetdir is not accessable" unless ( -x $timesheetdir );
    die "Error: $timesheetdir is not readable" unless ( -r $timesheetdir );
    die "Error: $timesheetdir is not writable" unless ( -w $timesheetdir );

    return $timesheetdir;
}

######################################################################
# Get the daily.pl script location
#
sub get_daily_script() {
    return &get_taskdir() . 'daily.pl';
}

######################################################################
# Get the weekly.pl script location
#
sub get_weekly_script() {
    return &get_taskdir() . 'weekly.pl';
}

######################################################################
# Get the name of the end-of-day log file
#
sub get_endofday_filename($) {
    my $task = shift;
    my $day = undef;
    ($task, $day) = split( /\s+/, $task, 2 );
    if ( defined $day ) {
        my $tz = DateTime::TimeZone->new( name => "local" );
        my $parser = DateTime::Format::Natural->new( time_zone => $tz->name() );
        my $dt = $parser->parse_datetime($day);
        if ( $parser->success() ) {
            $day = $dt->day_name();
        } else {
            die "Error: Could not parse provided day [$day]: " . $parser->error() . "\n";
        }
    } else {
        die "Error: No day provided\n";
    }

    my $taskdir = &get_taskdir();
    return "$taskdir.$day";
}

######################################################################
# Backup the hours log file
#
sub backup_logfn($;) {
    my $logfn = shift;
    rename $logfn, "$logfn.bak" or die "Error: $logfn.bak: $!\n";
}

######################################################################
# Renames all tasks in $logfn named $oldtask to $newtask
#
sub rename_task($$$;) {
    my $logfn   = shift;
    my $oldtask = shift;
    my $newtask = shift;
    my $count   = 0;

    if ( -f "$logfn" ) {
        open( INFILE, "<$logfn" ) or die "Error: Could not open $logfn for input: $!\n";
        open( OUTFILE, ">$logfn.tmp" ) or die "Error: Could not open $logfn.tmp for output: $!\n";
        while (<INFILE>) {
            if ( $_ =~ s/$oldtask/$newtask/i ) {
                $count++;
            }
            print OUTFILE $_;
        }
        close INFILE;
        close OUTFILE;
        rename "$logfn.tmp", "$logfn" or die "Error: Could not rename $logfn.tmp to $logfn: $!\n";
    } else {
        print STDERR "Warning: task log file $logfn not found\n";
    }

    if ( $count > 0 ) {
        print "Done: [$count] instance"
              . ($count>1?'s':'')
              . " of [$oldtask] "
              . ($count>1?'have':'has')
              . " been renamed to [$newtask].\n";
    } else {
        print "Done: No instances of [$oldtask] were found.\n";
    }
}

######################################################################
# Get the name of the task log file
#
sub get_logfn() {
    my $taskdir = &get_taskdir();
    my $logfn = $taskdir . $tasklog_filename;
}

######################################################################
# Format Time Array Values as 2-digit values
#
# TODO: update to use DateTime
#
sub fmttimearr(\@) {
    my $timearr = shift;
    my $timestr;
    my $ampm    = 'AM';

    # Adjust second and minute to be 2-digit numeric strings
    $$timearr[0]  = sprintf( "%2.2d", $$timearr[0] );
    $$timearr[1]  = sprintf( "%2.2d", $$timearr[1] );

    # Determine AM or PM and adjust hour to be w-digit numeric string
    if ( $$timearr[2] > 12 ) {
        $$timearr[2]  = sprintf( "%2.2d", $$timearr[2] - 12 );
        $ampm         = 'PM';
    }
    elsif ( $$timearr[2] == 0 ) {
        $$timearr[2]  = sprintf( "%2.2d", $$timearr[2] + 12 );
        $ampm         = 'AM';
    }
    else {
        $$timearr[2]  = sprintf( "%2.2d", $$timearr[2] );
        $ampm         = 'AM';
    }

    # Adjust month to be in the 1-12 range
    $$timearr[4]++;

    # Adjust year for years >= 2000
    $$timearr[5] -= 100 if ( $$timearr[5] >= 100 );

    # Adjust month, monthday, and year to be 2-digit numeric strings
    $$timearr[3] = sprintf( "%2.2d", $$timearr[3] );
    $$timearr[4] = sprintf( "%2.2d", $$timearr[4] );
    $$timearr[5] = sprintf( "%2.2d", $$timearr[5] );

    # Construct the formated time string
    $timestr  = join( '/', $$timearr[4], $$timearr[3], $$timearr[5] );
    $timestr .= ' ';
    $timestr .= join( ':', $$timearr[2], $$timearr[1], $$timearr[0] );
    $timestr .= " $ampm";

    return $timestr;
}

######################################################################
# Returns an array of 'break' aliases.
# Attempts to read a config file, if file exists uses contents,
# otherwise uses a set of standard aliases.
#
sub get_break_aliases() {
    my $fn = &get_taskdir() . '.break_aliases';
    my @aliases;
    if ( -f "$fn" ) {
        if ( open( INPUT, $fn ) ) {
            while ( <INPUT> ) {
                chomp;
                push( @aliases, $_ );
            }
            close( INPUT );
        }
    } else {
        # No break_aliases file defined, using standard values
        push( @aliases, 'Break', 'Lunch', 'Sick', 'Vacation', 'Holiday' );
    }
    return @aliases;
}

######################################################################
# Redo $time as either hours, minutes, or seconds
#
sub redotime($) {
    my $time = shift;
    my $desc = "";

    if ( $time > 60 * 60 ) {
        $time = $time / 60 / 60;
        $desc = 'hours';
    }
    elsif ( $time > 60 ) {
        $time = $time / 60;
        $desc = 'minutes';
    }
    else {
        $desc = 'seconds';
    }
    return ($time, $desc);
}

######################################################################
# Clear the daily log files (by deletion)
#
sub clear_daily_files(\%) {
    my $totalsref = shift;
    &printdebug( 1, "in clear function" );

    my $taskdir = &get_taskdir();

    foreach my $day ( keys %$totalsref ) {
        my $daily_file = "$taskdir.$day";
        if ( -e "$daily_file" ) {
            print "Removing $daily_file\n";
            unlink "$daily_file" or die "Error: Could not remove $daily_file: $!\n";
        }
    }
}

######################################################################
# Prints the debug string to the DEBUG filehandle if:
# * $DEBUG is true (positive non-zero number)
# * $lev is at or below $DEBUG
#
sub printdebug($$;) {
    if ( $DEBUG ) {
        open( DEBUG, ">&STDERR" ) or die "Error: Problems opening debug filehandle\n";
        my ($lev, $str) = @_;
        if ($lev <= $DEBUG) {
            print DEBUG "DEBUG[$lev]: $str\n";
        }
        close( DEBUG );
    }
}

######################################################################
1; # End of module ###################################################
######################################################################
__END__

=pod

=head1 NAME

C<tasklogs.pm> - sub-routines used by the tasklogs scripts

=head1 DESCRIPTION

This module contains supporting methods for the tasklogs scripts.

=head1 METHODS

=over

=item get_taskdir
    Get the name of the tasklogs directory

=item get_timesheetsdir
    Get the name of the timesheets directory

=item get_daily_script
    Get the C<daily.pl> script location

=item get_weekly_script
    Get the C<weekly.pl> script location

=item get_endofday_filename
    Get the name of the end-of-day log file

=item backup_logfn
    Backup the hours log file

=item rename_task
    Renames all tasks in C<$logfn> named C<$oldtask> to C<$newtask>

=item get_logfn
    Get the name of the task log file

=item fmttimearr
    Format Time Array Values as 2-digit values

=item get_break_aliases
    Returns an array of 'break' aliases.
    Attempts to read a config file, if file exists uses contents,
    otherwise uses a set of standard aliases.

=item redotime
    Redo C<$time> as either hours, minutes, or seconds

=item clear_daily_files
    Clear the daily log files (by deletion)

=item printdebug
    Prints the debug string to the C<DEBUG> filehandle if:
    C<$DEBUG> is true (positive non-zero number)
    C<$lev> is at or below C<$DEBUG>

=back

=head1 ENVIRONMENT VARIABLES 

Environment variables are used for determining which OS path separator to use.

=over

=item HOME
    if I<HOME> is found, assume unix-like environment

=item HOMEDRIVE, HOMEPATH
    if I<HOMEDRIVE> and I<HOMEPATH> are both found, assume Windows

=back

=head1 FILES

=over

=item .hours
    task log for the current day

=item .hours.bak
    task log for the previous day

=item .C<day-of-week>
    end of day report for the indicated I<day-of-week> (e.g., C<.Monday>, or C<mon>)

=item timesheets/C<YYMMDD.log>
    timesheet for week ending I<YYMMDD>

=item .break_aliases
    optional config file, defines I<task names> treated as aliases to I<break>

=back

=head1 REQUIRED MODULES

=over

=item L<DateTime>

=item L<DateTime::TimeZone>

=item L<DateTime::Format::Natural>

=item L<Lingua::EN::Titlecase>

=item L<Math::Round>

=back

=head1 AUTHORS

=over

=item Jon Warren C<jon@jonwarren.info>

=back

=head1 GIT REPOSITORY

=over

=item L<https://github.com/jonwarren/tasklogs>

=back

=cut

# vim: ts=4 sw=4 et