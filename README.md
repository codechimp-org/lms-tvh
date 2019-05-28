# lms-tvh
lms-tvh is a plugin for Logitech Media Server to allow integration with TVHeadend to play live radio streams from TVHeadend.

![alt text](https://github.com/andrew-codechimp/lms-tvh/raw/master/lms-tvh-systemdiagram.png "System Diagram")


## TVHeadend Configuration
To stream audio to Logitech Media Server a specific audio profile must be created and set as the default for a user account that this plugin will connect with.

First setup a new profile

Create a new user specifically for this plugin.

## Plugin Installation
Go to the Logitech Media Server Settings page. On the Plugins tab insert the repository URL for this plugin at the bottom of the page.

https://tvh.codechimp.org/repo.xml

Save and restart the Logitech Media Server. 

## Logitech Media Server Configuration & Use
On the Logitech Media Server Settings page/Advanced tab choose TVH in the top left drop down.

Provide your TVHeadend server details and save.

Within the Logitech Media Server home page you will now have TVH under AddOns where you can browse your TV Headend Tags/Stations.
Stream and enjoy :)

## Disclaimer
No support/warranty is offered on this plugin, help is provided on a best efforts basis.

## Contributing
If you find something wrong then pull requests are welcome, or raise an issue.  Any error logs would be helpful to diagnosing issues.

Neither andrew-codechimp or dozigden are experienced perl programmers so it may take us some time to work out fixes.

## Acknowledgements
Inspired by plugins created by @michaelherger

Initial idea for a plugin came from a post by netmax on how to stream a TVHeadend channel  
https://forums.slimdevices.com/showthread.php?108276-HowTo-Get-radio-streams-from-TVHeadend-server
