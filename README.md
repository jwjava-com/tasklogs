# tasklogs

A set of scripts written over a decade ago to help create weekly timesheets.
They were tweaked here-and-there during brief periods of down-time for a few years.
They still appear to work.  Putting here as they might be useful to someone.

Looking at these again, after several years, there's several things that could have
been done differently.  Handling of paths, for instance, and extracting some code
to a PM would be good.  I've updated a few times to try to migrate from running in
a Windows Command Prompt environment, using Active Perl, to run in a bash shell in
either Cygwin or Linux.

## TODOS

- ~~(done) `weekly.pl`: Auto-calculate Saturday date if none specified~~
- Extract common code to a module
- Add better handling of incorrect command-line parameters
- Expand documentation
- Port to other languages (spoken & programming)
- (started) Auto-create necessary paths & allow specifying different paths
- ~~(done) Handle spaces inside quoted task names~~
- Allow changing back to the previous (or previous X) task (ala bash !! or !-n)
- Allow resuming a day after a previous 'quit'
- Add configurable list (or file) of tasks to be treated same as 'break'
- (started, done in `task.pl`) Handle ending a day after midnight
- (started, done in `task.pl`) Update to allow changing rounding/output
- Change end-of-day files to always store raw seconds totals, to improve week-end numbers
- ~~(done) Rename end-of-week files from MMDDYY to YYMMDD~~
- Fix prompting to edit end-of-day log file
- Add option for renaming the current task: `task.pl -r "new task"` or `task.pl --rename "new task"`

## NAME

**task** - time tracking tool

## SYNOPSIS

- **task**
- **task** _taskname_
- **task** -_minutes_ _taskname_
- **task** _quit_

## DESCRIPTION

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

**task** _quit_
rotates its log file and prints a report,
listing total hours worked for each distinct _taskname_.

## ENVIRONMENT

**HOME** must be set to the path of the user's home directory.

## FILES

- `$HOME/.hours`
- `$HOME/.hours.bak`

***

## NAME

**weekly** - weekly report generator

## SYNOPSIS

- **weekly**
- **weekly** MMDDYY Where is Saturday week ending date
- **weekly** -v for viewing previous weekly report
- **weekly clear**

