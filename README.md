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
- ~~(done) Add configurable list (or file) of tasks to be treated same as 'break'~~
- (started, done in `task.pl`) Handle ending a day after midnight
- (started, done in `task.pl`) Update to allow changing rounding/output
- Change end-of-day files to always store raw seconds totals, to improve week-end numbers
- ~~(done) Rename end-of-week files from MMDDYY to YYMMDD~~
- Fix prompting to edit end-of-day log file
- Add option for renaming the current task: `task.pl -r "new task"` or `task.pl --rename "new task"`

***

## NAME

**`task.pl`** - time tracking tool

## SYNOPSIS

- **`task.pl`**
- **`task.pl`** _taskname_
- **`task.pl`** -_minutes_ _taskname_
- **`task.pl`** _quit_

## DESCRIPTION

**`task.pl`** without arguments says what _taskname_ it thinks
you're working on and for how long.

Use
**`task.pl`** _taskname_
when you start working on task _taskname_.
Short, repeatable _taskname_s are recommended.

If you forget to do this when you switch tasks, use
**`task.pl`** -_minutes_ _taskname_
to indicate that you started working on task _taskname_,
_minutes_ minutes ago.

**`task.pl`** _quit_
rotates its log file and prints a report,
listing total hours worked for each distinct _taskname_.

## ENVIRONMENT

**HOME** must be set to the path of the user's home directory.

## FILES

- `.hours` - The current day's running log of task start times
- `.hours.bak` - The previous day's log of task start times
- `Sunday` - The end-of-day report file for Sunday
- `Monday` - The end-of-day report file for Monday
- `Tuesday` - The end-of-day report file for Tuesday
- `Wednesday` - The end-of-day report file for Wednesday
- `Thursday` - The end-of-day report file for Thursday
- `Friday` - The end-of-day report file for Friday
- `Saturday` - The end-of-day report file for Saturday

***

## NAME

**`daily.pl`** - weekly report generator

## SYNOPSIS

- **`daily.pl`**
- **`daily.pl`** _end_

## DESCRIPTION

**`daily.pl`** without arguments displays the current daily report
This is useful for seeing how much billable time you've worked.

Use
**`daily.pl`** _end_
Process the end-of-day report, prompting for editing (if user chooses),
and (on Friday) runs the end-of-week report.

## FILES

- `.break_aliases` - Optional file containing list of task names
whose valuse are aliases for 'break' time (aka, non-billable time)
- `.hours` - The current day's running log of task start times
- `Sunday` - The end-of-day report file for Sunday
- `Monday` - The end-of-day report file for Monday
- `Tuesday` - The end-of-day report file for Tuesday
- `Wednesday` - The end-of-day report file for Wednesday
- `Thursday` - The end-of-day report file for Thursday
- `Friday` - The end-of-day report file for Friday
- `Saturday` - The end-of-day report file for Saturday

***

## NAME

**`weekly.pl`** - weekly report generator

## SYNOPSIS

- **`weekly.pl`** Processes the end-of-week report for the current week
- **`weekly.pl`** _YYMMDD_ Processes the end-of-week report for the current week using specified Saturday
- **`weekly.pl`** _-v YYMMDD_ for viewing previous weekly report
- **`weekly.pl`** _clear_ Removes any existing end-of-day report files

## FILES

- `weeklogs/YYMMDD.log` - The end-of-week report for Saturday indicated by YYMMDD
- `Sunday` - The end-of-day report file for Sunday
- `Monday` - The end-of-day report file for Monday
- `Tuesday` - The end-of-day report file for Tuesday
- `Wednesday` - The end-of-day report file for Wednesday
- `Thursday` - The end-of-day report file for Thursday
- `Friday` - The end-of-day report file for Friday
- `Saturday` - The end-of-day report file for Saturday

***

## NAME

**`.break_aliases`** - aliases file for task name synonyms for 'break' (non-billable time)

## DESCRIPTION

Optional file containing a list of task names, one-per-line,
of task names to use that will be treated as breaks.

If file does not exist, these task names will be used for non-billable time:
'Break', 'Lunch', 'Sick', 'Vacation', 'Holiday'.

If file exists, but is empty, no task names will be used for non-billable time.

## FILES

- `.break_aliases` - Optional file containing list of task names

