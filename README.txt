# EbsSnapshot

Take EBS Snapshots.  Ability to freeze LVM or XFS filesystems and write
lock MySQL databases during snapshot.

For pruning the snapshots to reduce storage costs on S3, take a look at
ebs_prune_snapshot (https://github.com/dusty/ebs_prune_snapshot).

## Installation

Add this line to your application's Gemfile:

    gem 'ebs_snapshot'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ebs_snapshot

For MySQL Support, add mysql2 to your Gemfile:

    gem 'ebs_snaphost'
    gem 'mysql2'

Or install it yourself as:

    $ gem install mysql2

## Usage

AWS Access Key and AWS Secret Access Key are required.  These options can be
provided through the command line or they may be stored in the environmental
variables of AMAZON_ACCESS_KEY_ID and AMAZON_SECRET_ACCESS_KEY.  Any options
provided through the command line will override the environmental variables.

If you wish to Freeze the filesystem, pass in the fileystem type (-f),
otherwise it will be skipped.

You may pass in a custom hostname used in the description of the
snapshot with (-H), otherwise the system hostname will be used.

For MySQL snapshots, the tables will be locked and the master status
will be recorded.  This information will be included in your snapshot
description. (testhost:/mnt/ebs (mysqld-bin.000001, 106).  If binary
logging is disabled, this will show (empty, empty).

Usage: ebs_snapshot [options]
   eg: ebs_snapshot -i vol-XXXXXX -m /dev/ebs/ebsvol -f lvm -d mysql -u root
   eg: ebs_snapshot -i vol-YYYYYY -m /mnt/ebsvol -f xfs -H mycustomhost

Required volume arguments
    -m, --path PATH                  Path to lvm device or mount point (/mnt/ebsvol)
    -i, --volume VOLUME              ID of EBS Volume (vol-XXXXXX)
    -f, --filesystem FILESYSTEM      Type of filesystem to freeze/suspend (xfs|lvm)

Informational arguments, used in the snapshot description
    -H, --hostname HOSTNAME          Hostname of the machine with the volume

AWS Identifications, required unless environmental variables set
    -k, --key KEY                    AWS Access Key (AMAZON_ACCESS_KEY_ID)
    -s, --secret SECRET              AWS Secret Access Key (AMAZON_SECRET_ACCESS_KEY)

Database information, required if snapshoting a mysql database volume
    -d, --database DATABASE          Database type (mysql)
    -u, --username USERNAME          Database username
    -p, --password PASSWORD          Database password
    -t, --host HOST                  Database host
    -P, --port PORT                  Database port
    -h, --help                       Show Command Help

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
