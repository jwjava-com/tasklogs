# NAME

`task.pl` - time tracking tool

# DESCRIPTION

This program allows tracking start times of various tasks for timesheets.

# SYNOPSIS

- task.pl
    display current task
- task.pl `taskname`
    start new task named _taskname_
- task.pl `-minutes` `taskname`
    start new task _minutes_ ago named _taskname_
- task.pl `+minutes` `taskname`
    start new task _minutes_ from now named _taskname_
- task.pl `quit` `day-of-week`
    do end-of-day processing for _day-of-week_

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
    end of day report for the indicated _day-of-week_ (e.g., `.Monday`)

# REQUIRED SCRIPTS

- daily.pl
    execution is passed to `daily.pl` during end-of-day processing

# REQUIRED MODULES

- [Math::Round](https://metacpan.org/pod/Math::Round)
- [Lingua::EN::Titlecase](https://metacpan.org/pod/Lingua::EN::Titlecase)
- [DateTime](https://metacpan.org/pod/DateTime)
- [DateTime::TimeZone](https://metacpan.org/pod/DateTime::TimeZone)
- [DateTime::Format::Natural](https://metacpan.org/pod/DateTime::Format::Natural)

# AUTHORS

- Jon Warren `jon@jonwarren.info`

# GIT REPOSITORY

- [https://github.com/jonwarren/tasklogs](https://github.com/jonwarren/tasklogs)
