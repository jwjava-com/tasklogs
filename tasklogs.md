# NAME

`tasklogs.pm` - sub-routines used by the tasklogs scripts

# DESCRIPTION

This module contains supporting methods for the tasklogs scripts.

# METHODS

- get\_taskdir
    Get the name of the tasklogs directory
- get\_timesheetsdir
    Get the name of the timesheets directory
- get\_daily\_script
    Get the `daily.pl` script location
- get\_weekly\_script
    Get the `weekly.pl` script location
- get\_endofday\_filename
    Get the name of the end-of-day log file
- backup\_logfn
    Backup the hours log file
- rename\_task
    Renames all tasks in `$logfn` named `$oldtask` to `$newtask`
- get\_logfn
    Get the name of the task log file
- fmttimearr
    Format Time Array Values as 2-digit values
- get\_break\_aliases
    Returns an array of 'break' aliases.
    Attempts to read a config file, if file exists uses contents,
    otherwise uses a set of standard aliases.
- redotime
    Redo `$time` as either hours, minutes, or seconds
- clear\_daily\_files
    Clear the daily log files (by deletion)
- printdebug
    Prints the debug string to the `DEBUG` filehandle if:
    `$DEBUG` is true (positive non-zero number)
    `$lev` is at or below `$DEBUG`

# ENVIRONMENT VARIABLES 

Environment variables are used for determining which OS path separator to use.

- HOME
    if _HOME_ is found, assume unix-like environment
- HOMEDRIVE, HOMEPATH
    if _HOMEDRIVE_ and _HOMEPATH_ are both found, assume Windows

# FILES

- .hours
    task log for the current day
- .hours.bak
    task log for the previous day
- .`day-of-week`
    end of day report for the indicated _day-of-week_ (e.g., `.Monday`, or `mon`)
- timesheets/`YYMMDD.log`
    timesheet for week ending _YYMMDD_
- .break\_aliases
    optional config file, defines _task names_ treated as aliases to _break_

# REQUIRED MODULES

- [DateTime](https://metacpan.org/pod/DateTime)
- [DateTime::TimeZone](https://metacpan.org/pod/DateTime::TimeZone)
- [DateTime::Format::Natural](https://metacpan.org/pod/DateTime::Format::Natural)
- [Lingua::EN::Titlecase](https://metacpan.org/pod/Lingua::EN::Titlecase)
- [Math::Round](https://metacpan.org/pod/Math::Round)

# AUTHORS

- Jon Warren `jon@jonwarren.info`

# GIT REPOSITORY

- [https://github.com/jonwarren/tasklogs](https://github.com/jonwarren/tasklogs)
