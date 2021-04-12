# lms-tvh
lms-tvh is a plugin for Logitech Media Server to allow playing of live radio streams from TVHeadend.

![alt text](https://github.com/codechimp-org/lms-tvh/raw/master/resources/lms-tvh-systemdiagram.png "System Diagram")

## Configuration
### TVHeadend Configuration
To stream audio to Logitech Media Server a specific audio profile must be created.

* Within TVHeadend go to the Configuration Tab/Stream/Stream Profiles
* Ensure your View level is set to Expert, otherwise you will not see all options
* Add a Stream Profile
* Choose Type - Transcode/av-lib
* Name your profile squeeze (case sensitive, you will enter this later into the TVH plugin settings on Logitech Media Server)
* Container: Raw Audio Stream
* Audio Codec: aac (depending on your TVHeadend installation you may have to experiment with other codec's)
* Press Create to save your new profile

Optionally, if using TVHeadend security create a new user specifically for this plugin and set the default profile to be the one you just created above.

Ensure that the "Use HTTP digest authentication" option within Configuration/General/Base is checked. Unchecking this is known to cause issues when calling the API.

### Plugin Installation
Go to the Logitech Media Server Settings page. On the Plugins tab, under 3rd Party Plugins enable TVH.

Press Apply and restart the Logitech Media Server. 

### Logitech Media Server Configuration & Use
On the Logitech Media Server Settings page/Advanced tab choose TVH in the top left drop down.

Provide your TVHeadend server details, username and password if using security and the profile name if not the default profile for the user or you are not using security.  
Save your settings

Within the Logitech Media Server home page you will now have TVH under My Apps where you can browse your TVHeadend Tags/Stations.  
Stream and enjoy :)

## Disclaimer
No support/warranty is offered on this plugin, help is provided on a best efforts basis.

## Releasing
The version property in the publish.properties file should be incremented if a functional release.  
After checkin the GitHub Package Action should be run manually to create the new zip, update the repo.xml and create a new tag/release based on the version & run number. 

## Contributing
If you find something wrong then pull requests are welcome, or raise an issue. Any error logs would be helpful to diagnosing issues.

Neither andrew-codechimp or dozigden are experienced perl programmers so it may take us some time to work out fixes.

[Discussion forum thread](https://forums.slimdevices.com/showthread.php?110619-ANNOUNCE-TVH-Plugin-TVHeadend-integration)

## Acknowledgements
Inspired by plugins created by @michaelherger

Initial idea for this plugin came from a [post by netmax](https://forums.slimdevices.com/showthread.php?108276-HowTo-Get-radio-streams-from-TVHeadend-server)
 on how to stream a TVHeadend channel
