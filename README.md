siriproxy-jenkins
===============

About
-----
siriproxy-jenkins is a [SiriProxy](https://github.com/plamoni/SiriProxy) plugin that allows you trigger jenkins builds using Siri.

Installation (New for SiriProxy 0.5.0+)
---------------------------------------

- Create a plugins directory  

`mkdir ~/plugins`  

`cd ~/plugins/` 

- Get the latest repo   

`git clone git://github.cerner.com/jt018805/siriproxy-jenkins`

- Add the example plugin configuration (config.example.yml) to the master config.yml plugins section and edit as needed.  

`vim ~/.siriproxy/config.yml`

- Bundle  

`siriproxy bundle`

- Run (Ref: https://github.com/plamoni/SiriProxy#set-up-instructions)  

`[rvmsudo] siriproxy server [-d ###.###.###.###] [-u username]`

Usage
-----

**build (name)**
- Searches for and builds the job with the given name. 