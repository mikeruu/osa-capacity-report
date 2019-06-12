#!/bin/bash -x
#
# Script Name: capacity-report-sql.sh
#
# Author: Miguel Parada
# Date : Feb 2019
#
# Description: The following script will calculate the RAM,CPU and DISK utilization from
#              all of the compute nodes and output in comma separated values to std out.
#              For efficiency it will query the MYSQL database directly as opposed to using the nova api
#
#
#

source /root/openrc

#Set the allocation ratios configured in the nova scheduler.
CPU_ALLOCATION_RATIO=3
DISK_ALLOCATION_RATIO=1
RAM_ALLOCATION_RATIO=2


#Get the list of compute node names
TOTAL_COMPUTES=$(lxc-attach -n $(lxc-ls -1 | grep utility) -- nova service-list | grep nova-compute | awk '{print $6}')
COMPUTE_UP=$(lxc-attach -n $(lxc-ls -1 | grep utility) -- nova service-list | grep nova-compute | grep enabled | grep up | awk '{print $6}')
COMPUTE_DOWN=$(lxc-attach -n $(lxc-ls -1 | grep utility) -- nova service-list | grep nova-compute | grep -E 'disabled|down' | awk '{print $6}')

#Attach to galera and execute mysql query for reusability
GALERA_COMM="lxc-attach -n $(lxc-ls -1 | grep galera | head -n 1) -- mysql -se"

#Get todays date
DATE=$(date +%Y-%m-%d%n)

#main function
function get_capacity_report(){

  #Get the count of all VMs
  TOTAL_VMS=$(lxc-attach -n $(lxc-ls -1 | grep utility) -- openstack server list --all-projects | grep -vE '\+|Status' | awk '{print $2}' | wc -l)

  #Get the count of compute nodes depending on their state
  TOTAL_COMPUTES_SUM=$(echo $TOTAL_COMPUTES | wc -w)
  ENABLED_COMPUTES_SUM=$(echo $COMPUTE_UP | wc -w)
  DISABLED_COMPUTES_SUM=$(echo $COMPUTE_DOWN | wc -w)

  #Escape the host name in case it has a hyphen for mysql query compatibility
  ENABLED_COMPUTES=$(for host in $COMPUTE_UP; do echo $host |  sed 's/-/\\-/'; done)
  #Join computes by commas for mysql query and add quotes to every hostname
  ENABLED_COMPUTES=$(echo $ENABLED_COMPUTES | sed 's/ /,/g' | sed 's/,/\",\"/g' | sed 's/^\|$/"/g')


  #Escape the host name in case it has a hyphen for mysql query compatibility
  TOTAL_COMPUTES_SQL=$(for host in $TOTAL_COMPUTES; do echo $host |  sed 's/-/\\-/'; done)
  #Join computes by commas for mysql query and add quotes to every hostname
  TOTAL_COMPUTES_SQL=$(echo $TOTAL_COMPUTES_SQL | sed 's/ /,/g' | sed 's/,/\",\"/g' | sed 's/^\|$/"/g')


  #Check if any disabled computes exist to avoid running queries on empty strings
  if [[ "$COMPUTE_DOWN" ]]; then
    #Escape the host name in case it has a hyphen for mysql query compatibility
    DISABLED_COMPUTES=$(for host in $COMPUTE_DOWN; do echo $host |  sed 's/-/\\-/'; done)
    #Join computes by commas for mysql query
    DISABLED_COMPUTES=$(echo $DISABLED_COMPUTES | sed 's/ /,/g' | sed 's/,/\",\"/g' | sed 's/^\|$/"/g')


    #Get the sum of resources of disabled computes
    DISABLED_SUMS=$( $GALERA_COMM "SELECT sum(memory_mb), sum(vcpus) , sum(local_gb) from(SELECT * FROM nova.compute_nodes WHERE host in (${DISABLED_COMPUTES}) group by host) as t;" )
    DISABLED_RAM=$( echo $DISABLED_SUMS | cut -d " " -f 1)
    DISABLED_CPU=$( echo $DISABLED_SUMS | cut -d " " -f 2)
    DISABLED_DISK=$( echo $DISABLED_SUMS | cut -d " " -f 3)

  fi


  #Get total sum of available resources
  TOTALS=$(lxc-attach -n $(lxc-ls -1 | grep galera | head -n 1) -- mysql -se "select sum(memory_mb), sum(vcpus) , sum(local_gb)from (SELECT * FROM nova.compute_nodes WHERE host in (${TOTAL_COMPUTES_SQL}) AND (host is NOT NULL AND deleted_at is NULL) group by host) as t;")

  #Assign each to its variable to use in output later
  TOTAL_RAM=$( echo $TOTALS | cut -d " " -f 1)
  TOTAL_CPU=$( echo $TOTALS | cut -d " " -f 2)
  TOTAL_DISK=$( echo $TOTALS | cut -d " " -f 3)

  #Get the sum of resources of enabled computes
  ENABLED_SUMS=$( $GALERA_COMM "SELECT sum(memory_mb), sum(vcpus) , sum(local_gb), sum(memory_mb_used), sum(vcpus_used), sum(local_gb_used) from (SELECT * FROM nova.compute_nodes WHERE host in (${ENABLED_COMPUTES}) group by host) as t;" )
  
  
  ENABLED_RAM=$( echo $ENABLED_SUMS | cut -d " " -f 1)
  ENABLED_CPU=$( echo $ENABLED_SUMS | cut -d " " -f 2)
  ENABLED_DISK=$( echo $ENABLED_SUMS | cut -d " " -f 3)

  USED_RAM=$( echo $ENABLED_SUMS | cut -d " " -f 4)
  ALLOCATED_CPU=$( echo $ENABLED_SUMS | cut -d " " -f 5 )
  USED_DISK=$( echo $ENABLED_SUMS | cut -d " " -f 6 )

  MEM_PERC=$(echo $USED_RAM $TOTAL_RAM $RAM_ALLOCATION_RATIO | awk '{ perc = $1 / ($2 * $3) ; print perc }' )
  MEM_ADJ_PERC=$(echo $USED_RAM $ENABLED_RAM $RAM_ALLOCATION_RATIO | awk '{ perc = $1 / ($2 * $3) ; print perc}' )

  CPU_PERC=$(echo $ALLOCATED_CPU $TOTAL_CPU $CPU_ALLOCATION_RATIO | awk '{ perc = $1 / ($2 * $3) ; print perc}')
  CPU_ADJ_PERC=$(echo $ALLOCATED_CPU $ENABLED_CPU $CPU_ALLOCATION_RATIO | awk '{ perc = $1 / ($2 * $3) ; print perc}')
  
  DISK_PERC=$(echo $USED_DISK $TOTAL_DISK $DISK_ALLOCATION_RATIO | awk '{ perc = $1 / ($2 * $3) ; print perc}')
  DISK_ADJ_PERC=$(echo $USED_DISK $ENABLED_DISK $DISK_ALLOCATION_RATIO | awk '{ perc = $1 / ($2 * $3) ; print perc}')

echo "$DATE;$TOTAL_COMPUTES_SUM;$ENABLED_COMPUTES_SUM;$DISABLED_COMPUTES_SUM;$TOTAL_VMS;$TOTAL_RAM;$DISABLED_RAM;$ENABLED_RAM;$USED_RAM;$TOTAL_CPU;$DISABLED_CPU;$ENABLED_CPU;$ALLOCATED_CPU;$TOTAL_DISK;$DISABLED_DISK;$ENABLED_DISK;$USED_DISK;$MEM_PERC;$MEM_ADJ_PERC;$CPU_PERC;$CPU_ADJ_PERC;$DISK_PERC;$DISK_ADJ_PERC"
}

get_capacity_report