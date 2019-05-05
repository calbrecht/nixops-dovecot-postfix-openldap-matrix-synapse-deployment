{ config, lib, pkgs, ... }:
let
  fqdn = config.networking.hostName;
  opt = (import (./. + "/options/${fqdn}.nix") { fqdn = fqdn; }) // {
    matterbridge = {
      irc-user = "calbrecht";
      irc-pass = "IRC_PASS_CHANGEME";
      matrix-user = "matterbridge";
      matrix-pass = "MATRIX_PASS_CHANGEME";
    };
  };
  template = ''
    #This is configuration for matterbridge.
    #WARNING: as this file contains credentials, be sure to set correct file permissions
    ###################################################################
    #IRC section
    ###################################################################
    #REQUIRED to start IRC section
    [irc]
    
    #You can configure multiple servers "[irc.name]" or "[irc.name2]"
    #In this example we use [irc.freenode]
    #REQUIRED
    [irc.freenode]
    #irc server to connect to. 
    #REQUIRED
    Server="irc.freenode.net:6697"
    
    #Password for irc server (if necessary)
    #OPTIONAL (default "")
    Password=""
    
    #Enable to use TLS connection to your irc server. 
    #OPTIONAL (default false)
    UseTLS=true
    
    #Enable SASL (PLAIN) authentication. (freenode requires this from eg AWS hosts)
    #It uses NickServNick and NickServPassword as login and password
    #OPTIONAL (default false)
    UseSASL=true
    
    #Enable to not verify the certificate on your irc server. i
    #e.g. when using selfsigned certificates
    #OPTIONAL (default false)
    #SkipTLSVerify=true
    
    #If you know your charset, you can specify it manually. 
    #Otherwise it tries to detect this automatically. Select one below
    # "iso-8859-2:1987", "iso-8859-9:1989", "866", "latin9", "iso-8859-10:1992", "iso-ir-109", "hebrew", 
    # "cp932", "iso-8859-15", "cp437", "utf-16be", "iso-8859-3:1988", "windows-1251", "utf16", "latin6", 
    # "latin3", "iso-8859-1:1987", "iso-8859-9", "utf-16le", "big5", "cp819", "asmo-708", "utf-8", 
    # "ibm437", "iso-ir-157", "iso-ir-144", "latin4", "850", "iso-8859-5", "iso-8859-5:1988", "l3", 
    # "windows-31j", "utf8", "iso-8859-3", "437", "greek", "iso-8859-8", "l6", "l9-iso-8859-15", 
    # "iso-8859-2", "latin2", "iso-ir-100", "iso-8859-6", "arabic", "iso-ir-148", "us-ascii", "x-sjis", 
    # "utf16be", "iso-8859-8:1988", "utf16le", "l4", "utf-16", "iso-ir-138", "iso-8859-7", "iso-8859-7:1987", 
    # "windows-1252", "l2", "koi8-r", "iso8859-1", "latin1", "ecma-114", "iso-ir-110", "elot-928", 
    # "iso-ir-126", "iso-8859-1", "iso-ir-127", "cp850", "cyrillic", "greek8", "windows-1250", "iso-latin-1", 
    # "l5", "ibm866", "cp866", "ms-kanji", "ibm850", "ecma-118", "iso-ir-101", "ibm819", "l1", "iso-8859-6:1987", 
    # "latin5", "ascii", "sjis", "iso-8859-10", "iso-8859-4", "iso-8859-4:1988", "shift-jis
    # The select charset will be converted to utf-8 when sent to other bridges.
    #OPTIONAL (default "")
    #Charset=""
    
    #Your nick on irc. 
    #REQUIRED
    Nick="${opt.matterbridge.irc-user}[mb]"
    
    #If you registered your bot with a service like Nickserv on freenode. 
    #Also being used when UseSASL=true
    #
    #Note: if you want do to quakenet auth, set NickServNick="Q@CServe.quakenet.org"
    #OPTIONAL
    NickServNick="${opt.matterbridge.irc-user}"
    NickServPassword="${opt.matterbridge.irc-pass}"
    
    #OPTIONAL only used for quakenet auth
    #NickServUsername="username"
    
    ## RELOADABLE SETTINGS
    ## Settings below can be reloaded by editing the file
    
    #Flood control
    #Delay in milliseconds between each message send to the IRC server
    #OPTIONAL (default 1300)
    MessageDelay=1300
    
    #Maximum amount of messages to hold in queue. If queue is full 
    #messages will be dropped. 
    #<message clipped> will be add to the message that fills the queue.
    #OPTIONAL (default 30)
    MessageQueue=30
    
    #Maximum length of message sent to irc server. If it exceeds
    #<message clipped> will be add to the message.
    #OPTIONAL (default 400)
    MessageLength=400
    
    #Split messages on MessageLength instead of showing the <message clipped>
    #WARNING: this could lead to flooding
    #OPTIONAL (default false)
    MessageSplit=false
    
    #Delay in seconds to rejoin a channel when kicked
    #OPTIONAL (default 0)
    RejoinDelay=0
    
    #ColorNicks will show each nickname in a different color.
    #Only works in IRC right now.
    ColorNicks=false
    
    #RunCommands allows you to send RAW irc commands after connection
    #Array of strings
    #OPTIONAL (default empty)
    #RunCommands=["PRIVMSG user hello","PRIVMSG chanserv something"]
    
    #Nicks you want to ignore. 
    #Regular expressions supported
    #Messages from those users will not be sent to other bridges.
    #OPTIONAL
    #IgnoreNicks="ircspammer1 ircspammer2"
    
    #Messages you want to ignore. 
    #Messages matching these regexp will be ignored and not sent to other bridges
    #See https://regex-golang.appspot.com/assets/html/index.html for more regex info
    #OPTIONAL (example below ignores messages starting with ~~ or messages containing badword
    IgnoreMessages="^~~ badword"
    
    #messages you want to replace.
    #it replaces outgoing messages from the bridge.
    #so you need to place it by the sending bridge definition.
    #regular expressions supported
    #some examples:
    #this replaces cat => dog and sleep => awake
    #replacemessages=[ ["cat","dog"], ["sleep","awake"] ]
    #this replaces every number with number.  123 => numbernumbernumber
    #replacemessages=[ ["[0-9]","number"] ]
    #optional (default empty)
    #ReplaceMessages=[ ["cat","dog"] ]
    
    #nicks you want to replace.
    #see replacemessages for syntaxa
    #optional (default empty)
    #ReplaceNicks=[ ["user--","user"] ]
    
    #Extractnicks is used to for example rewrite messages from other relaybots
    #See https://github.com/42wim/matterbridge/issues/713 and https://github.com/42wim/matterbridge/issues/466
    #some examples:
    #this replaces a message like "Relaybot: <relayeduser> something interesting" to "relayeduser: something interesting"
    #ExtractNicks=[ [ "Relaybot", "<(.*?)>\\s+" ] ]
    #you can use multiple entries for multiplebots
    #this also replaces a message like "otherbot: (relayeduser) something else" to "relayeduser: something else"
    #ExtractNicks=[ [ "Relaybot", "<(.*?)>\\s+" ],[ "otherbot","\\((.*?)\\)\\s+" ]
    #OPTIONAL (default empty)
    #ExtractNicks=[ ["otherbot","<(.*?)>\\s+" ] ]
    
    #extra label that can be used in the RemoteNickFormat
    #optional (default empty)
    #Label=""
    
    #RemoteNickFormat defines how remote users appear on this bridge 
    #See [general] config section for default options
    #The string "{NOPINGNICK}" (case sensitive) will be replaced by the actual nick / username, but with a ZWSP inside the nick, so the irc user with the same nick won't get pinged. See https://github.com/42wim/matterbridge/issues/175 for more information
    RemoteNickFormat="[{PROTOCOL}] <{NICK}> "
    
    #Enable to show users joins/parts from other bridges 
    #Currently works for messages from the following bridges: irc, mattermost, slack, discord
    #OPTIONAL (default false)
    ShowJoinPart=true
    
    #Do not send joins/parts to other bridges
    #Currently works for messages from the following bridges: irc, mattermost, slack
    #OPTIONAL (default false)
    NoSendJoinPart=false
    
    #StripNick only allows alphanumerical nicks. See https://github.com/42wim/matterbridge/issues/285
    #It will strip other characters from the nick
    #OPTIONAL (default false)
    StripNick=false
    
    #Enable to show topic changes from other bridges 
    #Only works hiding/show topic changes from slack bridge for now
    #OPTIONAL (default false)
    ShowTopicChange=false




    ###################################################################
    #matrix section
    ###################################################################
    [matrix]
    #You can configure multiple servers "[matrix.name]" or "[matrix.name2]"
    #In this example we use [matrix.neo]
    #REQUIRED
    
    [matrix.${fqdn}]
    #Server is your homeserver (eg https://matrix.org)
    #REQUIRED
    Server="https://${fqdn}"
    
    #login/pass of your bot. 
    #Use a dedicated user for this and not your own! 
    #Messages sent from this user will not be relayed to avoid loops.
    #REQUIRED 
    Login="${opt.matterbridge.matrix-user}"
    Password="${opt.matterbridge.matrix-pass}"
    
    #Whether to send the homeserver suffix. eg ":matrix.org" in @username:matrix.org
    #to other bridges, or only send "username".(true only sends username)
    #OPTIONAL (default false)
    NoHomeServerSuffix=true
    
    ## RELOADABLE SETTINGS
    ## Settings below can be reloaded by editing the file
    
    #Whether to prefix messages from other bridges to matrix with the sender's nick. 
    #Useful if username overrides for incoming webhooks isn't enabled on the 
    #matrix server. If you set PrefixMessagesWithNick to true, each message 
    #from bridge to matrix will by default be prefixed by the RemoteNickFormat setting. i
    #OPTIONAL (default false)
    PrefixMessagesWithNick=false
    
    #Nicks you want to ignore. 
    #Regular expressions supported
    #Messages from those users will not be sent to other bridges.
    #OPTIONAL
    #IgnoreNicks="spammer1 spammer2"
    
    #Messages you want to ignore. 
    #Messages matching these regexp will be ignored and not sent to other bridges
    #See https://regex-golang.appspot.com/assets/html/index.html for more regex info
    #OPTIONAL (example below ignores messages starting with ~~ or messages containing badword
    #IgnoreMessages="^~~ badword"
    
    #messages you want to replace.
    #it replaces outgoing messages from the bridge.
    #so you need to place it by the sending bridge definition.
    #regular expressions supported
    #some examples:
    #this replaces cat => dog and sleep => awake
    #replacemessages=[ ["cat","dog"], ["sleep","awake"] ]
    #this replaces every number with number.  123 => numbernumbernumber
    #replacemessages=[ ["[0-9]","number"] ]
    #optional (default empty)
    #ReplaceMessages=[ ["cat","dog"] ]
    
    #nicks you want to replace.
    #see replacemessages for syntaxa
    #optional (default empty)
    #ReplaceNicks=[ ["user--","user"] ]
    
    #Extractnicks is used to for example rewrite messages from other relaybots
    #See https://github.com/42wim/matterbridge/issues/713 and https://github.com/42wim/matterbridge/issues/466
    #some examples:
    #this replaces a message like "Relaybot: <relayeduser> something interesting" to "relayeduser: something interesting"
    #ExtractNicks=[ [ "Relaybot", "<(.*?)>\\s+" ] ]
    #you can use multiple entries for multiplebots
    #this also replaces a message like "otherbot: (relayeduser) something else" to "relayeduser: something else"
    #ExtractNicks=[ [ "Relaybot", "<(.*?)>\\s+" ],[ "otherbot","\\((.*?)\\)\\s+" ]
    #OPTIONAL (default empty)
    #ExtractNicks=[ ["otherbot","<(.*?)>\\s+" ] ]
    
    #extra label that can be used in the RemoteNickFormat
    #optional (default empty)
    #Label=""
    
    #RemoteNickFormat defines how remote users appear on this bridge 
    #See [general] config section for default options
    RemoteNickFormat="[{PROTOCOL}] <{NICK}> "
    
    #Enable to show users joins/parts from other bridges 
    #Currently works for messages from the following bridges: irc, mattermost, slack, discord
    #OPTIONAL (default false)
    ShowJoinPart=true
    
    #StripNick only allows alphanumerical nicks. See https://github.com/42wim/matterbridge/issues/285
    #It will strip other characters from the nick
    #OPTIONAL (default false)
    #StripNick=false
    
    #Enable to show topic changes from other bridges 
    #Only works hiding/show topic changes from slack bridge for now
    #OPTIONAL (default false)
    #ShowTopicChange=false




    [[gateway]]
    name="matrixirc"
    enable=true
    
    [[gateway.inout]]
    account="irc.freenode"
    channel="#nixos"
    
    [[gateway.inout]]
    account="matrix.${fqdn}"
    channel="#nixos:${fqdn}"
  '';
in {
  services.matterbridge = {
    enable = true;
    configPath = "/etc/nixos/matterbridge.toml";
  };

  environment.etc."matterbridge.toml.template".text = template;
}
