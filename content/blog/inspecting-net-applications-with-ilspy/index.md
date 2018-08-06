---
title: "Inspecting .NET applications with ILSpy"
date: 2013-09-19 12:40:40.611816
permalink: /inspecting-net-applications-with-ilspy
tags:
   - security
---

Every once in a while I come across an application that is so comically insecure that I feel the urge to blog about it. The application in question is a .NET application to manage care homes and provide a [Medical Administration Record](https://en.wikipedia.org/wiki/Medication_Administration_Record) for residents. Staff login to the app using a username and password associated with an organization and you use the application to view everything about a care home - the residents, their schedules, your rota etc. Everything is synchronized to a remote server via a collection of RPC methods, and the application even works while not connected to the internet and will push any modified data to the remote server when it can next connect.

The application is essentially a [thick client](https://en.wikipedia.org/wiki/Fat_client) - it fetches data from the remote database and displays it to the user in various ways, whilst also taking input from the user and submitting it to the server after validating it. That sounds good, until you look deeper. The application performed *all* its validation on the client, the remote server performed no validation *at all* - any user (even unauthenticated ones) could just request a complete list of patients including medical records and the server would send them, no questions asked. They violated one key security principle: **never trust user input**. They trusted that the thick client was the only way to communicate with the remote server (and thus all user input came form an authenticated source), which is a bit silly since the binary application is .NET (easy to decompile), not obfuscated in any way and used standard .NET serialization to send/receive objects from the server.

The analogy that can be drawn is one of a bank full of customers. The bank vault is your database, the teller is your server and the customers are people using your application. Normally customers in the bank are not malicious and only make valid requests: “can I transfer my money to this account” or “can I check my balance”. However I found that the teller (the backend service) answers requests indiscriminately, so if a malicious customer were to ask “can I check the balance of someone else's account” or “can I transfer all money from Mr Gate's account into mine” the teller would not check if the customer is allowed to make those requests before processing them.

#### Hacking the application
I can't really write about the backend, but I can write about one interesting issue we found. This snippet says it all. Remember, this runs on the **client**:

~~~csharp
internal static User UserLogin(String username, String password)
{		
    // Notice how it compares the password locally after fetching the User object
    var user = DataPortal.Fetch<User>(username);
    if (user.PasswordHash != GetPasswordHash(username,password)) return null;
    return user;
}
~~~

So, lets hack it. [ILSpy](https://ilspy.net/) is a fantastic tool for debugging .NET applications. One of its best features is you can set breakpoints in arbitrary assemblies (__you have to compile it from source in debug mode to enable that it seems__). Because the app fetches the user and then compares it locally we can just set a breakpoint after it fetches the object but before it performs any checks. First you have to execute the assembly through ILSpy:

![](./MarFAIL1_Z7AUSWDY.png)

Once you have selected the executable ILSpy will execute it and decompile the sources. This allows you to navigate through the source (which may differ from the real source in some ways) and set breakpoints to be triggered. You can use the sidebar on the left to navigate the various namespaces in the assembly and view the classes contained within. Below I have located the actual code segment where the user is fetched and I have set a breakpoint on the statement after it.

![](./MarFAIL2_PCNNHY36.png)

After I've set the breakpoint I simply need to attempt to login as the "admin" user (with any password) and I can view all of the admin users attributes (public and private), including his password hash, by simply hovering over the reference in the source code.

![](./2013-09-11_17_18_01-Validate_your_input_bro_-_Toms_corner_of_the_internet_2XPXTNSH_JQPOYWWB.png)

Isn't ILSpy awesome?
    