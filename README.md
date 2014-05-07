OSX-Server-Backup
=================

a CLI tool with GUI interface for backing up OS X Server

The GUI handles backing and basic scheduling for OSX Server.app settings and data,
such as settings generated from running serveradmin, all of the Postgres DB's managed
by server, Open Directory, RADIUS, Named etc...

You can use the GUI tool to handle most things, or if you prefer
you can just install the just install "osxsbak" CLI tool by running
/path/to/OSX Server Backup.app/Contents/MacOS/osxsbak --install
which installs the osxsbak into /usr/local/sbin/

from there you can run 
```/usr/local/sbin/osxsbak -h``` 
to see a full usage

to completely remove OSX Server Backup.app you will want to remove these files
eventually an uninstall method will be included in the GUI, but for now
you'll have to do this manually.
```
/Library/PrivilegedHelperTools/com.eeaapps.osxsbak.helper
/Library/LaunchDaemons/com.eeaapps.osxsbak.helper.plist
/Library/LaunchDaemons/com.eeaapps.osxsbak.run.weekly.plist
/Library/LaunchDaemons/com.eeaapps.osxsbak.run.daily.plist
```


this is extremely early in development, and currently only have implemented
features for the things I currently use on server, but plan on fleshing out
the reset as time allows.  Anyone interested in contributing should
send me pull requests, they would be welcome.  

