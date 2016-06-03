######################################################################
# tasklogs.pm - sub-routines used by the tasklogs scripts
# See end of file for user documentation.
######################################################################

package tasklogs;

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);
@EXPORT = qw(
    get_daily_script        get_weekly_script
    get_taskdir             get_timesheetsdir
    get_logfn               backup_logfn
    get_break_aliases       clear_daily_files
    fmttimearr              redotime
    rename_tasks            rename_task
    get_endofday            get_endofday_object
    get_endofweek_ymd       get_endofweek_object
    get_rounding_precision  get_printf_fmt
    get_seconds_conversion  get_minutes_conversion
    printdebug
);

use DateTime;
use DateTime::TimeZone;
use DateTime::Format::Natural;
use Lingua::EN::Titlecase;
use Math::Round qw(nearest);
use Tie::File;

my $DEBUG = 0;
my ($TENTHS, $QUARTERS, $HALVES, $WHOLE) = (0.1, 0.25, 0.5, 1);
my ($TO_MINS, $TO_HRS) = (60, 3600);
# ====================================================================
# TODO: Set these to control output.
# #====================================================================
# By default this will output values rounded to nearest quarter hour:
my $rounding_precision = $QUARTERS;
my $seconds_conversion = $TO_HRS;
my $printf_fmt         = "%5.2f";
#
# If you need output by tenth of an hour, use these values:
# my $rounding_precision = $TENTHS;
# my $seconds_conversion = $TO_HRS;
# my $printf_fmt         = "%5.1f";
#
# If you need output in minutes, rounded to nearest minute:
# my $rounding_precision = $WHOLE;
# my $seconds_conversion = $TO_MINS;
# my $printf_fmt         = "%5.0f";
# #====================================================================

# #====================================================================
# change at your own risk -- some of the code might not be forgiving
# #====================================================================
my $tasklogs_dirname   = 'tasklogs';  # main directory for all tasklogs
my $tasklog_filename   = '.hours';    # task log file, stored in $tasklogs_dirname
my $tasklogs_backupdir = 'backups';   # subdirectory of $tasklogs_dirname
# #====================================================================

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
# Get the name of the task log file
#
sub get_logfn() {
    my $taskdir = &get_taskdir();
    my $logfn = $taskdir . $tasklog_filename;
}

######################################################################
# Backup the hours log file
#
sub backup_logfn($;) {
    my $logfn = shift;
    rename $logfn, "$logfn.bak" or die "Error: $logfn.bak: $!\n";
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
# Renames all tasks in $logfn named $oldtask to $newtask
#
# TODO: update to use Tie::File
#
sub rename_tasks($$$;) {
    my ($logfn, $oldtask, $newtask) = @_;
    my $count   = 0;

    # standardize capitalization of new task for writing into file
    $newtask = Lingua::EN::Titlecase->new("$newtask")->title();

    if ( -f $logfn ) {
        open( INFILE, "<$logfn" ) or die "Error: Could not open $logfn for input: $!\n";
        open( OUTFILE, ">$logfn.tmp" ) or die "Error: Could not open $logfn.tmp for output: $!\n";
        while (<INFILE>) {
            $_ =~ s/\s+$//;
            if ( $_ =~ s/(\s+)$oldtask$/$1$newtask/i ) {
                $count++;
            }
            print OUTFILE "$_$/";
        }
        close INFILE;
        close OUTFILE;
        rename "$logfn.tmp", $logfn or die "Error: Could not rename $logfn.tmp to $logfn: $!\n";
    } else {
        die "Error: Cannot rename tasks, task log file $logfn not found\n";
    }

    if ( $count > 0 ) {
        print "Done: [$count] instance"
              . ($count>1?'s':'')
              . " of [$oldtask] "
              . ($count>1?'have':'has')
              . " been renamed to [$newtask].\n";
    } else {
        die "Error: No instances of [$oldtask] were found.\n";
    }
}

######################################################################
# Renames current task in $logfn to $newtask
#
sub rename_task($$;) {
    my ($logfn, $newtask) = @_;
    my $count   = 0;

    # standardize capitalization of new task for writing into file
    $newtask = Lingua::EN::Titlecase->new("$newtask")->title();

    if ( -f $logfn ) {
        my @logfile;
        tie( @logfile, 'Tie::File', $logfn );

        my (undef, $prevtask) = split( /\s+/, $logfile[-2], 2 );

        if ( $newtask =~ /$prevtask/i ) {
            # drop last row
            $#logfile -= 1;
            $count = -1;
        } else {
            # rename last row
            if ( $logfile[-1] =~ s/(\s+)\w.+$/$1$newtask/i ) {
                $count++;
            }
        }
    } else {
        die "Error: Cannot rename task, task log file $logfn not found\n";
    }

    if ( $count > 0 ) {
        print "Current task renamed to [$newtask].\n";
    } elsif ( $count == -1 ) {
        print "Previous task was [$newtask], continuing that entry.\n";
    } else {
        die "Error: Could not rename current task.\n";
    }
}

######################################################################
# Get a hashref to a hash containing 'fn' (end-of-day log filename)
# and 'dt' (DateTime object for day we're ending).
#
sub get_endofday($) {
    my ($task, $day) = split( /\s+/, shift, 2 );

    my %endofday = (
        fn => "",
        dt => undef,
    );

    my $dt = undef;
    if ( defined $day ) {
        $dt = &get_endofday_object( $day );
        $day = $dt->day_name();
    } else {
        die "Error: No day provided\n";
    }

    $endofday{fn} = &get_taskdir() . ".$day";
    $endofday{dt} = $dt;

    return \%endofday;
}

######################################################################
# Get a DateTime object for the day we're ending
#
sub get_endofday_object($) {
    my $day = shift;

    my $tz     = DateTime::TimeZone->new( name => "local" );
    my $parser = DateTime::Format::Natural->new( time_zone => $tz->name() );

    my $eod_dt   = $parser->parse_datetime($day);
    if ( ! $parser->success() ) {
        die "Error: Could not parse provided day [$day]: " . $parser->error() . "\n";
    }

    my $today_dt = DateTime->today( time_zone => $tz->name() );
    die "Error: Cannot end a future date\n" if ( DateTime->compare( $eod_dt, $today_dt ) > 0 );

    return $eod_dt;
}

######################################################################
# Get a YYYYMMDD formated string for the week we're ending given
# an end-of-day DateTime object.
#
sub get_endofweek_ymd($) {
    my $dt = &get_endofweek_object( shift );
    return $dt->ymd('');
}

######################################################################
# Get a DateTime object for the week we're ending given an end-of-day
# DateTime object.
#
sub get_endofweek_object($) {
    my $dt = shift;

    my $sat_offset = 6 - $dt->day_of_week();  # 6 is 'Saturday'
    $dt->add( days => $sat_offset );

    return $dt;
}

######################################################################
# Get the specified rounding precision
#
sub get_rounding_precision() {
    return $rounding_precision;
}

######################################################################
# Get the specified output printf format
#
sub get_printf_fmt() {
    return $printf_fmt;
}

######################################################################
# Get the specified seconds conversion
#
sub get_seconds_conversion() {
    return $seconds_conversion;
}

######################################################################
# Get the specified minutes conversion
#
sub get_minutes_conversion() {
    return $TO_MINS;
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

=item get_daily_script
    Get the C<daily.pl> script location

=item get_weekly_script
    Get the C<weekly.pl> script location

=item get_taskdir
    Get the name of the tasklogs directory

=item get_timesheetsdir
    Get the name of the timesheets directory

=item get_logfn
    Get the name of the task log file

=item backup_logfn
    Backup the hours log file

=item get_break_aliases
    Returns an array of 'break' aliases.
    Attempts to read a config file, if file exists uses contents,
    otherwise uses a set of standard aliases.

=item clear_daily_files
    Clear the daily log files (by deletion)

=item fmttimearr
    Format Time Array Values as 2-digit values

=item redotime
    Redo C<$time> as either hours, minutes, or seconds

=item rename_tasks
    Renames all tasks in C<$logfn> named C<$oldtask> to C<$newtask>

=item rename_task
    Renames current task in $logfn to $newtask

=item get_endofday
    Get a hashref to a hash containing 'fn' (end-of-day log filename)
    and 'dt' (DateTime object for day we're ending).

=item get_endofday_object
    Get a DateTime object for the day we're ending

=item get_endofweek_ymd
    Get a YYYYMMDD formated string for the week we're ending given
    an end-of-day DateTime object.

=item get_endofweek_object
    Get a DateTime object for the week we're ending given an end-of-day
    DateTime object.

=item get_rounding_precision
    Get the specified rounding precision

=item get_printf_fmt
    Get the specified output printf format

=item get_seconds_conversion
    Get the specified seconds conversion

=item get_minutes_conversion
    Get the specified minutes conversion

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

=item L<Tie::File>

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
