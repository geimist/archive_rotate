# archive_rotate

This script rotates archived files by user specified pattern.

### Usage: 

``./archive_rotate.sh [-c -r -v --dry-run] -p=Path [-s=searchpattern] [-h=…|-d=…|-w=…|-m=…|-y=…] ``

### Example:

``./archive_rotate.sh -crv -p="/volume1/home/MySQL_Backup/" --searchpattern="WordPress_*" --filesperhour="*x48" -d=24x7 -m="1x*" ``


- The specification for the number of files and time periods is separated 
  by an "x" [DIGITxDIGIT eg. -h=7x6 for 7 files per hour for 6 hours].
- The time periods are added together. This means that the next larger 
  period starts at the end of the previous smaller period.
- Older files outside the defined period are deleted if parameters 
  -c / --cleanig are set, otherwise the files are ignored.
- Periods and counts can also be defined as wildcards [*].
- Intervals are dynamic. For example, if 12 files are to be kept per year, 
  and all files of this period are from one day, 12 files will also be kept, 
  although they have a disproportionately small time interval.

``    -p= --path=             Path to parent directory``

Arguments for the count of kept files and count of the respective period:

```    -h= --filesperhour=     how many files per how many hours [eg. 60x24 means: 24 hours with 60 files each]
    -d= --filesperday=      how many files per how many days
    -w= --filesperweek=     how many files per how many weeks
    -m= --filespermonth=    how many files per how many month
    -y= --filesperyear=     how many files per how many years 
```


optional arguments:


```    -s= --searchpattern=    only files who match pattern are proceeded 
    -r  --recursive         also searches in subdirectories
    -v  --verbose           explain what is being done
    -c  --cleaning          delete files out of range
        --dry-run           perform a trial run with no changes made
    -h  --help              display this help and exit
```