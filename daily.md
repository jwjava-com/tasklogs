# NAME

`daily.pl` - daily report generator

# DESCRIPTION

This program generates a daily report of time worked vs breaks taken.

# SYNOPSIS

- daily.pl
    display current daily report snapshot
- daily.pl `end`
    create the end-of-day report

# ENVIRONMENT VARIABLES 

Environment variables are used for determining which OS path separator to use.

- HOME
    if _HOME_ is found, assume unix-like environment
- HOMEDRIVE, HOMEPATH
    if _HOMEDRIVE_ and _HOMEPATH_ are both found, assume Windows

# FILES

- .hours
    task log for the current day
- .`day-of-week`
    end of day report for the indicated _day-of-week_ (e.g., `.Monday`)
- .break\_aliases
    optional config file, defines _task names_ treated as aliases to _break_

# REQUIRED SCRIPTS

- weekly.pl
    execution is passed to `weekly.pl` during end-of-day processing
    if day-of-week is Friday, Saturday, or Sunday

# REQUIRED MODULES

- [Lingua::EN::Titlecase](https://metacpan.org/pod/Lingua::EN::Titlecase)

# AUTHORS

- Jon Warren `jon@jonwarren.info`

# GIT REPOSITORY

- [https://github.com/jonwarren/tasklogs](https://github.com/jonwarren/tasklogs)
