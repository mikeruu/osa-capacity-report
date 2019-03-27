# osa-capacity-report
Script to get Openstack capacity report

This script will query the openstack nova MySQL database to generate a CSV with RAM,CPU and DISK utilization.

It's meant to be run from the controller node that has the nova MySQL database running in an lxc container.

Installation
____________

No installation is needed other than having to copy the scrip to the controller node.
Before running make sure to set the appropriate allocation ratios in the script to get the correct usage percentages.

.. code-block:: bash

    CPU_ALLOCATION_RATIO=4
    DISK_ALLOCATION_RATIO=1
    RAM_ALLOCATION_RATIO=1.5

The script will send to std out the CSV values that can be copied into the DATA page in the spreadsheet
The spreadsheet should auto update reading the last row from the DATA page.


Usage
_____

.. code-block:: bash

    $ bash capacity-report-sql.sh
    
The CSV output headers are:
DATE;TOTAL COMPUTES;ENABLED COMPUTES;DISABLED COMPUTES;TOTAL VMS;TOTAL RAM;DISABLED RAM;ENABLED RAM;USED RAM;TOTAL CPU;DISABLED CPU;ENABLED CPU;ALLOCATED CPU;TOTAL DISK;DISABLED DISK;ENABLED DISK;USED DISK;MEMORY_PERC;MEMORY_ADJ_PERC;CPU_PERC;CPU_ADJ_PERC;DISK_PERC;DISK_ADJ_PERC
    
Examples
________

.. code-block:: bash

    $ bash capacity-report-sql.sh
    2019-03-27;23;23;0;1237;35602781;;35602781;5906299;1656;;1656;2751;98969;;98969;35761;0.165894;0.165894;0.166123;0.166123;0.361335;0.361335
    
