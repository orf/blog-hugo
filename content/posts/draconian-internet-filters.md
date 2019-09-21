---
title: "Draconian internet filters"
date: 2012-04-12 00:36:44.575146
---

My universities student network is pretty restricted. I just finished coding a few changes to [Simple](https://github.com/orf/simple) and realised I couldn't push any changes to GitHub due to port restrictions. It appears that they block almost all ports bar 80 and 445 via TCP, which is fine for most users but is quite annoying for me - I often need to SSH into one of my servers or use non-standard ports.

After some investigating I discovered that I could SSH to the student run linux cluster [Freeside](https://www.freeside.co.uk), so I went and got and signed up for an account and got myself a shell. At first I figured that I could just set up a SSH tunnel from my PC to freeside and then proxy my traffic through freeside, allowing me unfiltered access to the internet. However the freeside servers appear to have some form of filtering on them as well, or though not as much - I can SSH out (so I can deploy to github from there) but I can't forward OpenVPN traffic through it (which is critical for my work), so I need to set up a SSH tunnel from freeside to one of my servers in Germany which is fully unrestricted, allowing me to run OpenVPN through the tunnel.

#### Feeding traffic through multiple SSH tunnels using PuTTY
I run Windows on my laptop to develop and game on. Because of this I have no native SSH client, so I use the fantastic [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/) - I suggest you go download it if you do not already have it.

Open up PuTTY and enter *freeside.co.uk* as the hostname and 22 as the port, then navigate to the *tunnels* settings page (under Connections->SSH). Enter 1000 as the source port and the destination as *localhost:10000*. This will forward any traffic going through port 1000 on our machine to port 10000 on the connected host. Navigate back to the session tab and press Save (very important, I always forget to do this and loose any changes I have made). Click connect.

Once you have connected to Freeside and logged in using the username and password that you signed up with then run the following command in the terminal:
``cat ssh -D 10000 username@yourserver.com -p 22 > tunnel.sh``
Replace yourserver.com with your remote servers IP or hostname - I suggest you go buy a [VPS](https://www.vps-forge.com) from somewhere and use that. Replace the username with the username on the remote host.
This will create a new file called tunnel.sh which when executed will create another SSH tunnel listening on port 10000 and forwarding all traffic through yourserver.com.
Make sure you can execute it by running the following command:
``chmod +x tunnel.sh``
And voila, you now have a simple SSH chain set up. Before you want to proxy any traffic open up putty and SSH into freeside, once there execute the tunnel script by running
``sh tunnel.sh``
and login with the correct details when prompted. Now simply point OpenVPN or TortoiseGIT to use the SOCKS proxy running locally on your machine, listening on port 1000, and any traffic you send will be bounced through Freeside, your server then the rest of the world.








    