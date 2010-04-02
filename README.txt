EbsSnapshot

  Make snapshots of XFS file systems to EBS
 
 
Installation

  gem install ebs_snapshot-x.x.x.gem

Configuration

  ##
  # /etc/ebs_snapshot.yml

  ##
  # aws authentication
  #
  # hostname you want to display in snapshot description
  aws:
    access_key: xxxxxxxxxxxxxx
    secret_key: xxxxxxxxxxxxxx
    hostname: myhostname

  ##
  # mysql authentication information
  mysql:
    user: myuser
    password: mypassword

  ##
  # Snapshots
  #
  # set db to mysql if a mysql database volume
  #
  # set fs to xfs or lvm filesystem for freezing
  #
  # set path to mount point for xfs
  # set path to lvm mapper for lvm
  snapshots:
    vol-xxxxxxx:
      path: /mnt/dbvolume
      fs: xfs
      db: mysql
    vol-yyyyyyy:
      path: /dev/mapper/ebs-othervolume
      fs: lvm

  
Usage

  ebs_snapshot
  
