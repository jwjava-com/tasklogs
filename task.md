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

# FILES

- .hours
    task log for the current day
- .hours.bak
    task log for the previous day
- .`day-of-week`
    end of day report for the indicated _day-of-week_ (e.g., `.Monday`, or `mon`)

# REQUIRED SCRIPTS

- daily.pl
    execution is passed to `daily.pl` during end-of-day processing

# REQUIRED MODULES

- `tasklogs`
- [Lingua::EN::Titlecase](https://metacpan.org/pod/Lingua::EN::Titlecase)
- [Math::Round](https://metacpan.org/pod/Math::Round)

# AUTHORS

- Jon Warren `jon@jonwarren.info`

# GIT REPOSITORY

- [https://github.com/jonwarren/tasklogs](https://github.com/jonwarren/tasklogs)
