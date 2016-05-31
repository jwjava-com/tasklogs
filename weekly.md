# NAME

`weekly.pl` - weekly timesheet generator

# DESCRIPTION

This program generates a weekly timesheet.

# SYNOPSIS

- weekly.pl `-c YYMMDD`
    create new weekly timesheet for week ending _YYMMDD_
- weekly.pl `-u YYMMDD`
    update existing weekly timesheet for week ending _YYMMDD_
- weekly.pl `-r YYMMDD`
    display existing weekly timesheet for week ending _YYMMDD_
- weekly.pl `--delete`
    delete daily log files

# ENVIRONMENT VARIABLES 

Environment variables are used for determining which OS path separator to use.

- HOME
    if _HOME_ is found, assume unix-like environment
- HOMEDRIVE, HOMEPATH
    if _HOMEDRIVE_ and _HOMEPATH_ are both found, assume Windows

# FILES

- timesheets/`YYMMDD.log`
    timesheet for week ending _YYMMDD_
- .`day-of-week`
    end of day report for the indicated _day-of-week_ (e.g., `.Monday`, or `mon`)
- .break\_aliases
    optional config file, defines _task names_ treated as aliases to _break_

# REQUIRED MODULES

- [tasklogs.md](tasklogs.md)

# AUTHORS

- Jon Warren `jon@jonwarren.info`

# GIT REPOSITORY

- [https://github.com/jonwarren/tasklogs](https://github.com/jonwarren/tasklogs)
