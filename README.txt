EbsSnapshot

  Make snapshots of XFS file systems to EBS
 
 
Installation

  gem install ebs_snapshot-x.x.x.gem

Configuration

  # /etc/ebs_snapshot.yml  
  # make db true if this is a database volume
  global:
    ec2_access_key: xxxxxxxxxxxxxx
    ec2_secret_key: xxxxxxxxxxxxxx
    hostname: myhostname
    db_user: user
    db_pass: password

  snapshots:
    - path: /mnt/dbvolume
      volume: vol-xxxxxxx
      db: true
    - path: /mnt/othervolume
      volume: vol-xxxxxxx
  
Usage

  ebs_snapshot
  
