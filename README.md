A set of scripts written over a decade ago to help create weekly timesheets.
They were tweaked here-and-there during brief periods of down-time for a few years.
Their current state is... unknown.  Putting here as they might be useful to someone.

# NAME

**task** - time tracking tool

# SYNOPSIS

- **task**
- **task** _taskname_
- **task** -_minutes_ _taskname_
- **task quit**

# DESCRIPTION

**task** without arguments says what _taskname_ it thinks
you're working on and for how long.

Use
**task** _taskname_
when you start working on task _taskname_.
Short, repeatable _taskname_s are recommended.

If you forget to do this when you switch tasks, use
**task** -_minutes_ _taskname_
to indicate that you started working on task _taskname_,
_minutes_ minutes ago.

**task quit**
rotates its log file and prints a report,
listing total hours worked for each distinct _taskname_.

# ENVIRONMENT

**HOME** must be set to the path of the user's home directory.

# FILES

- `$HOME/.hours`
- `$HOME/.hours.bak`

***

# NAME

**weekly** - weekly report generator

# SYNOPSIS

- **weekly**
- **weekly** MMDDYY Where is Saturday week ending date
- **weekly** -v for viewing previous weekly report
- **weekly clear**

